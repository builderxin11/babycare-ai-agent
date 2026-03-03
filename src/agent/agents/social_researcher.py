"""Social Researcher agent — Xiaohongshu MCP integration.

Two-tier execution:
  1. MCP URL configured -> _run_mcp()   (XHS MCP search -> LLM synthesize)
     MCP failure        -> falls back to _run_skip()
  2. No MCP URL         -> _run_skip()  (no data, no LLM — just a message)

When no social MCP is configured (or it fails), the agent explicitly reports
that no cross-check was performed rather than fabricating consensus via LLM.
"""

from __future__ import annotations

import logging
from typing import Any

from langchain_core.messages import AIMessage

from agent.config import config
from agent.models.outputs import Citation, SocialInsight, SourceStatus, SourceStatusCode
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


def _extract_chinese_text(text: str) -> str:
    """Extract Chinese characters and common punctuation from mixed text."""
    import re
    # Match Chinese characters, numbers, and common Chinese punctuation
    chinese_pattern = re.compile(r'[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef0-9]+')
    matches = chinese_pattern.findall(text)
    return " ".join(matches)


def _build_search_query(state: AgentState) -> str:
    """Build an optimized XHS search query.

    Strategy:
    1. Extract Chinese text from question (XHS is Chinese-language)
    2. Add baby age in Chinese format
    3. Include medical symptoms/conditions if available
    4. Add top correlations from trend analysis
    5. Keep query focused (max ~100 chars)
    """
    parts: list[str] = []

    # Extract Chinese keywords from question
    question = state.get("question", "")
    if question:
        chinese_q = _extract_chinese_text(question)
        if chinese_q:
            parts.append(chinese_q)
        elif len(question) < 50:
            # Short English question - use as-is
            parts.append(question)

    # Add age context in Chinese
    age = state.get("baby_age_months")
    if age is not None:
        parts.append(f"{age}个月宝宝")

    # Extract key terms from medical insight if available
    medical = state.get("medical_insight")
    if medical and medical.summary:
        medical_chinese = _extract_chinese_text(medical.summary)
        if medical_chinese and len(medical_chinese) < 30:
            parts.append(medical_chinese)

    # Add top correlations from trend analysis
    trend = state.get("trend_analysis")
    if trend and trend.correlations:
        for corr in trend.correlations[:2]:
            parts.append(corr)

    # Join and truncate to reasonable length for search
    query = " ".join(parts)
    if len(query) > 100:
        query = query[:100].rsplit(" ", 1)[0]

    return query


# Module-level MCP session state (lazy-initialized)
_mcp_session: Any = None  # requests.Session
_mcp_session_id: str | None = None
_mcp_request_id: int = 0


def _get_mcp_session() -> tuple[Any, str]:
    """Get or create an initialized MCP session.

    Returns (requests.Session, session_id). Initializes the MCP protocol
    handshake on first call.
    """
    global _mcp_session, _mcp_session_id, _mcp_request_id
    import requests

    if _mcp_session is not None and _mcp_session_id is not None:
        return _mcp_session, _mcp_session_id

    _mcp_session = requests.Session()
    _mcp_request_id = 0

    # Step 1: Initialize
    _mcp_request_id += 1
    init_resp = _mcp_session.post(
        config.xhs_mcp_url,
        json={
            "jsonrpc": "2.0",
            "id": _mcp_request_id,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "nurturemind", "version": "1.0"},
            },
        },
        timeout=15,
    )
    init_resp.raise_for_status()
    _mcp_session_id = init_resp.headers.get("Mcp-Session-Id")
    if not _mcp_session_id:
        raise MCPError("MCP server did not return session ID")

    # Step 2: Send initialized notification
    _mcp_session.post(
        config.xhs_mcp_url,
        headers={"Mcp-Session-Id": _mcp_session_id},
        json={"jsonrpc": "2.0", "method": "notifications/initialized"},
        timeout=15,
    )

    return _mcp_session, _mcp_session_id


def _mcp_call(method: str, params: dict[str, Any]) -> Any:
    """Send a JSON-RPC tools/call request to the XHS MCP server.

    Raises MCPError on JSON-RPC errors, requests exceptions on HTTP failures.
    Import of `requests` is lazy so unconfigured environments never need the dependency.
    """
    global _mcp_request_id

    session, session_id = _get_mcp_session()
    _mcp_request_id += 1

    payload = {
        "jsonrpc": "2.0",
        "id": _mcp_request_id,
        "method": "tools/call",
        "params": {
            "name": method,
            "arguments": params,
        },
    }
    resp = session.post(
        config.xhs_mcp_url,
        headers={"Mcp-Session-Id": session_id},
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()

    body = resp.json()
    if "error" in body:
        raise MCPError(f"MCP error: {body['error']}")

    # tools/call returns result with content array
    result = body.get("result", {})
    content = result.get("content", [])
    if content and isinstance(content, list) and len(content) > 0:
        first = content[0]
        if first.get("type") == "text":
            import json
            try:
                return json.loads(first.get("text", "{}"))
            except json.JSONDecodeError:
                return first.get("text", "")
    return result


def _fetch_xhs_notes(query: str, max_notes: int | None = None) -> tuple[list[dict[str, Any]], int]:
    """Search XHS notes and fetch details for the top ones by engagement.

    Per-note get_note_detail errors are caught individually so one bad note
    doesn't break the entire search.

    Args:
        query: Search keyword
        max_notes: Max notes to fetch (default: config.xhs_max_posts)

    Returns (notes, failed_detail_count).
    """
    if max_notes is None:
        max_notes = config.xhs_max_posts

    search_result = _mcp_call("search_feeds", {"keyword": query})

    # search_feeds returns {"feeds": [...], "count": N}
    if isinstance(search_result, dict):
        raw_items = search_result.get("feeds", search_result.get("items", []))
    elif isinstance(search_result, list):
        raw_items = search_result
    else:
        raw_items = []

    if not raw_items:
        return [], 0

    # Flatten nested noteCard structure for easier processing
    def _flatten_note(item: dict) -> dict:
        """Extract nested noteCard fields to top level for uniform access."""
        note_card = item.get("noteCard", {})
        interact = note_card.get("interactInfo", {})
        user = note_card.get("user", {})
        return {
            "id": item.get("id"),
            "feed_id": item.get("id"),
            "xsec_token": item.get("xsecToken", ""),
            "title": note_card.get("displayTitle", note_card.get("title", "")),
            "author": user.get("nickname", user.get("name", "Anonymous")),
            "likes": int(interact.get("likedCount", 0) or 0),
            "comments": int(interact.get("commentCount", 0) or 0),
            "collects": int(interact.get("collectedCount", 0) or 0),
            "content": note_card.get("desc", ""),  # May be empty in search results
            "_raw": item,  # Keep raw data for detail fetch
        }

    flat_notes = [_flatten_note(item) for item in raw_items]

    # Sort by total engagement (likes + comments + collects)
    def _engagement(note: dict) -> int:
        return note.get("likes", 0) + note.get("comments", 0) + note.get("collects", 0)

    sorted_notes = sorted(flat_notes, key=_engagement, reverse=True)[:max_notes]

    detailed: list[dict[str, Any]] = []
    failed_count = 0
    for note in sorted_notes:
        feed_id = note.get("feed_id")
        xsec_token = note.get("xsec_token", "")
        if not feed_id or not xsec_token:
            detailed.append(note)
            continue
        try:
            detail = _mcp_call("get_feed_detail", {"feed_id": feed_id, "xsec_token": xsec_token})
            if isinstance(detail, dict):
                # Extract content from nested structure: detail["data"]["note"]["desc"]
                data = detail.get("data", {})
                note_data = data.get("note", {})
                content = note_data.get("desc", detail.get("content", detail.get("desc", "")))
                note["content"] = content
                detailed.append(note)
            else:
                detailed.append(note)
        except Exception:
            logger.warning("Failed to fetch detail for feed %s, using summary.", feed_id)
            detailed.append(note)
            failed_count += 1

    return detailed, failed_count


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
        note_id = note.get("id") or note.get("feed_id") or note.get("note_id", "")
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

    data_summary = trend.data_summary if trend and trend.data_summary else "No data available."

    return {
        "baby_name": state.get("baby_name", "Baby"),
        "baby_age_months": str(state.get("baby_age_months", "unknown")),
        "question": state.get("question", ""),
        "medical_summary": medical_summary,
        "trend_summary": trend_summary,
        "data_summary": data_summary,
    }


# ---------------------------------------------------------------------------
# Shared LLM call (used by _run_mcp)
# ---------------------------------------------------------------------------


def _call_llm(state: AgentState, xhs_context_block: str) -> SocialInsight:
    """Invoke ChatBedrockConverse with structured output."""
    # Lazy import so unconfigured environments never touch AWS SDK
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


def _run_mcp(state: AgentState) -> tuple[SocialInsight, SourceStatus]:
    """Full MCP: search XHS notes, then LLM synthesize.

    If MCP retrieval fails or returns no results, falls back to _run_skip().
    If the LLM call itself fails, the exception propagates.

    Returns (insight, source_status).
    """
    notes: list[dict] = []
    failed_detail_count = 0
    try:
        query = _build_search_query(state)
        notes, failed_detail_count = _fetch_xhs_notes(query)
    except Exception:
        logger.warning(
            "XHS MCP retrieval failed; skipping social cross-check.", exc_info=True
        )
        return _run_skip(), SourceStatus(
            source="Social Cross-Check (Xiaohongshu)",
            status=SourceStatusCode.SKIPPED,
            message="Xiaohongshu MCP server was unreachable. Social cross-check was not performed.",
        )

    if not notes:
        logger.info("XHS MCP returned no results; skipping social cross-check.")
        return _run_skip(), SourceStatus(
            source="Social Cross-Check (Xiaohongshu)",
            status=SourceStatusCode.SKIPPED,
            message="Xiaohongshu MCP search returned no results. Social cross-check was not performed.",
        )

    xhs_citations = _extract_citations_from_notes(notes)
    context_block = _format_notes_as_context(notes)
    sample_size = _compute_sample_size(notes)

    # Capture raw post snippets for degraded-mode display
    raw_social_posts = []
    for note in notes:
        title = note.get("title", "Untitled")
        content = note.get("content", note.get("desc", ""))[:300]
        raw_social_posts.append(f"{title}: {content}")

    insight = _call_llm(state, context_block)

    # Merge XHS citations, deduplicating by reference
    existing_refs = {c.reference for c in insight.citations}
    for c in xhs_citations:
        if c.reference not in existing_refs:
            insight.citations.append(c)
            existing_refs.add(c.reference)

    # Override sample_size with real engagement total
    insight.sample_size = sample_size
    insight.raw_social_posts = raw_social_posts

    if failed_detail_count > 0:
        status = SourceStatus(
            source="Social Cross-Check (Xiaohongshu)",
            status=SourceStatusCode.DEGRADED,
            message=(
                f"Retrieved social data but {failed_detail_count} note detail(s) "
                f"failed to load. Results are based on partial data."
            ),
        )
    else:
        status = SourceStatus(
            source="Social Cross-Check (Xiaohongshu)",
            status=SourceStatusCode.OK,
            message=f"Analyzed {len(notes)} top Xiaohongshu posts ({sample_size} total engagements).",
        )

    return insight, status


# ---------------------------------------------------------------------------
# Graph node entry point
# ---------------------------------------------------------------------------


def social_researcher_node(state: AgentState) -> dict:
    """Fetch social consensus on the topic.

    Routes to MCP or skip depending on configuration.
    MCP retrieval errors fall back to skip (no fabricated data).
    Bedrock LLM errors propagate — the graph should surface the failure.
    """
    if config.xhs_mcp_url:
        insight, source_status = _run_mcp(state)
    else:
        insight = _run_skip()
        source_status = SourceStatus(
            source="Social Cross-Check (Xiaohongshu)",
            status=SourceStatusCode.SKIPPED,
            message=(
                "No Xiaohongshu MCP server configured. Social cross-check was not performed."
            ),
        )

    return {
        "social_insight": insight,
        "agents_completed": ["social_researcher"],
        "source_statuses": [source_status],
        "messages": [AIMessage(
            content=f"[social_researcher] {insight.summary}",
            name="social_researcher",
        )],
    }
