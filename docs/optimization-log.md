# CalmDownDad — Performance Optimization Log

This document tracks every performance optimization applied to the multi-agent pipeline, including the problem, solution, estimated impact, and implementation details. Each entry represents a deliberate engineering decision to reduce end-to-end latency while preserving output quality.

---

## Optimization #1: Agent Parallelization (Medical Expert || Social Researcher)

**Date:** 2025-06 (initial implementation)
**Commit:** `a7d5196`

### Problem
The original supervisor loop dispatched agents sequentially: `data_scientist → medical_expert → social_researcher`. Medical Expert and Social Researcher are independent of each other — both only depend on Data Scientist output. Running them in sequence wasted time.

### Solution
Replaced the sequential supervisor routing with LangGraph's `Send()` fan-out pattern. After Data Scientist completes, Medical Expert and Social Researcher are dispatched in parallel via `_parallel_dispatch()`. A `join` node with `_join_router()` synchronizes both branches before proceeding to critique.

### Graph Topology Change
```
BEFORE:  START → data_scientist → medical_expert → social_researcher → critique → ...
AFTER:   START → data_scientist → [medical_expert ‖ social_researcher] → join → critique → ...
```

### Key Implementation Details
- `_parallel_dispatch()` returns `[Send("medical_expert", state), Send("social_researcher", state)]`
- `_join_router()` checks `agents_completed` set; returns `"__wait__"` until both agents report in
- `_join_node()` is a no-op barrier node — exists only to synchronize branches

### Impact
- **Latency reduction:** ~40% on the parallel segment (pipeline time = `max(medical, social)` instead of `medical + social`)
- **Estimated saving:** 5-15 seconds depending on KB retrieval and MCP response times
- **Risk:** None — agents were already independent; no shared mutable state

### Files Changed
- `src/agent/graph/builder.py` — new graph topology with `Send()` fan-out and join node

---

## Optimization #2: Critique Model Downgrade (Opus → Sonnet)

**Date:** 2026-03-07

### Problem
The critique node used Claude Opus (`us.anthropic.claude-opus-4-6-v1`) for structured output quality review. Opus is 3-5x slower than Sonnet for inference, and the critique task (approve/reject + confidence score + issue list) does not require Opus-level reasoning. This was the single largest latency bottleneck in the pipeline.

### Solution
Changed `_call_critique_llm()` in `moderator.py` to use `config.sonnet_model_id` instead of `config.opus_model_id`. The critique still uses LLM-based structured output (`with_structured_output(CritiqueResult)`), but on a faster model.

### Why This Is Safe
1. The critique has a **rule-based fallback** (`_run_rule_based()`) that activates if the LLM call fails — quality floor is preserved
2. The critique checks are well-defined: completeness, citation count, risk assessment, contradiction detection — these are pattern-matching tasks well within Sonnet's capability
3. Max iterations (`max_critique_iterations=2`) caps worst-case re-runs regardless of model quality
4. The three-source confidence model is computed by deterministic Python code, not the LLM

### Impact
- **Latency reduction:** 8-15 seconds per critique iteration (Opus → Sonnet inference time difference)
- **Total saving:** 8-30 seconds (1-2 critique iterations per request)
- **Risk:** Low. Sonnet may occasionally miss subtle quality issues that Opus would catch, but the rule-based fallback covers structural checks. Opus is still used for the eval judge (`EVAL_JUDGE_MODE=llm_based`), so quality regression is detectable.

### Files Changed
- `src/agent/agents/moderator.py` — `_call_critique_llm()`: `config.opus_model_id` → `config.sonnet_model_id`

---

## Optimization #3: Parallel XHS Note Detail Fetching

**Date:** 2026-03-07

### Problem
The Social Researcher fetches top Xiaohongshu posts via MCP. After the initial `search_feeds` call returns a list, the agent calls `get_feed_detail` for each post **sequentially** to retrieve full content. With `xhs_max_posts=5` and each detail fetch taking 2-5 seconds, this loop alone costs 10-25 seconds.

### Solution
Replaced the sequential `for note in sorted_notes` loop in `_fetch_xhs_notes()` with `concurrent.futures.ThreadPoolExecutor`. All detail fetches now run in parallel with `max_workers=min(len(notes), 5)`. Results are collected back in original order using an index mapping.

### Key Implementation Details
- `_fetch_one(note)` is a self-contained function that fetches one note's detail and handles its own errors
- `future_to_idx` dict preserves original sort order (engagement-ranked) after parallel completion
- Per-note error isolation is preserved: one failed detail fetch doesn't break others
- Thread pool is scoped with `with` statement for clean shutdown

### Code Change
```python
# BEFORE: Sequential (10-25s for 5 posts)
for note in sorted_notes:
    detail = _mcp_call("get_feed_detail", {...})
    ...

# AFTER: Parallel (~2-5s for 5 posts)
with ThreadPoolExecutor(max_workers=min(len(sorted_notes), 5)) as executor:
    future_to_idx = {executor.submit(_fetch_one, note): i for i, note in enumerate(sorted_notes)}
    for future in as_completed(future_to_idx):
        results[future_to_idx[future]] = future.result()
```

### Impact
- **Latency reduction:** 8-20 seconds (5 sequential fetches → 1 parallel batch)
- **Estimated saving:** From `N × avg_fetch_time` to `max(fetch_times)` where N = `xhs_max_posts`
- **Risk:** Low. MCP server handles concurrent requests fine. Error isolation per note is preserved.

### Files Changed
- `src/agent/agents/social_researcher.py` — `_fetch_xhs_notes()`: sequential loop → `ThreadPoolExecutor`

---

## Optimization #4: SSE Streaming Endpoint

**Date:** 2026-03-07

### Problem
The `/ask` API endpoint waits for the entire multi-agent pipeline to complete before returning a response. From the user's perspective, they see nothing for 15-35 seconds, then get the full answer at once. This creates a poor perceived latency even when actual computation is reasonable.

### Solution
Added a new `POST /ask/stream` endpoint that returns a Server-Sent Events (SSE) stream. Each agent node completion emits an event immediately, so the client sees real-time progress.

### SSE Event Types
| Event | Payload | When |
|-------|---------|------|
| `agent` | `{"node": "data_scientist", "message": "[data_scientist] Analyzed 7 days..."}` | Each agent node completes |
| `result` | Full `AskResponse` JSON | Pipeline finishes successfully |
| `error` | `{"detail": "..."}` | Pipeline failure |

### Client Usage Example
```javascript
const evtSource = new EventSource('/ask/stream', {method: 'POST', body: JSON.stringify(req)});

evtSource.addEventListener('agent', (e) => {
  const {node, message} = JSON.parse(e.data);
  showProgress(node, message);  // Update UI immediately
});

evtSource.addEventListener('result', (e) => {
  const advice = JSON.parse(e.data);
  showFinalAdvice(advice);
});
```

### Key Implementation Details
- Uses `StreamingResponse` with `media_type="text/event-stream"`
- Sets `Cache-Control: no-cache` and `X-Accel-Buffering: no` to prevent proxy buffering
- HITL auto-approve logic is replicated in the streaming path
- Checkpoint cleanup runs after the stream completes
- The original `/ask` endpoint is preserved for backward compatibility

### Impact
- **Actual latency reduction:** 0 seconds (total compute time is the same)
- **Perceived latency reduction:** Significant — user sees first result within 1-2 seconds instead of waiting 15-35 seconds
- **Risk:** None. This is additive (new endpoint); existing `/ask` is unchanged.

### Files Changed
- `src/api/server.py` — new `POST /ask/stream` endpoint with `StreamingResponse`

---

## Cumulative Impact Summary

| Optimization | Actual Latency Saved | Perceived Latency Saved |
|-------------|---------------------|------------------------|
| Agent Parallelization | 5-15s | 5-15s |
| Critique Opus → Sonnet | 8-15s | 8-15s |
| Parallel XHS Fetch | 8-20s | 8-20s |
| SSE Streaming | 0s | 15-35s (first visible result in ~1s) |
| **Total** | **~20-50s** | **Near-instant first feedback** |

### Before vs After
```
BEFORE: ~35-70s end-to-end, user sees nothing until complete
AFTER:  ~15-25s end-to-end, user sees progress within 1-2s
```

---

## Future Optimization Candidates

### Response Caching (Not Implemented)
Cache frequently asked questions (e.g., "is post-vaccine fever normal?") with TTL. Would eliminate LLM calls entirely for repeat queries. Trade-off: cache invalidation complexity, stale medical advice risk.

### Critique Skip for High-Confidence (Not Implemented)
If the rule-based pre-check yields confidence > 0.9 with zero issues, skip the LLM critique entirely. Would save 3-8s on easy questions. Trade-off: reduced safety net.

### Model Routing by Complexity (Not Implemented)
Use Haiku for simple questions (single topic, no anomalies) and Sonnet only for complex multi-factor queries. Would save 2-5s per agent on simple cases. Trade-off: complexity classifier needed, risk of misrouting.
