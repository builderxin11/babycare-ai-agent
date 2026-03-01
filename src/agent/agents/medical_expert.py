"""Medical Expert agent — Bedrock RAG implementation.

Three-tier execution:
  1. use_mock_data=True        -> _run_stub()       (hardcoded, no AWS)
  2. use_mock_data=False, no KB -> _run_llm_only()   (ChatBedrockConverse, no retrieval)
  3. use_mock_data=False, KB set -> _run_rag()        (KB retrieve -> LLM interpret)

Any Bedrock exception falls back to _run_stub() so the graph never crashes.
"""

from __future__ import annotations

import logging
import re
from typing import TYPE_CHECKING

from langchain_core.messages import AIMessage

from agent.config import config
from agent.models.outputs import Citation, MedicalInsight, RiskLevel
from agent.models.state import AgentState
from agent.prompts.templates import MEDICAL_EXPERT_HUMAN, MEDICAL_EXPERT_SYSTEM

if TYPE_CHECKING:
    from langchain_core.documents import Document

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helper functions (pure, unit-testable)
# ---------------------------------------------------------------------------


def _build_retrieval_query(state: AgentState) -> str:
    """Combine question, baby age, and trend data into a KB retrieval query."""
    parts: list[str] = []

    question = state.get("question", "")
    if question:
        parts.append(question)

    age = state.get("baby_age_months")
    if age is not None:
        parts.append(f"{age}-month-old infant")

    trend = state.get("trend_analysis")
    if trend:
        if trend.summary:
            parts.append(trend.summary)
        # Include up to 3 correlations for relevance
        for corr in trend.correlations[:3]:
            parts.append(corr)

    return " ".join(parts)


def _format_docs_as_context(docs: list[Document]) -> str:
    """Format retrieved KB documents as numbered markdown sections."""
    if not docs:
        return "No relevant documents were retrieved from the knowledge base."

    sections: list[str] = []
    for i, doc in enumerate(docs, 1):
        score = doc.metadata.get("score", "N/A")
        source = doc.metadata.get("source", doc.metadata.get("location", {}).get("s3Location", {}).get("uri", "unknown"))
        content = doc.page_content[:2000]  # Truncate very long passages
        sections.append(
            f"### Document {i} (relevance: {score})\n"
            f"**Source:** {source}\n\n"
            f"{content}"
        )
    return "\n\n".join(sections)


def _extract_citations_from_docs(docs: list[Document]) -> list[Citation]:
    """Build Citation objects from KB document metadata."""
    citations: list[Citation] = []
    for doc in docs:
        # Try to get URI from various metadata shapes
        uri = doc.metadata.get("source", "")
        if not uri:
            location = doc.metadata.get("location", {})
            s3_loc = location.get("s3Location", {})
            uri = s3_loc.get("uri", "")

        if uri:
            # Derive human-readable reference from S3 key or URL
            reference = _humanize_uri(uri)
        else:
            reference = "Knowledge Base Document"

        detail = doc.page_content[:200] if doc.page_content else None

        citations.append(
            Citation(
                source_type="book",
                reference=reference,
                detail=detail,
            )
        )
    return citations


def _humanize_uri(uri: str) -> str:
    """Convert an S3 URI or URL into a human-readable reference string."""
    # Extract filename from s3://bucket/path/to/file.pdf or https://...
    match = re.search(r"[/\\]([^/\\]+?)(?:\.\w+)?$", uri)
    if match:
        name = match.group(1)
        # Convert hyphens/underscores to spaces, title case
        return name.replace("-", " ").replace("_", " ").title()
    return uri


def _format_trend_for_prompt(state: AgentState) -> dict[str, str]:
    """Extract trend analysis fields formatted for the prompt template."""
    trend = state.get("trend_analysis")
    if not trend:
        return {
            "trend_summary": "No trend analysis available.",
            "anomalies": "None detected.",
            "correlations": "None detected.",
        }

    anomaly_lines = []
    for a in trend.anomalies:
        anomaly_lines.append(
            f"- {a.date}: {a.metric} = {a.value} "
            f"(baseline {a.baseline}, {a.deviation_pct:+.1f}% deviation) — {a.description}"
        )

    corr_lines = [f"- {c}" for c in trend.correlations] if trend.correlations else ["- None"]

    return {
        "trend_summary": trend.summary,
        "anomalies": "\n".join(anomaly_lines) if anomaly_lines else "None detected.",
        "correlations": "\n".join(corr_lines),
    }


# ---------------------------------------------------------------------------
# Shared LLM call (used by _run_llm_only and _run_rag)
# ---------------------------------------------------------------------------


def _call_llm(state: AgentState, context_block: str) -> MedicalInsight:
    """Invoke ChatBedrockConverse with structured output."""
    # Lazy import so mock mode never touches AWS SDK
    from langchain_aws import ChatBedrockConverse

    llm = ChatBedrockConverse(
        model=config.sonnet_model_id,
        region_name=config.aws_region,
        temperature=0.1,
    )
    structured_llm = llm.with_structured_output(MedicalInsight)

    trend_fields = _format_trend_for_prompt(state)
    human_msg = MEDICAL_EXPERT_HUMAN.format(
        baby_name=state.get("baby_name", "Baby"),
        baby_age_months=state.get("baby_age_months", "unknown"),
        question=state.get("question", ""),
        context_block=context_block,
        **trend_fields,
    )

    return structured_llm.invoke([
        {"role": "system", "content": MEDICAL_EXPERT_SYSTEM},
        {"role": "user", "content": human_msg},
    ])


# ---------------------------------------------------------------------------
# Execution tiers
# ---------------------------------------------------------------------------


def _run_stub(state: AgentState) -> MedicalInsight:
    """Return hardcoded post-vaccine guidance (original stub logic)."""
    trend = state.get("trend_analysis")

    has_vaccine_correlation = False
    if trend and trend.correlations:
        has_vaccine_correlation = any(
            "VACCINE" in c.upper() for c in trend.correlations
        )

    if has_vaccine_correlation:
        return MedicalInsight(
            summary=(
                "Post-vaccination behavioral changes (reduced feeding, increased sleepiness) "
                "are normal and expected within 48-72 hours of DTaP vaccination. "
                "These are signs of a healthy immune response."
            ),
            risk_level=RiskLevel.LOW,
            recommendations=[
                "Continue offering regular feedings; slight reduction (10-20%) is normal post-vaccine.",
                "Extra sleep is expected — allow baby to rest but maintain wake windows for feeding.",
                "Monitor for fever; acetaminophen (infant Tylenol) may be given per pediatrician's dosing.",
                "Seek immediate care if: fever >101\u00b0F persists >48h, inconsolable crying >3h, or refusal to eat >24h.",
            ],
            citations=[
                Citation(
                    source_type="book",
                    reference="AAP Immunization Guide, Chapter 4: Post-Vaccination Care",
                    detail="Expected side effects of DTaP in infants 2-6 months",
                ),
                Citation(
                    source_type="medical",
                    reference="CDC Vaccine Information Statement: DTaP",
                    detail="Common reactions and when to call the doctor",
                ),
            ],
        )

    return MedicalInsight(
        summary=(
            "The observed changes in feeding and sleep patterns should be monitored. "
            "For a 4-month-old, variations can be related to growth spurts or developmental milestones."
        ),
        risk_level=RiskLevel.LOW,
        recommendations=[
            "Track feeding volumes for the next 48 hours.",
            "Ensure adequate wet diapers (6+ per day) as hydration indicator.",
            "Consult pediatrician if patterns persist beyond 3 days.",
        ],
        citations=[
            Citation(
                source_type="book",
                reference="AAP Bright Futures: Nutrition, 4th Edition",
                detail="Normal feeding variation in 4-month-olds",
            ),
        ],
    )


def _run_llm_only(state: AgentState) -> MedicalInsight:
    """Use ChatBedrockConverse without KB retrieval."""
    context_block = (
        "No knowledge base configured. Reason from your medical training knowledge. "
        "Cite well-known authoritative sources (AAP, CDC, WHO) where applicable."
    )
    return _call_llm(state, context_block)


def _run_rag(state: AgentState) -> MedicalInsight:
    """Full RAG: retrieve from Bedrock KB, then LLM interpret.

    If KB retrieval fails, falls back to LLM-only (no retrieval).
    If the LLM call itself fails, the exception propagates.
    """
    # Lazy import so mock mode never touches AWS SDK
    from langchain_aws import AmazonKnowledgeBasesRetriever

    docs: list[Document] = []
    try:
        retriever = AmazonKnowledgeBasesRetriever(
            knowledge_base_id=config.bedrock_kb_id,
            retrieval_config={
                "vectorSearchConfiguration": {
                    "numberOfResults": 5,
                    "overrideSearchType": "HYBRID",
                }
            },
            min_score_confidence=0.4,
            region_name=config.aws_region,
        )

        query = _build_retrieval_query(state)
        docs = retriever.invoke(query)
    except Exception:
        logger.warning(
            "KB retrieval failed; falling back to LLM-only.", exc_info=True
        )
        return _run_llm_only(state)

    kb_citations = _extract_citations_from_docs(docs)
    context_block = _format_docs_as_context(docs)

    insight = _call_llm(state, context_block)

    # Merge KB citations, deduplicating by reference
    existing_refs = {c.reference for c in insight.citations}
    for c in kb_citations:
        if c.reference not in existing_refs:
            insight.citations.append(c)
            existing_refs.add(c.reference)

    return insight


# ---------------------------------------------------------------------------
# Graph node entry point
# ---------------------------------------------------------------------------


def medical_expert_node(state: AgentState) -> dict:
    """Provide medical guidance based on trend analysis.

    Routes to stub, LLM-only, or full RAG depending on configuration.
    KB retrieval errors fall back to LLM-only.
    Bedrock LLM errors propagate — the graph should surface the failure.
    """
    if config.use_mock_data:
        insight = _run_stub(state)
    elif config.bedrock_kb_id:
        insight = _run_rag(state)
    else:
        insight = _run_llm_only(state)

    return {
        "medical_insight": insight,
        "agents_completed": ["medical_expert"],
        "messages": [AIMessage(
            content=f"[medical_expert] {insight.summary}",
            name="medical_expert",
        )],
    }
