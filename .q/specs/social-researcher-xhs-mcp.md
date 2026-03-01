# Spec: Social Researcher Agent — Xiaohongshu MCP Integration

## Status
In Progress

## Problem
The Social Researcher agent (`src/agent/agents/social_researcher.py`) is a stub returning
hardcoded Xiaohongshu-style consensus data regardless of input. It needs integration with
the Xiaohongshu MCP server (`xpzouying/xiaohongshu-mcp`) to search real posts and
synthesize social consensus via LLM.

## Solution: Three-Tier Execution

```
social_researcher_node(state)
  ├─ use_mock_data=True                → _run_stub(state)       # current hardcoded logic, unchanged
  ├─ use_mock_data=False, no MCP URL   → _run_llm_only(state)   # ChatBedrockConverse, no XHS data
  └─ use_mock_data=False, MCP URL set  → _run_mcp(state)        # XHS MCP search → LLM synthesize
      ├─ MCP failure                   → fallback to _run_llm_only()
      └─ LLM failure                   → propagates (no silent fallback)
```

### Tier 1: Stub (default)
Exact copy of the existing if/else vaccine-correlation logic. Activated when
`config.use_mock_data=True`. All existing tests and eval remain green.

### Tier 2: LLM-Only
Uses `ChatBedrockConverse` with `with_structured_output(SocialInsight)` to produce
typed output. No XHS data — the LLM reasons from training knowledge alone.
Activated when `use_mock_data=False` and no `XHS_MCP_URL` is set.

### Tier 3: Full MCP
1. Build a Chinese-language search query from question + baby age + top-2 correlations.
2. Call XHS MCP `search_notes` via JSON-RPC over HTTP.
3. Sort results by engagement (likes+comments+collects), take top 3.
4. Call `get_note_detail` for each note.
5. Format notes as markdown context block.
6. Send context + question to LLM for structured reasoning → `SocialInsight`.
7. Merge citations from notes, override `sample_size` with real engagement total.

## MCP Communication
Uses `requests.post()` to call the MCP server's JSON-RPC endpoint directly
(e.g. `http://localhost:18060/mcp`). This avoids async complexity and the
`langchain-mcp-adapters` dependency.

## Config Change
New field in `AgentConfig`: `xhs_mcp_url: str = ""` (env: `XHS_MCP_URL`).

## Key Design Decisions
- Lazy `import requests` inside `_mcp_call()` — mock mode never needs it.
- `temperature=0.3` — slightly higher than medical (0.1) for social nuance.
- Top 3 notes by engagement (likes+comments+collects).
- Per-note `get_note_detail` errors are caught individually — one bad note doesn't break the search.
- 15s timeout per MCP call, 4 calls max = ~60s worst case.
- `sample_size` overridden with real engagement total in MCP mode.
- MCP failure falls back to LLM-only — still provides reasoned advice.
- Bedrock LLM failure propagates — surfaces the error.

## Files Modified
1. `src/agent/config.py` — add `xhs_mcp_url`
2. `src/agent/prompts/templates.py` — add `SOCIAL_RESEARCHER_HUMAN`
3. `src/agent/agents/social_researcher.py` — full rewrite with three tiers
4. `tests/test_social_researcher.py` — new test file
