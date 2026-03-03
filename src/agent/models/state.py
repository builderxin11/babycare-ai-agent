"""LangGraph agent state definition.

Uses TypedDict with Annotated reducers — the idiomatic LangGraph pattern.
"""

from __future__ import annotations

import operator
from typing import Annotated, TypedDict

from langgraph.graph import add_messages

from .outputs import (
    CritiqueResult,
    DailyReport,
    ParentingAdvice,
    SourceStatus,
    TrendAnalysis,
    MedicalInsight,
    SocialInsight,
)


class AgentState(TypedDict, total=False):
    """Shared state flowing through the multi-agent graph.

    Fields use Annotated reducers where multiple nodes append to the same key.
    """

    # --- Input ---
    question: str
    baby_id: str
    baby_name: str
    baby_age_months: int

    # --- LangGraph message history ---
    messages: Annotated[list, add_messages]

    # --- Routing ---
    agents_completed: Annotated[list[str], operator.add]
    next_agent: str

    # --- Agent outputs ---
    trend_analysis: TrendAnalysis | None
    medical_insight: MedicalInsight | None
    social_insight: SocialInsight | None

    # --- Source transparency ---
    source_statuses: Annotated[list[SourceStatus], operator.add]

    # --- Critique / reflection ---
    critique_result: CritiqueResult | None
    critique_count: int

    # --- Final output ---
    final_advice: ParentingAdvice | None
    daily_report: DailyReport | None

    # --- Human-in-the-loop ---
    requires_human_review: bool
    human_review_reason: str
    human_feedback: str | None

    # --- Report mode flag ---
    is_daily_report: bool
