"""Pydantic models for the evaluation framework.

Mirrors the pattern in agent.models.outputs — strict typing for all eval data.
"""

from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel, Field, field_validator


class JudgeMode(StrEnum):
    RULE_BASED = "rule_based"
    LLM_BASED = "llm_based"


class TestCase(BaseModel):
    """A single entry from the gold dataset."""

    __test__ = False  # prevent pytest collection

    id: str
    description: str
    question: str
    baby_id: str
    baby_name: str
    baby_age_months: int
    expected_risk_level: str = Field(description="LOW, MEDIUM, or HIGH")
    expected_citation_types: list[str] = Field(default_factory=list)
    expected_topics: list[str] = Field(default_factory=list)
    min_confidence: float = Field(ge=0.0, le=1.0)
    should_trigger_hitl: bool = False
    harmful_keywords: list[str] = Field(default_factory=list)
    reference_answer: str = ""


class EvalScore(BaseModel):
    """Scores for a single eval case across three dimensions."""

    safety: int = Field(ge=1, le=5)
    medical_accuracy: int = Field(ge=1, le=5)
    source_grounding: int = Field(ge=1, le=5)

    @property
    def average(self) -> float:
        return round((self.safety + self.medical_accuracy + self.source_grounding) / 3, 2)

    @field_validator("safety", "medical_accuracy", "source_grounding", mode="before")
    @classmethod
    def clamp_score(cls, v: int) -> int:
        return max(1, min(5, v))


class EvalResult(BaseModel):
    """Result for a single test case."""

    test_case_id: str
    score: EvalScore
    safety_findings: list[str] = Field(default_factory=list)
    accuracy_findings: list[str] = Field(default_factory=list)
    grounding_findings: list[str] = Field(default_factory=list)
    passed: bool = False
    elapsed_seconds: float = 0.0

    @property
    def pass_label(self) -> str:
        return "PASS" if self.passed else "FAIL"


class EvalReport(BaseModel):
    """Aggregated report across all test cases."""

    results: list[EvalResult] = Field(default_factory=list)
    avg_safety: float = 0.0
    avg_medical_accuracy: float = 0.0
    avg_source_grounding: float = 0.0
    avg_overall: float = 0.0
    total_passed: int = 0
    total_cases: int = 0
    has_regression: bool = False
    regression_details: list[str] = Field(default_factory=list)

    def compute_averages(self) -> None:
        """Recompute averages from results."""
        if not self.results:
            return
        n = len(self.results)
        self.total_cases = n
        self.total_passed = sum(1 for r in self.results if r.passed)
        self.avg_safety = round(sum(r.score.safety for r in self.results) / n, 2)
        self.avg_medical_accuracy = round(
            sum(r.score.medical_accuracy for r in self.results) / n, 2
        )
        self.avg_source_grounding = round(
            sum(r.score.source_grounding for r in self.results) / n, 2
        )
        self.avg_overall = round(
            (self.avg_safety + self.avg_medical_accuracy + self.avg_source_grounding) / 3, 2
        )
