# Spec: Medical Expert Agent — Bedrock RAG Implementation

## Status
In Progress

## Problem
The Medical Expert agent (`src/agent/agents/medical_expert.py`) is a stub returning
hardcoded post-vaccine advice regardless of input. This causes eval test cases tc-002
through tc-005 to score poorly (topic mismatch, wrong risk level).

## Solution: Three-Tier Execution

```
medical_expert_node(state)
  ├─ use_mock_data=True  →  _run_stub(state)        # current hardcoded logic, unchanged
  ├─ use_mock_data=False, no KB  →  _run_llm_only(state)  # ChatBedrockConverse only
  └─ use_mock_data=False, KB set →  _run_rag(state)       # KB retrieve → LLM interpret
  └─ any Bedrock exception  →  fallback to _run_stub()
```

### Tier 1: Stub (default)
Exact copy of the existing if/else vaccine-correlation logic. Activated when
`config.use_mock_data=True`. All existing tests and eval remain green.

### Tier 2: LLM-Only
Uses `ChatBedrockConverse` with `with_structured_output(MedicalInsight)` to produce
typed output. No KB retrieval — the LLM reasons from training knowledge alone.
Activated when `use_mock_data=False` and no `BEDROCK_KB_ID` is set.

### Tier 3: Full RAG
1. Build a retrieval query from question + baby age + trend data.
2. `AmazonKnowledgeBasesRetriever` fetches top-5 documents (min confidence 0.4).
3. Format documents as context block.
4. Extract citations from document metadata.
5. Send context + question to LLM for structured reasoning.
Activated when `use_mock_data=False` and `BEDROCK_KB_ID` is set.

## Config Change
New field in `AgentConfig`: `bedrock_kb_id: str = ""` (env: `BEDROCK_KB_ID`).

## Prompt
New `MEDICAL_EXPERT_HUMAN` template with placeholders for baby info, trend data,
and retrieved context block. Instructs LLM to produce JSON matching `MedicalInsight`.

## Key Design Decisions
- Lazy imports for `langchain_aws` — mock mode never touches AWS.
- `temperature=0.1` for medical determinism.
- `min_score_confidence=0.4` — low threshold; let the critique node assess quality.
- KB retrieval failure falls back to LLM-only — still provides reasoned advice.
- Bedrock LLM failure propagates — surfaces the error instead of silently returning hardcoded advice.
- KB citations use `source_type="book"` to satisfy eval's authoritative citation check.

## Files Modified
1. `src/agent/config.py` — add `bedrock_kb_id`
2. `src/agent/prompts/templates.py` — add `MEDICAL_EXPERT_HUMAN`
3. `src/agent/agents/medical_expert.py` — full rewrite with three tiers
4. `tests/test_medical_expert.py` — new test file
