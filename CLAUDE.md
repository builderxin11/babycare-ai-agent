# CLAUDE.md - CalmDownDad Engineering Standards

## 1. Project Vision & Mission
Build a production-grade **Multi-Agent System (MAS)** for parenting. The goal is to move beyond simple RAG to a **Reasoning & Reflection** architecture that handles data conflict and long-term state.

## 2. Multi-Agent Orchestration (Core Requirement)
**DO NOT use single-prompt chains.** All reasoning must follow the **Multi-Agent Swarm** pattern in LangGraph:
- **Data Scientist Agent:** Analyzes `PhysiologyLog` trends using statistical methods (not just LLM intuition).
- **Pediatric Expert Agent:** Performs RAG on Bedrock Knowledge Bases (Books).
- **Social Researcher Agent:** Uses **Xiaohongshu MCP** to fetch social consensus.
- **Moderator Agent:** Orchestrates other agents, resolves conflicts, and generates final advice.
- **Reflection Loop:** Every advice must pass a `CritiqueNode` before delivery.

## 3. Evaluation-First Development (P0)
**Evaluation is the source of truth.** All Agent changes must be validated against the **Eval Framework**:
- **Gold Dataset:** Located in `eval/gold_dataset.json`.
- **Judge Agent:** Use `Claude 4.6 Opus` as the judge to score outputs on **Safety (1-5)**, **Medical Accuracy (1-5)**, and **Source Grounding (1-5)**.
- **Regression:** Before merging features, run `python src/eval/judge.py` to ensure no quality regression.

## 4. Technical Stack & Commands
- **Backend:** AWS Amplify Gen 2, LangGraph, PydanticAI.
- **Model:** Amazon Bedrock `us.anthropic.claude-sonnet-4-20250514-v1:0` (for sub-agents) and `us.anthropic.claude-opus-4-6-v1` (for Moderator/Judge).
- **Persistence:** DynamoDB-backed `LangGraph Checkpointer` for async HITL.
- **Commands:**
    - Sync Sandbox: `npx ampx sandbox`
    - Run Eval: `pytest src/eval/`
    - Start MCP: `mcp run xpzouying/xiaohongshu-mcp`

## 5. Implementation Rules (Strict)
1. **Type Safety:** Strict TypeScript for Amplify; Pydantic V3 for all Python Agent States.
2. **State Persistence:** Use `langgraph-checkpoint-aws`. All Graph threads must be resumable.
3. **Sequential RAG:** Follow strict sequence: Authority (Books) -> Validation (Social Proof). 
4. **Citations:** Every claim MUST cite its source (e.g., `[AAP Book, p.42]` or `[XHS Consensus]`).
5. **Human-in-the-loop:** Use `__interrupt__` for any advice with a `ConfidenceScore < 0.8` or high-risk medical topics.

## 6. Architecture Overview


## 7. Future Features (Planned)

### Daily Health Report (P1)
Automated daily analysis that runs at end-of-day on the baby's logged data and generates a proactive report for parents. This is a **push** model (system initiates) vs the current **pull** model (parent asks a question).

**Requirements:**
- Trigger: Scheduled (e.g., 9 PM daily) or when enough new PhysiologyLog entries accumulate.
- Input: That day's PhysiologyLog + ContextEvent data for the baby, plus rolling 7-day baseline.
- Output: A structured `DailyReport` containing:
  - Overall health status (healthy / monitor / concern)
  - Key observations (e.g., "Feeding volume recovered to baseline after 2 days of post-vaccine dip")
  - Trend comparisons vs. the past 7 days (improving / stable / declining)
  - Actionable tips tailored to the day's data (e.g., "Consider offering an extra feed before bedtime")
  - Flags for anything that warrants pediatrician attention
- Must reuse the existing multi-agent pipeline: Data Scientist for trends → Medical Expert for interpretation → Critique for safety review.
- Must work even without a parent question — the agents need to self-generate the "question" from the data.
- Store reports in a new `DailyReport` DynamoDB table linked to Baby, so parents can review history.

### Agent Parallelization (P2)
Investigate running independent agent nodes in parallel to reduce end-to-end latency. Current graph runs agents sequentially via the supervisor loop (`data_scientist → medical_expert → social_researcher`). Potential parallel groups:
- **Data Scientist** has no agent dependencies — always runs first.
- **Medical Expert** and **Social Researcher** both depend on Data Scientist output but are independent of each other — could run in parallel after Data Scientist completes.
- Requires changing the supervisor routing logic or using LangGraph's `Send()` / fan-out pattern.
- Must preserve the constraint: Medical Expert output feeds into Social Researcher's prompt (for `agrees_with_medical` assessment). Evaluate whether this dependency is strict or can be relaxed.

### UX Optimizations (P3)

1. **Xiaohongshu Search Query Optimization**
   - Current search queries are too literal, results not always relevant
   - Investigate: keyword extraction, Chinese synonym expansion, age-specific terms
   - Consider: pre-filtering by engagement threshold before fetching details

2. **Increase XHS Post Coverage**
   - Currently fetches top 3 posts by engagement
   - Increase to 5-8 posts for better consensus representation
   - Balance: more posts = slower response, diminishing returns

3. **Source Attribution in Key Points**
   - Parents can't tell which conclusions come from which source
   - Tag each key point with source: `[Medical]`, `[Data]`, `[Social]`
   - Example: "[Medical] Post-vaccine appetite decrease is normal for 48-72 hours"
   - Implementation: modify `synthesize_node` to preserve source tags through to `ParentingAdvice.key_points`

## 8. Instructions for Claude Code
- **Always** create a Spec in `.q/specs/` before implementing new Agent logic.
- **Never** simplify the Multi-Agent logic for the sake of speed.
- **Focus** on the "Reconciliation" logic: how to resolve conflicts when the Medical Agent and Social Agent disagree.