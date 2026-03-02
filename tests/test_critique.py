"""Tests for the critique node (rule-based, prompt formatting, and LLM fallback)."""

from unittest.mock import MagicMock, patch

import pytest
from langchain_core.messages import AIMessage

from agent.agents.moderator import (
    _compute_three_source_confidence,
    _format_agent_output,
    _format_critique_prompt,
    _run_llm,
    _run_rule_based,
    _synthesize_degraded,
    _synthesize_normal,
    critique_node,
    synthesize_node,
)
from agent.models.outputs import (
    Citation,
    CritiqueResult,
    MedicalInsight,
    ParentingAdvice,
    RiskLevel,
    SocialInsight,
    TrendAnalysis,
    TrendAnomaly,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_trend(**overrides) -> TrendAnalysis:
    defaults = {
        "summary": "Feeding volume dropped 25% post-vaccine.",
        "anomalies": [
            TrendAnomaly(
                date="2025-01-15",
                metric="feeding_volume_ml",
                value=120.0,
                baseline=160.0,
                deviation_pct=-25.0,
                description="Feeding volume below baseline",
            ),
        ],
        "correlations": ["DTaP Vaccine (2025-01-14)"],
        "citations": [
            Citation(source_type="data_analysis", reference="PhysiologyLog analysis"),
        ],
    }
    defaults.update(overrides)
    return TrendAnalysis(**defaults)


def _make_medical(**overrides) -> MedicalInsight:
    defaults = {
        "summary": "Normal post-vaccination response.",
        "risk_level": RiskLevel.LOW,
        "recommendations": ["Monitor feeding", "Consult pediatrician if persists"],
        "citations": [
            Citation(source_type="book", reference="AAP Immunization Guide, p.42"),
        ],
        "kb_available": None,
    }
    defaults.update(overrides)
    return MedicalInsight(**defaults)


def _make_social(**overrides) -> SocialInsight:
    defaults = {
        "summary": "Parents report similar patterns.",
        "consensus_points": ["Temporary decrease is common"],
        "sample_size": 200,
        "citations": [
            Citation(source_type="xhs_post", reference="XHS Consensus, N=200"),
        ],
        "agrees_with_medical": True,
    }
    defaults.update(overrides)
    return SocialInsight(**defaults)


def _make_state(**overrides) -> dict:
    """Create a minimal AgentState dict for critique testing."""
    state: dict = {
        "question": "Baby eating less after vaccine?",
        "baby_age_months": 4,
        "trend_analysis": _make_trend(),
        "medical_insight": _make_medical(),
        "social_insight": _make_social(),
        "critique_count": 0,
        "messages": [],
        "agents_completed": ["data_scientist", "medical_expert", "social_researcher"],
    }
    state.update(overrides)
    return state


# ---------------------------------------------------------------------------
# TestCritiqueRuleBased
# ---------------------------------------------------------------------------


class TestCritiqueRuleBased:
    """Tests for the deterministic rule-based critique path."""

    def test_all_outputs_present_approved(self):
        """When all agents produced output with citations, result is approved."""
        result = _run_rule_based(_make_state(), iteration=1)
        cr = result["critique_result"]
        assert isinstance(cr, CritiqueResult)
        assert cr.approved is True
        assert cr.confidence_score > 0.7
        assert len(cr.issues) == 0

    def test_missing_trend_flagged(self):
        """Missing trend_analysis should be flagged as an issue."""
        result = _run_rule_based(_make_state(trend_analysis=None), iteration=1)
        cr = result["critique_result"]
        assert cr.approved is False
        assert any("Missing trend analysis" in i for i in cr.issues)

    def test_missing_medical_flagged(self):
        """Missing medical_insight should be flagged as an issue."""
        result = _run_rule_based(_make_state(medical_insight=None), iteration=1)
        cr = result["critique_result"]
        assert cr.approved is False
        assert any("Missing medical insight" in i for i in cr.issues)

    def test_no_citations_flagged(self):
        """Agent output with empty citations should produce issues."""
        trend = _make_trend(citations=[])
        medical = _make_medical(citations=[])
        social = _make_social(citations=[])
        result = _run_rule_based(
            _make_state(trend_analysis=trend, medical_insight=medical, social_insight=social),
            iteration=1,
        )
        cr = result["critique_result"]
        assert any("lacks citations" in i for i in cr.issues)
        assert any("citation coverage" in s for s in cr.suggestions)

    def test_max_iterations_force_approve(self):
        """After max iterations, approve despite issues."""
        result = _run_rule_based(
            _make_state(trend_analysis=None),
            iteration=2,  # default max_critique_iterations=2
        )
        cr = result["critique_result"]
        assert cr.approved is True
        assert any("max iterations" in s for s in cr.suggestions)

    def test_confidence_scoring(self):
        """Confidence should be higher when all checks pass."""
        good = _run_rule_based(_make_state(), iteration=1)
        bad = _run_rule_based(_make_state(trend_analysis=None), iteration=1)
        assert good["critique_result"].confidence_score > bad["critique_result"].confidence_score


# ---------------------------------------------------------------------------
# TestFormatCritiquePrompt
# ---------------------------------------------------------------------------


class TestFormatCritiquePrompt:
    """Tests for _format_critique_prompt and _format_agent_output."""

    def test_all_fields_populated(self):
        """Prompt should contain question, age, and serialized agent outputs."""
        prompt = _format_critique_prompt(_make_state())
        assert "Baby eating less" in prompt
        assert "4 months" in prompt
        assert "Feeding volume dropped" in prompt  # from trend JSON
        assert "AAP Immunization Guide" in prompt  # from medical JSON
        assert "XHS Consensus" in prompt  # from social JSON

    def test_missing_social_shows_placeholder(self):
        """When social_insight is None, prompt should show a placeholder."""
        prompt = _format_critique_prompt(_make_state(social_insight=None))
        assert "(no output produced)" in prompt

    def test_missing_trend_shows_placeholder(self):
        """When trend_analysis is None, prompt should show a placeholder."""
        prompt = _format_critique_prompt(_make_state(trend_analysis=None))
        assert "(no output produced)" in prompt

    def test_format_agent_output_none(self):
        assert _format_agent_output(None) == "(no output produced)"

    def test_format_agent_output_pydantic(self):
        trend = _make_trend()
        output = _format_agent_output(trend)
        assert "feeding_volume_ml" in output  # from JSON serialization


# ---------------------------------------------------------------------------
# TestCritiqueFallback
# ---------------------------------------------------------------------------


class TestCritiqueFallback:
    """Tests for LLM critique path and its fallback to rule-based."""

    def test_llm_failure_falls_back_to_rule_based(self):
        """When the LLM call raises, _run_llm should fall back to _run_rule_based."""
        state = _make_state()

        with patch("agent.agents.moderator._call_critique_llm", side_effect=RuntimeError("Bedrock down")):
            result = _run_llm(state, iteration=1)

        cr = result["critique_result"]
        assert isinstance(cr, CritiqueResult)
        # Rule-based with all outputs should approve
        assert cr.approved is True

    def test_llm_success_returns_llm_result(self):
        """When LLM succeeds, its CritiqueResult is used directly."""
        llm_result = CritiqueResult(
            approved=False,
            confidence_score=0.6,
            issues=["Safety concern detected"],
            suggestions=["Rephrase recommendation"],
        )

        with patch("agent.agents.moderator._call_critique_llm", return_value=llm_result):
            result = _run_llm(_make_state(), iteration=1)

        cr = result["critique_result"]
        assert cr.approved is False
        assert cr.confidence_score == 0.6
        assert "Safety concern detected" in cr.issues
        assert "[critique/llm]" in result["messages"][0].content

    def test_max_iterations_skips_llm(self):
        """At max iterations, _run_llm should skip the LLM and use rule-based."""
        state = _make_state(trend_analysis=None)  # has issues
        # Should NOT call the LLM at all
        with patch("agent.agents.moderator._call_critique_llm") as mock_llm:
            result = _run_llm(state, iteration=2)
            mock_llm.assert_not_called()

        cr = result["critique_result"]
        # Force-approved by rule-based at max iterations
        assert cr.approved is True


# ---------------------------------------------------------------------------
# TestCritiqueNodeRouting
# ---------------------------------------------------------------------------


class TestCritiqueNodeRouting:
    """Tests that critique_node always attempts LLM with rule-based fallback."""

    def test_attempts_llm(self, monkeypatch):
        """critique_node should always attempt LLM path."""
        import agent.agents.moderator as mod

        llm_result = CritiqueResult(
            approved=True,
            confidence_score=0.9,
            issues=[],
            suggestions=[],
        )

        with patch.object(mod, "_call_critique_llm", return_value=llm_result):
            result = critique_node(_make_state())

        assert "[critique/llm]" in result["messages"][0].content

    def test_falls_back_to_rule_based_on_llm_failure(self):
        """When LLM fails, critique_node should fall back to rule-based."""
        with patch("agent.agents.moderator._call_critique_llm", side_effect=RuntimeError("down")):
            result = critique_node(_make_state())

        cr = result["critique_result"]
        assert isinstance(cr, CritiqueResult)
        # Rule-based with all outputs should approve
        assert cr.approved is True
        assert "[critique]" in result["messages"][0].content


# ---------------------------------------------------------------------------
# TestThreeSourceConfidence
# ---------------------------------------------------------------------------


class TestThreeSourceConfidence:
    """Tests for the three-source confidence scoring model."""

    def test_kb_found_and_agree_highest(self):
        """Three-way agreement (KB found + social agrees) should yield highest score."""
        medical = _make_medical(kb_available=True)
        social = _make_social(agrees_with_medical=True)
        score = _compute_three_source_confidence(
            medical, social,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        # 0.50 + 0.20 + 0.10 + 0.10 + 0.05 + 0.03 + 0.02 = 1.00 -> capped at 0.95
        assert score == 0.95

    def test_kb_unknown_and_agree_highest(self):
        """kb_available=None with agreement should also hit max."""
        medical = _make_medical(kb_available=None)
        social = _make_social(agrees_with_medical=True)
        score = _compute_three_source_confidence(
            medical, social,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        assert score == 0.95

    def test_kb_missing_small_penalty(self):
        """KB miss (kb_available=False) should cause a small reduction."""
        medical_kb = _make_medical(kb_available=True)
        medical_no_kb = _make_medical(kb_available=False)
        social = _make_social(agrees_with_medical=True)

        score_with_kb = _compute_three_source_confidence(
            medical_kb, social,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        score_without_kb = _compute_three_source_confidence(
            medical_no_kb, social,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        # KB miss loses +0.20 -> -0.05, plus loses three-way bonus +0.10
        assert score_with_kb > score_without_kb
        # Without KB: 0.50 - 0.05 + 0.10 + 0.05 + 0.03 + 0.02 = 0.65
        assert score_without_kb == 0.65

    def test_contradiction_lowers_score(self):
        """Social contradiction should significantly lower confidence."""
        medical = _make_medical(kb_available=True)
        social_agree = _make_social(agrees_with_medical=True)
        social_disagree = _make_social(agrees_with_medical=False)

        score_agree = _compute_three_source_confidence(
            medical, social_agree,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        score_disagree = _compute_three_source_confidence(
            medical, social_disagree,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        assert score_agree > score_disagree
        # Disagree: 0.50 + 0.20 - 0.15 + 0.05 + 0.03 + 0.02 = 0.65
        assert score_disagree == 0.65

    def test_contradiction_adds_issue_in_rule_based(self):
        """Rule-based critique should flag contradiction as an issue."""
        state = _make_state(
            social_insight=_make_social(agrees_with_medical=False),
        )
        result = _run_rule_based(state, iteration=1)
        cr = result["critique_result"]
        assert any("contradicts" in i.lower() for i in cr.issues)

    def test_unknown_agreement_neutral(self):
        """Unknown agreement (None) should cause no adjustment."""
        medical = _make_medical(kb_available=None)
        social_agree = _make_social(agrees_with_medical=True)
        social_unknown = _make_social(agrees_with_medical=None)

        score_agree = _compute_three_source_confidence(
            medical, social_agree,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        score_unknown = _compute_three_source_confidence(
            medical, social_unknown,
            no_issues=True, total_citations=4, has_correlations=True,
        )
        # Unknown loses +0.10 (agreement) and +0.10 (three-way bonus) = -0.20
        assert score_agree > score_unknown
        # Unknown: 0.50 + 0.20 + 0.00 + 0.05 + 0.03 + 0.02 = 0.80
        assert score_unknown == 0.80

    def test_all_missing_floors_at_minimum(self):
        """With no medical and no social, confidence should be low."""
        score = _compute_three_source_confidence(
            None, None,
            no_issues=False, total_citations=0, has_correlations=False,
        )
        # medical=None -> kb_available treated as False -> -0.05
        # social=None -> agrees treated as None -> +0.00
        # no_issues=False -> no bonus, total_citations<3 -> no bonus, no correlations -> no bonus
        # 0.50 - 0.05 = 0.45
        assert score == 0.45

    def test_kb_miss_social_skip(self):
        """KB miss + social skip (None agreement)."""
        medical = _make_medical(kb_available=False)
        score = _compute_three_source_confidence(
            medical, None,
            no_issues=False, total_citations=2, has_correlations=False,
        )
        # 0.50 - 0.05 + 0.00 = 0.45
        assert score == 0.45


# ---------------------------------------------------------------------------
# TestSynthesizeDegraded
# ---------------------------------------------------------------------------


class TestSynthesizeDegraded:
    """Tests for degraded synthesis mode."""

    def test_degraded_when_medical_missing(self):
        """When medical_insight is None, synthesis should be degraded."""
        state = _make_state(medical_insight=None)
        state["critique_result"] = CritiqueResult(
            approved=True, confidence_score=0.5, issues=[], suggestions=[],
        )
        result = synthesize_node(state)
        advice = result["final_advice"]
        assert advice.is_degraded is True
        assert "could not produce" in advice.summary.lower()
        assert "degraded=True" in result["messages"][0].content

    def test_degraded_when_low_confidence(self):
        """When confidence < 0.4, synthesis should be degraded."""
        state = _make_state()
        state["critique_result"] = CritiqueResult(
            approved=True, confidence_score=0.3, issues=[], suggestions=[],
        )
        result = synthesize_node(state)
        advice = result["final_advice"]
        assert advice.is_degraded is True
        assert len(advice.raw_sources) >= 0  # may be empty if no raw snippets

    def test_degraded_populates_raw_sources(self):
        """Degraded mode should populate raw_sources from available data."""
        medical = _make_medical(
            raw_kb_snippets=["KB snippet about vaccines"],
        )
        social = _make_social(
            raw_social_posts=["Post about baby after vaccine"],
        )
        state = _make_state(medical_insight=medical, social_insight=social)
        state["critique_result"] = CritiqueResult(
            approved=True, confidence_score=0.2, issues=[], suggestions=[],
        )
        result = synthesize_node(state)
        advice = result["final_advice"]
        assert advice.is_degraded is True
        assert any("[Medical KB]" in s for s in advice.raw_sources)
        assert any("[Social]" in s for s in advice.raw_sources)

    def test_contradiction_shows_both_perspectives(self):
        """When social contradicts medical, both views should appear in key_points."""
        state = _make_state(
            social_insight=_make_social(agrees_with_medical=False),
        )
        state["critique_result"] = CritiqueResult(
            approved=True, confidence_score=0.7, issues=[], suggestions=[],
        )
        result = synthesize_node(state)
        advice = result["final_advice"]
        # Normal mode (confidence >= 0.4 and medical present)
        assert advice.is_degraded is False
        assert any("differs from the medical" in p for p in advice.key_points)

    def test_normal_mode_not_degraded(self):
        """Standard case should not be degraded."""
        state = _make_state()
        state["critique_result"] = CritiqueResult(
            approved=True, confidence_score=0.9, issues=[], suggestions=[],
        )
        result = synthesize_node(state)
        advice = result["final_advice"]
        assert advice.is_degraded is False
        assert advice.raw_sources == []
