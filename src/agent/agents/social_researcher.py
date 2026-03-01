"""Social Researcher agent — Xiaohongshu MCP integration.

Three-tier execution:
  1. use_mock_data=True              -> _run_stub()       (hardcoded, no AWS/MCP)
  2. use_mock_data=False, no MCP URL -> _run_skip()        (no data, no LLM — just a message)
  3. use_mock_data=False, MCP URL set -> _run_mcp()       (XHS MCP search -> LLM synthesize)
      MCP failure                    -> falls back to _run_skip()

When no social MCP is configured (or it fails), the agent explicitly reports
that no cross-check was performed rather than fabricating consensus via LLM.
"""

from __future__ import annotations

import logging
from typing import Any

from langchain_core.messages import AIMessage

from agent.config import config
from agent.models.outputs import Citation, SocialInsight
from agent.models.state import AgentState
from agent.prompts.templates import SOCIAL_RESEARCHER_HUMAN, SOCIAL_RESEARCHER_SYSTEM

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Custom exception
# ---------------------------------------------------------------------------


class MCPError(Exception):
    """Raised when the XHS MCP server returns a JSON-RPC error."""


# ---------------------------------------------------------------------------
# Helper functions (pure, unit-testable)
# ---------------------------------------------------------------------------


def _build_search_query(state: AgentState) -> str:
    """Combine question + Chinese age format + top-2 correlations into a search query."""
    parts: list[str] = []

    question = state.get("question", "")
    if question:
        parts.append(question)

    age = state.get("baby_age_months")
    if age is not None:
        parts.append(f"{age}个月宝宝")

    trend = state.get("trend_analysis")
    if trend and trend.correlations:
        for corr in trend.correlations[:2]:
            parts.append(corr)

    return " ".join(parts)


def _mcp_call(method: str, params: dict[str, Any]) -> Any:
    """Send a JSON-RPC request to the XHS MCP server.

    Raises MCPError on JSON-RPC errors, requests exceptions on HTTP failures.
    Import of `requests` is lazy so stub mode never needs the dependency.
    """
    import requests

    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params,
    }
    resp = requests.post(config.xhs_mcp_url, json=payload, timeout=15)
    resp.raise_for_status()

    body = resp.json()
    if "error" in body:
        raise MCPError(f"MCP error: {body['error']}")

    return body.get("result", [])


def _fetch_xhs_notes(query: str, max_notes: int = 3) -> list[dict[str, Any]]:
    """Search XHS notes and fetch details for the top ones by engagement.

    Per-note get_note_detail errors are caught individually so one bad note
    doesn't break the entire search.
    """
    raw_notes = _mcp_call("search_notes", {"keyword": query})

    if not raw_notes:
        return []

    # Sort by total engagement (likes + comments + collects)
    def _engagement(note: dict) -> int:
        return (
            note.get("likes", 0)
            + note.get("comments", 0)
            + note.get("collects", 0)
        )

    sorted_notes = sorted(raw_notes, key=_engagement, reverse=True)[:max_notes]

    detailed: list[dict[str, Any]] = []
    for note in sorted_notes:
        note_id = note.get("id") or note.get("note_id")
        if not note_id:
            detailed.append(note)
            continue
        try:
            detail = _mcp_call("get_note_detail", {"note_id": note_id})
            if isinstance(detail, dict):
                detailed.append(detail)
            else:
                detailed.append(note)
        except Exception:
            logger.warning("Failed to fetch detail for note %s, using summary.", note_id)
            detailed.append(note)

    return detailed


def _format_notes_as_context(notes: list[dict[str, Any]]) -> str:
    """Format XHS notes as numbered markdown sections for the prompt."""
    if not notes:
        return "No Xiaohongshu posts were found for this topic."

    sections: list[str] = []
    for i, note in enumerate(notes, 1):
        author = note.get("author", note.get("user", {}).get("nickname", "Anonymous"))
        likes = note.get("likes", 0)
        comments = note.get("comments", 0)
        collects = note.get("collects", 0)
        title = note.get("title", "Untitled")
        content = note.get("content", note.get("desc", ""))[:1000]

        sections.append(
            f"### Post {i}: {title}\n"
            f"**Author:** {author} | "
            f"**Engagement:** {likes} likes, {comments} comments, {collects} collects\n\n"
            f"{content}"
        )

    return "\n\n".join(sections)


def _extract_citations_from_notes(notes: list[dict[str, Any]]) -> list[Citation]:
    """Build Citation objects from XHS note data."""
    citations: list[Citation] = []
    for note in notes:
        title = note.get("title", "Untitled XHS Post")
        author = note.get("author", note.get("user", {}).get("nickname", "Anonymous"))
        note_id = note.get("id") or note.get("note_id", "")
        citations.append(
            Citation(
                source_type="xhs_post",
                reference=f"XHS: {title} (by {author})",
                detail=f"Note ID: {note_id}" if note_id else None,
            )
        )
    return citations


def _compute_sample_size(notes: list[dict[str, Any]]) -> int:
    """Sum engagement (likes+comments+collects) across all notes."""
    total = 0
    for note in notes:
        total += (
            note.get("likes", 0)
            + note.get("comments", 0)
            + note.get("collects", 0)
        )
    return total


def _format_prompt_context(state: AgentState) -> dict[str, str]:
    """Extract baby info, medical summary, and trend summary from state."""
    medical = state.get("medical_insight")
    medical_summary = medical.summary if medical else "No medical assessment available yet."

    trend = state.get("trend_analysis")
    trend_summary = trend.summary if trend else "No trend analysis available."

    return {
        "baby_name": state.get("baby_name", "Baby"),
        "baby_age_months": str(state.get("baby_age_months", "unknown")),
        "question": state.get("question", ""),
        "medical_summary": medical_summary,
        "trend_summary": trend_summary,
    }


# ---------------------------------------------------------------------------
# Shared LLM call (used by _run_mcp)
# ---------------------------------------------------------------------------


def _call_llm(state: AgentState, xhs_context_block: str) -> SocialInsight:
    """Invoke ChatBedrockConverse with structured output."""
    # Lazy import so mock mode never touches AWS SDK
    from langchain_aws import ChatBedrockConverse

    llm = ChatBedrockConverse(
        model=config.sonnet_model_id,
        region_name=config.aws_region,
        temperature=0.3,
    )
    structured_llm = llm.with_structured_output(SocialInsight)

    ctx = _format_prompt_context(state)
    human_msg = SOCIAL_RESEARCHER_HUMAN.format(
        xhs_context_block=xhs_context_block,
        **ctx,
    )

    return structured_llm.invoke([
        {"role": "system", "content": SOCIAL_RESEARCHER_SYSTEM},
        {"role": "user", "content": human_msg},
    ])


# ---------------------------------------------------------------------------
# Execution tiers
# ---------------------------------------------------------------------------


def _run_stub(state: AgentState) -> SocialInsight:
    """Return hardcoded XHS consensus (original stub logic)."""
    trend = state.get("trend_analysis")

    has_vaccine_topic = False
    if trend and trend.correlations:
        has_vaccine_topic = any(
            "VACCINE" in c.upper() for c in trend.correlations
        )

    if has_vaccine_topic:
        return SocialInsight(
            summary=(
                "Among 500+ Xiaohongshu posts about post-vaccine baby care, "
                "the overwhelming consensus (92%) reports that reduced feeding and "
                "increased sleepiness for 1-3 days after DTaP is normal. "
                "Parents recommend extra cuddles, skin-to-skin contact, and patience."
            ),
            consensus_points=[
                "92% of parents report temporary appetite reduction lasting 1-3 days",
                "85% observed increased sleepiness, averaging 1-2 extra hours/day",
                "70% used cool compresses on the injection site to reduce fussiness",
                "Key minority view (8%): some babies show NO behavioral changes post-vaccine",
            ],
            sample_size=523,
            citations=[
                Citation(
                    source_type="xhs_post",
                    reference="XHS Consensus: Post-DTaP Baby Care (N=523)",
                    detail="Aggregated from top-rated posts in #婴儿疫苗 and #宝宝打针后 tags",
                ),
            ],
        )

    return SocialInsight(
        summary=(
            "Among parenting communities, feeding pattern changes in 4-month-olds "
            "are commonly discussed. Most parents report this as a normal phase."
        ),
        consensus_points=[
            "Feeding variations are common during the 4-month sleep regression",
            "Growth spurts can temporarily alter feeding patterns",
        ],
        sample_size=150,
        citations=[
            Citation(
                source_type="xhs_post",
                reference="XHS Consensus: 4-Month Baby Feeding (N=150)",
                detail="Aggregated from #四个月宝宝 tag",
            ),
        ],
    )


_SKIP_SUMMARY = (
    "No social media or BBS linked, so no cross-check was done. "
    "If you want to enable social media cross-referencing, please refer to "
    ".q/specs/social-researcher-xhs-mcp.md for the XHS MCP setup guide."
)


def _run_skip() -> SocialInsight:
    """Return a clear 'not configured' message — no LLM call, no fabricated data."""
    return SocialInsight(
        summary=_SKIP_SUMMARY,
        consensus_points=[],
        sample_size=0,
        citations=[],
    )


def _run_mcp(state: AgentState) -> SocialInsight:
    """Full MCP: search XHS notes, then LLM synthesize.

    If MCP retrieval fails or returns no results, falls back to _run_skip().
    If the LLM call itself fails, the exception propagates.
    """
    notes: list[dict] = []
    try:
        query = _build_search_query(state)
        notes = _fetch_xhs_notes(query)
    except Exception:
        logger.warning(
            "XHS MCP retrieval failed; skipping social cross-check.", exc_info=True
        )
        return _run_skip()

    if not notes:
        logger.info("XHS MCP returned no results; skipping social cross-check.")
        return _run_skip()

    xhs_citations = _extract_citations_from_notes(notes)
    context_block = _format_notes_as_context(notes)
    sample_size = _compute_sample_size(notes)

    insight = _call_llm(state, context_block)

    # Merge XHS citations, deduplicating by reference
    existing_refs = {c.reference for c in insight.citations}
    for c in xhs_citations:
        if c.reference not in existing_refs:
            insight.citations.append(c)
            existing_refs.add(c.reference)

    # Override sample_size with real engagement total
    insight.sample_size = sample_size

    return insight


# ---------------------------------------------------------------------------
# Graph node entry point
# ---------------------------------------------------------------------------


def social_researcher_node(state: AgentState) -> dict:
    """Fetch social consensus on the topic.

    Routes to stub, skip, or full MCP depending on configuration.
    MCP retrieval errors fall back to skip (no fabricated data).
    Bedrock LLM errors propagate — the graph should surface the failure.
    """
    if config.use_mock_data:
        insight = _run_stub(state)
    elif config.xhs_mcp_url:
        insight = _run_mcp(state)
    else:
        insight = _run_skip()

    return {
        "social_insight": insight,
        "agents_completed": ["social_researcher"],
        "messages": [AIMessage(
            content=f"[social_researcher] {insight.summary}",
            name="social_researcher",
        )],
    }
