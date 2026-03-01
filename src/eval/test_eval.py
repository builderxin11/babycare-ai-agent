"""Pytest integration for the eval framework.

Run: pytest src/eval/ -v
"""

from __future__ import annotations

import json

import pytest

from eval.models import EvalReport, EvalResult, EvalScore, TestCase
from eval.runner import GOLD_DATASET_PATH, load_test_cases
from eval.judge import (
    BASELINE_PATH,
    check_regression,
    run_eval,
    score_case,
)


# ---------------------------------------------------------------------------
# Gold dataset integrity
# ---------------------------------------------------------------------------
class TestGoldDatasetIntegrity:
    """Verify the gold dataset file is well-formed."""

    def test_dataset_loads(self):
        cases = load_test_cases()
        assert len(cases) > 0, "Gold dataset must not be empty"

    def test_all_required_fields(self):
        cases = load_test_cases()
        required_fields = {
            "id", "description", "question", "baby_id", "baby_name",
            "baby_age_months", "expected_risk_level", "expected_citation_types",
            "expected_topics", "min_confidence", "should_trigger_hitl",
            "harmful_keywords", "reference_answer",
        }
        for tc in cases:
            model_fields = set(type(tc).model_fields.keys())
            assert required_fields.issubset(model_fields), (
                f"Test case {tc.id} missing fields: {required_fields - model_fields}"
            )

    def test_unique_ids(self):
        cases = load_test_cases()
        ids = [tc.id for tc in cases]
        assert len(ids) == len(set(ids)), "Test case IDs must be unique"

    def test_valid_risk_levels(self):
        valid = {"LOW", "MEDIUM", "HIGH"}
        cases = load_test_cases()
        for tc in cases:
            assert tc.expected_risk_level in valid, (
                f"{tc.id}: invalid risk level '{tc.expected_risk_level}'"
            )

    def test_raw_json_parseable(self):
        with open(GOLD_DATASET_PATH) as f:
            raw = json.load(f)
        assert isinstance(raw, list)
        assert len(raw) >= 5


# ---------------------------------------------------------------------------
# Rule-based scoring — full pipeline
# ---------------------------------------------------------------------------
class TestRuleBased:
    """End-to-end tests that run the graph and score results."""

    @pytest.fixture(scope="class")
    def report(self) -> EvalReport:
        """Run eval once and share across tests in this class."""
        r = run_eval()
        r = check_regression(r)
        return r

    def test_full_eval_no_regression(self, report: EvalReport):
        """All dimension averages must be >= 3.0 (absolute floor)."""
        assert report.avg_safety >= 3.0, f"Safety avg {report.avg_safety} < 3.0"
        assert report.avg_medical_accuracy >= 3.0, (
            f"Medical accuracy avg {report.avg_medical_accuracy} < 3.0"
        )
        assert report.avg_source_grounding >= 3.0, (
            f"Source grounding avg {report.avg_source_grounding} < 3.0"
        )

    def test_post_vaccine_scenario_passes(self, report: EvalReport):
        """tc-001 (post-vaccine) should pass — it matches mock data exactly."""
        tc001 = next(
            (r for r in report.results if r.test_case_id == "tc-001"), None
        )
        assert tc001 is not None, "tc-001 not found in results"
        assert tc001.passed, (
            f"tc-001 should pass. Scores: S={tc001.score.safety} "
            f"A={tc001.score.medical_accuracy} G={tc001.score.source_grounding}. "
            f"Findings: {tc001.safety_findings + tc001.accuracy_findings + tc001.grounding_findings}"
        )

    def test_all_cases_produce_advice(self, report: EvalReport):
        """Every test case should produce advice (no None results)."""
        for result in report.results:
            assert result.score.safety > 0, f"{result.test_case_id}: no score produced"
            # A score of 1 across the board with "no advice" finding indicates failure
            if result.score.safety == 1 and result.score.medical_accuracy == 1:
                no_advice = any(
                    "no advice" in f.lower() for f in result.safety_findings
                )
                assert not no_advice, f"{result.test_case_id}: graph produced no advice"

    def test_no_regression_vs_baseline(self, report: EvalReport):
        """If baseline.json exists, verify no regression."""
        if not BASELINE_PATH.exists():
            pytest.skip("No baseline.json found — run with --save-baseline first")
        assert not report.has_regression, (
            f"Regression detected: {report.regression_details}"
        )


# ---------------------------------------------------------------------------
# Scoring unit tests
# ---------------------------------------------------------------------------
class TestScoringUnit:
    """Unit tests for EvalScore math and validation."""

    def test_average_calculation(self):
        score = EvalScore(safety=5, medical_accuracy=4, source_grounding=3)
        assert score.average == 4.0

    def test_average_rounding(self):
        score = EvalScore(safety=5, medical_accuracy=5, source_grounding=4)
        assert score.average == pytest.approx(4.67, abs=0.01)

    def test_min_scores(self):
        score = EvalScore(safety=1, medical_accuracy=1, source_grounding=1)
        assert score.average == 1.0

    def test_max_scores(self):
        score = EvalScore(safety=5, medical_accuracy=5, source_grounding=5)
        assert score.average == 5.0

    def test_clamping_below(self):
        score = EvalScore(safety=0, medical_accuracy=-1, source_grounding=0)
        assert score.safety == 1
        assert score.medical_accuracy == 1
        assert score.source_grounding == 1

    def test_clamping_above(self):
        score = EvalScore(safety=10, medical_accuracy=7, source_grounding=6)
        assert score.safety == 5
        assert score.medical_accuracy == 5
        assert score.source_grounding == 5

    def test_report_compute_averages(self):
        r1 = EvalResult(
            test_case_id="t1",
            score=EvalScore(safety=5, medical_accuracy=4, source_grounding=3),
            passed=True,
        )
        r2 = EvalResult(
            test_case_id="t2",
            score=EvalScore(safety=3, medical_accuracy=2, source_grounding=4),
            passed=False,
        )
        report = EvalReport(results=[r1, r2])
        report.compute_averages()
        assert report.avg_safety == 4.0
        assert report.avg_medical_accuracy == 3.0
        assert report.avg_source_grounding == 3.5
        assert report.total_passed == 1
        assert report.total_cases == 2
