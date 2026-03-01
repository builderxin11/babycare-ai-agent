"""Moderator agent — FUNCTIONAL.

Provides four node functions for the graph:
1. supervisor_node: Sequential dispatch to specialist agents
2. critique_node: Two-tier reflection loop (LLM or rule-based)
3. hitl_node: Human-in-the-loop interrupt gate
4. synthesize_node: Final advice assembly
"""

from __future__ import annotations

import logging

from langchain_core.messages import AIMessage
from langgraph.types import interrupt

from agent.config import config
from agent.models.enums import AgentRole
from agent.models.outputs import (
    Citation,
    CritiqueResult,
    ParentingAdvice,
    RiskLevel,
    SourceStatus,
    SourceStatusCode,
)
from agent.models.state import AgentState
from agent.prompts.templates import CRITIQUE_HUMAN, CRITIQUE_SYSTEM

logger = logging.getLogger(__name__)

# The order in which specialist agents are dispatched
AGENT_SEQUENCE = [
    AgentRole.DATA_SCIENTIST,
    AgentRole.MEDICAL_EXPERT,
    AgentRole.SOCIAL_RESEARCHER,
]


def supervisor_node(state: AgentState) -> dict:
    """Route to the next specialist agent in sequence, or to critique."""
    completed = set(state.get("agents_completed", []))

    for agent in AGENT_SEQUENCE:
        if agent.value not in completed:
            return {
                "next_agent": agent.value,
                "messages": [AIMessage(
                    content=f"[supervisor] Routing to: {agent.value}",
                    name="supervisor",
                )],
            }

    # All specialists done — route to critique
    return {
        "next_agent": AgentRole.CRITIQUE.value,
        "messages": [AIMessage(
            content="[supervisor] All specialists completed. Routing to: critique",
            name="supervisor",
        )],
    }


def _format_agent_output(obj: object) -> str:
    """Serialize a Pydantic model (or None) to readable text for the prompt."""
    if obj is None:
        return "(no output produced)"
    if hasattr(obj, "model_dump_json"):
        return obj.model_dump_json(indent=2)  # type: ignore[union-attr]
    return str(obj)


def _format_critique_prompt(state: AgentState) -> str:
    """Fill CRITIQUE_HUMAN placeholders with agent outputs from the state."""
    return CRITIQUE_HUMAN.format(
        question=state.get("question", "(unknown)"),
        baby_age_months=state.get("baby_age_months", "unknown"),
        trend_analysis=_format_agent_output(state.get("trend_analysis")),
        medical_insight=_format_agent_output(state.get("medical_insight")),
        social_insight=_format_agent_output(state.get("social_insight")),
    )


def _call_critique_llm(state: AgentState) -> CritiqueResult:
    """Invoke Claude Opus via Bedrock to produce a structured CritiqueResult."""
    from langchain_aws import ChatBedrockConverse  # lazy import — mock mode never hits AWS
    from langchain_core.messages import HumanMessage, SystemMessage

    llm = ChatBedrockConverse(
        model=config.opus_model_id,
        region_name=config.aws_region,
        temperature=0,
    )
    structured_llm = llm.with_structured_output(CritiqueResult)

    human_text = _format_critique_prompt(state)
    messages = [
        SystemMessage(content=CRITIQUE_SYSTEM),
        HumanMessage(content=human_text),
    ]
    return structured_llm.invoke(messages)  # type: ignore[return-value]


def _run_rule_based(state: AgentState, iteration: int) -> dict:
    """Deterministic rule-based critique (original logic)."""
    issues: list[str] = []
    suggestions: list[str] = []

    trend = state.get("trend_analysis")
    medical = state.get("medical_insight")
    social = state.get("social_insight")

    # Check completeness
    if not trend:
        issues.append("Missing trend analysis from Data Scientist")
    if not medical:
        issues.append("Missing medical insight from Medical Expert")
    if not social:
        issues.append("Missing social insight from Social Researcher")

    # Check citations
    total_citations = 0
    if trend:
        total_citations += len(trend.citations)
        if not trend.citations:
            issues.append("Trend analysis lacks citations")
    if medical:
        total_citations += len(medical.citations)
        if not medical.citations:
            issues.append("Medical insight lacks citations")
    if social:
        total_citations += len(social.citations)
        if not social.citations:
            issues.append("Social insight lacks citations")

    if total_citations < 3:
        suggestions.append("Increase citation coverage — minimum 3 sources expected")

    # Assess risk
    risk = RiskLevel.LOW
    if medical:
        risk = medical.risk_level

    if risk == RiskLevel.HIGH:
        suggestions.append("High-risk topic detected — ensure conservative recommendations")

    # Compute confidence
    base_confidence = 0.7
    if not issues:
        base_confidence += 0.1
    if total_citations >= 3:
        base_confidence += 0.05
    if trend and trend.correlations:
        base_confidence += 0.05
    # Cap at 0.95
    confidence = min(base_confidence, 0.95)

    # Max iterations check
    approved = len(issues) == 0 or iteration >= config.max_critique_iterations
    if iteration >= config.max_critique_iterations and issues:
        suggestions.append(f"Approved after max iterations ({iteration}) despite issues")

    result = CritiqueResult(
        approved=approved,
        confidence_score=round(confidence, 2),
        issues=issues,
        suggestions=suggestions,
    )

    status_text = "APPROVED" if approved else "REJECTED"

    if iteration >= config.max_critique_iterations and issues:
        source_status = SourceStatus(
            source="Quality Review",
            status=SourceStatusCode.DEGRADED,
            message=(
                f"Advice force-approved after max iterations ({iteration}) "
                f"despite {len(issues)} unresolved issue(s)."
            ),
        )
    else:
        source_status = SourceStatus(
            source="Quality Review",
            status=SourceStatusCode.OK,
            message=f"Advice reviewed using rule-based quality checks (iteration {iteration}).",
        )

    return {
        "critique_result": result,
        "critique_count": iteration,
        "source_statuses": [source_status],
        "messages": [AIMessage(
            content=(
                f"[critique] Iteration {iteration}: {status_text} "
                f"(confidence={result.confidence_score})"
            ),
            name="critique",
        )],
    }


def _run_llm(state: AgentState, iteration: int) -> dict:
    """LLM-based critique via Claude Opus, with rule-based fallback."""
    # Max iterations — force approve regardless of LLM opinion
    if iteration >= config.max_critique_iterations:
        logger.info("Critique max iterations reached (%d), force-approving", iteration)
        return _run_rule_based(state, iteration)

    try:
        result = _call_critique_llm(state)
    except Exception:
        logger.warning("LLM critique failed, falling back to rule-based", exc_info=True)
        fallback_result = _run_rule_based(state, iteration)
        # Override the source status to reflect LLM failure
        fallback_result["source_statuses"] = [SourceStatus(
            source="Quality Review",
            status=SourceStatusCode.FALLBACK,
            message=(
                "AI quality judge was unavailable. "
                "Advice reviewed using rule-based quality checks instead."
            ),
        )]
        return fallback_result

    status_text = "APPROVED" if result.approved else "REJECTED"

    return {
        "critique_result": result,
        "critique_count": iteration,
        "source_statuses": [SourceStatus(
            source="Quality Review",
            status=SourceStatusCode.OK,
            message="Advice reviewed and approved by AI quality judge.",
        )],
        "messages": [AIMessage(
            content=(
                f"[critique/llm] Iteration {iteration}: {status_text} "
                f"(confidence={result.confidence_score})"
            ),
            name="critique",
        )],
    }


def critique_node(state: AgentState) -> dict:
    """Two-tier critique of accumulated agent outputs.

    When use_mock_data=True (default): deterministic rule-based checks.
    When use_mock_data=False: Claude Opus LLM judge with rule-based fallback.
    """
    iteration = (state.get("critique_count") or 0) + 1

    if config.use_mock_data:
        return _run_rule_based(state, iteration)
    return _run_llm(state, iteration)


def hitl_node(state: AgentState) -> dict:
    """Human-in-the-loop gate.

    Calls interrupt() if confidence is below threshold or risk is HIGH.
    The graph will pause here and resume when human feedback is provided.
    """
    critique = state.get("critique_result")
    medical = state.get("medical_insight")

    needs_review = False
    reason = ""

    if critique and critique.confidence_score < config.confidence_threshold:
        needs_review = True
        reason = f"Confidence score ({critique.confidence_score}) below threshold ({config.confidence_threshold})"

    if medical and medical.risk_level == RiskLevel.HIGH:
        needs_review = True
        reason = f"High-risk medical topic: {medical.summary[:100]}"

    if needs_review:
        # This will pause the graph execution
        human_feedback = interrupt({
            "reason": reason,
            "question": state.get("question", ""),
            "confidence": critique.confidence_score if critique else 0.0,
            "message": "Please review and approve or modify the advice before delivery.",
        })
        return {
            "requires_human_review": True,
            "human_review_reason": reason,
            "human_feedback": human_feedback,
            "messages": [AIMessage(
                content=f"[hitl] Human review completed. Feedback: {human_feedback}",
                name="hitl",
            )],
        }

    return {
        "requires_human_review": False,
        "human_review_reason": "",
        "messages": [AIMessage(
            content="[hitl] No human review required. Proceeding to synthesis.",
            name="hitl",
        )],
    }


def synthesize_node(state: AgentState) -> dict:
    """Assemble final ParentingAdvice from all agent outputs."""
    trend = state.get("trend_analysis")
    medical = state.get("medical_insight")
    social = state.get("social_insight")
    critique = state.get("critique_result")

    # Collect all citations
    all_citations: list[Citation] = []
    if trend:
        all_citations.extend(trend.citations)
    if medical:
        all_citations.extend(medical.citations)
    if social:
        all_citations.extend(social.citations)

    # Build key points from each agent
    key_points: list[str] = []
    if trend:
        key_points.append(trend.summary)
    if medical:
        key_points.append(medical.summary)
    if social:
        key_points.append(social.summary)

    # Collect action items from medical recommendations
    action_items: list[str] = []
    if medical:
        action_items.extend(medical.recommendations)

    # Determine risk level
    risk = medical.risk_level if medical else RiskLevel.LOW
    confidence = critique.confidence_score if critique else 0.5

    # Build summary
    question = state.get("question", "")
    baby_name = state.get("baby_name", "your baby")

    summary_parts = []
    if trend and trend.anomalies:
        summary_parts.append(
            f"Our analysis of {baby_name}'s data detected {len(trend.anomalies)} "
            f"anomalies in the past week."
        )
    if trend and trend.correlations:
        summary_parts.append(
            "These changes correlate with a recent context event."
        )
    if medical:
        summary_parts.append(medical.summary)

    summary = " ".join(summary_parts) if summary_parts else "Analysis complete."

    advice = ParentingAdvice(
        question=question,
        summary=summary,
        key_points=key_points,
        action_items=action_items,
        risk_level=risk,
        confidence_score=confidence,
        citations=all_citations,
        sources_used=state.get("source_statuses", []),
    )

    return {
        "final_advice": advice,
        "messages": [AIMessage(
            content=f"[synthesize] Final advice delivered (confidence={confidence})",
            name="synthesize",
        )],
    }
