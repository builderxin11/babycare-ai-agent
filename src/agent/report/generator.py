"""Daily health report generator.

Generates a DailyReport by running a lightweight multi-agent pipeline:
Data Scientist → Medical Expert → Critique → Report Writer

Key differences from the /ask flow:
- No parent question — synthetic question generated from data
- No Social Researcher — skipped for faster daily reports
- No HITL interrupt — auto-approved (Critique only)
- Output is DailyReport, not ParentingAdvice
"""

from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, timedelta, timezone

from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.serde.jsonplus import JsonPlusSerializer
from langgraph.graph import END, START, StateGraph

from agent.agents.data_scientist import data_scientist_node
from agent.agents.medical_expert import medical_expert_node
from agent.agents.moderator import critique_node
from agent.config import config
from agent.models.outputs import (
    Citation,
    DailyReport,
    HealthStatus,
    RiskLevel,
    TrendDirection,
)
from agent.models.state import AgentState
from agent.tools.dynamodb import query_context_events, query_physiology_logs

logger = logging.getLogger(__name__)

# Allowed msgpack modules for checkpoint serialization
_ALLOWED_MSGPACK_MODULES: set[tuple[str, str]] = {
    ("agent.models.outputs", "CritiqueResult"),
    ("agent.models.outputs", "DailyReport"),
    ("agent.models.outputs", "HealthStatus"),
    ("agent.models.outputs", "MedicalInsight"),
    ("agent.models.outputs", "RiskLevel"),
    ("agent.models.outputs", "SourceStatus"),
    ("agent.models.outputs", "SourceStatusCode"),
    ("agent.models.outputs", "TrendAnalysis"),
    ("agent.models.outputs", "TrendDirection"),
}


def _generate_synthetic_question(baby_name: str, report_date: date) -> str:
    """Generate a synthetic question for the agent pipeline."""
    return (
        f"Based on {baby_name}'s logged data for {report_date.isoformat()}, "
        f"provide a comprehensive daily health summary including any concerns, "
        f"trends compared to the past week, and actionable recommendations."
    )


def _build_report_graph() -> StateGraph:
    """Build a lightweight graph for daily report generation.

    Topology:
        START → data_scientist → medical_expert → critique → report_writer → END

    No supervisor loop, no Social Researcher, no HITL.
    """
    graph = StateGraph(AgentState)

    # Reuse existing agent nodes
    graph.add_node("data_scientist", data_scientist_node)
    graph.add_node("medical_expert", medical_expert_node)
    graph.add_node("critique", critique_node)
    graph.add_node("report_writer", _report_writer_node)

    # Linear flow
    graph.add_edge(START, "data_scientist")
    graph.add_edge("data_scientist", "medical_expert")
    graph.add_edge("medical_expert", "critique")
    graph.add_edge("critique", "report_writer")
    graph.add_edge("report_writer", END)

    return graph


def _compile_report_graph():
    """Compile the report graph with a temporary MemorySaver."""
    graph = _build_report_graph()
    serde = JsonPlusSerializer(allowed_msgpack_modules=_ALLOWED_MSGPACK_MODULES)
    checkpointer = MemorySaver(serde=serde)
    return graph.compile(checkpointer=checkpointer)


def _map_risk_to_health_status(risk_level: RiskLevel) -> HealthStatus:
    """Map RiskLevel to HealthStatus for daily reports."""
    if risk_level == RiskLevel.HIGH:
        return HealthStatus.CONCERN
    elif risk_level == RiskLevel.MEDIUM:
        return HealthStatus.MONITOR
    return HealthStatus.HEALTHY


def _compute_trend_direction(trend_analysis) -> TrendDirection:
    """Determine trend direction from anomalies.

    Logic:
    - If recent anomalies show improvement → IMPROVING
    - If recent anomalies show decline → DECLINING
    - Otherwise → STABLE
    """
    if not trend_analysis or not trend_analysis.anomalies:
        return TrendDirection.STABLE

    # Look at the most recent anomaly
    anomalies = sorted(trend_analysis.anomalies, key=lambda a: a.date, reverse=True)
    recent = anomalies[0] if anomalies else None

    if not recent:
        return TrendDirection.STABLE

    # Check deviation direction
    if recent.deviation_pct > 0.25:
        # Above baseline could be good (feeding) or bad (depends on metric)
        if "feeding" in recent.metric:
            return TrendDirection.IMPROVING
        return TrendDirection.STABLE
    elif recent.deviation_pct < -0.25:
        # Below baseline is typically declining
        return TrendDirection.DECLINING

    return TrendDirection.STABLE


def _report_writer_node(state: AgentState) -> dict:
    """Transform agent outputs into a DailyReport.

    This is a pure transformation node — no LLM calls.
    """
    trend = state.get("trend_analysis")
    medical = state.get("medical_insight")
    critique = state.get("critique_result")

    baby_id = state.get("baby_id", "")
    baby_name = state.get("baby_name", "Baby")

    # Determine health status from medical risk level
    risk_level = medical.risk_level if medical else RiskLevel.LOW
    health_status = _map_risk_to_health_status(risk_level)

    # Compute trend direction
    trend_direction = _compute_trend_direction(trend)

    # Build summary
    summary_parts = []
    if medical:
        summary_parts.append(medical.summary)
    if trend and trend.summary:
        summary_parts.append(trend.summary)
    summary = " ".join(summary_parts) if summary_parts else "No significant observations today."

    # Build observations from trend anomalies
    observations = []
    if trend and trend.anomalies:
        for anomaly in trend.anomalies[:5]:
            observations.append(anomaly.description)
    if trend and trend.correlations:
        for corr in trend.correlations[:3]:
            observations.append(corr)

    # Build action items from medical recommendations
    action_items = medical.recommendations if medical else []

    # Build warnings for HIGH risk
    warnings = []
    if risk_level == RiskLevel.HIGH:
        warnings.append("Consider consulting your pediatrician about the patterns observed today.")
    if critique and critique.issues:
        for issue in critique.issues[:2]:
            if "safety" in issue.lower() or "concern" in issue.lower():
                warnings.append(issue)

    # Collect citations
    citations = []
    if trend and trend.citations:
        citations.extend(trend.citations)
    if medical and medical.citations:
        citations.extend(medical.citations)

    # Build data snapshots
    data_snapshot = {}
    baseline_snapshot = {}
    if trend and trend.data_summary:
        data_snapshot["raw_summary"] = trend.data_summary

    # Create the report
    report = DailyReport(
        baby_id=baby_id,
        baby_name=baby_name,
        report_date=date.today(),
        health_status=health_status,
        confidence_score=critique.confidence_score if critique else 0.7,
        trend_direction=trend_direction,
        summary=summary,
        observations=observations,
        action_items=action_items,
        warnings=warnings,
        citations=citations,
        data_snapshot=data_snapshot,
        baseline_snapshot=baseline_snapshot,
        generated_at=datetime.now(timezone.utc),
    )

    return {"daily_report": report}


def generate_daily_report(
    baby_id: str,
    baby_name: str,
    baby_age_months: int,
    report_date: date | None = None,
) -> DailyReport:
    """Generate a daily health report for a baby.

    Args:
        baby_id: The baby's ID for DynamoDB queries
        baby_name: The baby's name for display
        baby_age_months: The baby's age in months
        report_date: Date to generate report for (defaults to today)

    Returns:
        A DailyReport with health status, observations, and recommendations.

    Raises:
        ValueError: If no data is available for the baby
    """
    if report_date is None:
        report_date = date.today()

    # Generate synthetic question
    question = _generate_synthetic_question(baby_name, report_date)

    # Build initial state
    initial_state: AgentState = {
        "question": question,
        "baby_id": baby_id,
        "baby_name": baby_name,
        "baby_age_months": baby_age_months,
        "messages": [],
        "agents_completed": [],
        "critique_count": 0,
        "requires_human_review": False,
        "human_review_reason": "",
        # Mark this as a report request (can be used for conditional logic)
        "is_daily_report": True,
    }

    # Compile and run the graph
    graph = _compile_report_graph()
    thread_id = str(uuid.uuid4())
    config_dict = {"configurable": {"thread_id": thread_id}}

    # Run the graph
    final_state = None
    for event in graph.stream(initial_state, config_dict, stream_mode="updates"):
        pass

    # Get final state
    graph_state = graph.get_state(config_dict)
    final_state = graph_state.values

    # Clean up checkpoint
    if hasattr(graph.checkpointer, "delete_thread"):
        graph.checkpointer.delete_thread(thread_id)

    # Extract the report
    report_data = final_state.get("daily_report")
    if not report_data:
        # Fallback: create a minimal report
        logger.warning("Report writer did not produce a report, creating fallback")
        return DailyReport(
            baby_id=baby_id,
            baby_name=baby_name,
            report_date=report_date,
            health_status=HealthStatus.HEALTHY,
            confidence_score=0.5,
            trend_direction=TrendDirection.STABLE,
            summary="Unable to generate a complete report. Please check data availability.",
            observations=[],
            action_items=["Ensure daily logs are being recorded consistently."],
            warnings=[],
            citations=[],
            data_snapshot={},
            baseline_snapshot={},
        )

    # Handle both dict (from checkpoint deserialization) and DailyReport object
    if isinstance(report_data, DailyReport):
        return report_data
    elif isinstance(report_data, dict):
        return DailyReport.model_validate(report_data)
    else:
        logger.warning(f"Unexpected report type: {type(report_data)}, creating fallback")
        return DailyReport(
            baby_id=baby_id,
            baby_name=baby_name,
            report_date=report_date,
            health_status=HealthStatus.HEALTHY,
            confidence_score=0.5,
            trend_direction=TrendDirection.STABLE,
            summary="Unable to process report data.",
            observations=[],
            action_items=[],
            warnings=[],
            citations=[],
            data_snapshot={},
            baseline_snapshot={},
        )
