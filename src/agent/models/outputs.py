"""Pydantic models for agent output schemas.

Each agent produces a typed output that flows through the graph state.
"""

from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel, Field


class RiskLevel(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class SourceStatusCode(StrEnum):
    OK = "ok"             # Source worked as intended
    DEGRADED = "degraded" # Partial success (e.g., some note details failed)
    FALLBACK = "fallback" # Source failed, alternative used
    SKIPPED = "skipped"   # Source not available/configured


class SourceStatus(BaseModel):
    """Status of a single data source used during advice generation."""

    source: str = Field(description="e.g. 'Medical Knowledge Base'")
    status: SourceStatusCode
    message: str = Field(description="User-facing explanation of what happened")


class Citation(BaseModel):
    """A single source citation attached to advice."""

    source_type: str = Field(description="e.g. 'data_analysis', 'book', 'medical', 'xhs_post'")
    reference: str = Field(description="e.g. 'AAP Immunization Guide, p.42'")
    detail: str | None = None


class TrendAnomaly(BaseModel):
    """A single anomaly detected in physiology data."""

    date: str
    metric: str
    value: float
    baseline: float
    deviation_pct: float = Field(description="Percentage deviation from baseline")
    description: str


class TrendAnalysis(BaseModel):
    """Output of the Data Scientist agent."""

    summary: str
    anomalies: list[TrendAnomaly] = Field(default_factory=list)
    correlations: list[str] = Field(
        default_factory=list,
        description="Context events correlated with anomalies",
    )
    citations: list[Citation] = Field(default_factory=list)


class MedicalInsight(BaseModel):
    """Output of the Medical Expert agent."""

    summary: str
    risk_level: RiskLevel = RiskLevel.LOW
    recommendations: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    kb_available: bool | None = Field(
        default=None,
        description="True=RAG succeeded, False=LLM-only/KB failed, None=unknown",
    )
    raw_kb_snippets: list[str] = Field(
        default_factory=list,
        description="Raw document excerpts for degraded-mode display",
    )


class SocialInsight(BaseModel):
    """Output of the Social Researcher agent."""

    summary: str
    consensus_points: list[str] = Field(default_factory=list)
    sample_size: int = Field(default=0, description="Number of posts/discussions analyzed")
    citations: list[Citation] = Field(default_factory=list)
    agrees_with_medical: bool | None = Field(
        default=None,
        description="True=agrees, False=contradicts, None=unknown",
    )
    raw_social_posts: list[str] = Field(
        default_factory=list,
        description="Raw post snippets for degraded-mode display",
    )


class CritiqueResult(BaseModel):
    """Output of the Critique node (reflection loop)."""

    approved: bool
    confidence_score: float = Field(ge=0.0, le=1.0)
    issues: list[str] = Field(default_factory=list)
    suggestions: list[str] = Field(default_factory=list)


class ParentingAdvice(BaseModel):
    """Final synthesized output delivered to the parent."""

    question: str
    summary: str
    key_points: list[str] = Field(default_factory=list)
    action_items: list[str] = Field(default_factory=list)
    risk_level: RiskLevel = RiskLevel.LOW
    confidence_score: float = Field(ge=0.0, le=1.0)
    citations: list[Citation] = Field(default_factory=list)
    sources_used: list[SourceStatus] = Field(default_factory=list)
    is_degraded: bool = False
    raw_sources: list[str] = Field(
        default_factory=list,
        description="Raw source snippets shown when synthesis is degraded",
    )
    disclaimer: str = (
        "This is AI-generated guidance and not a substitute for professional medical advice. "
        "Always consult your pediatrician for health concerns."
    )
