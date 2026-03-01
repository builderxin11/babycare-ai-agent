# CLAUDE.md - NurtureMind Engineering Standards

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


## 7. Instructions for Claude Code
- **Always** create a Spec in `.q/specs/` before implementing new Agent logic.
- **Never** simplify the Multi-Agent logic for the sake of speed.
- **Focus** on the "Reconciliation" logic: how to resolve conflicts when the Medical Agent and Social Agent disagree.