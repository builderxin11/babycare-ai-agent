# NurtureMind — Multi-Agent Parenting Advisor

A production-grade **Multi-Agent System (MAS)** that provides evidence-based parenting guidance by orchestrating four specialized AI agents through a LangGraph state machine. The system performs **Reasoning & Reflection** — not just RAG retrieval — resolving conflicting signals from medical literature, physiological trend data, and social community consensus before delivering advice to parents.

## Why This Exists

Single-prompt LLM apps can answer parenting questions. But parents don't need another chatbot — they need a system that:

- **Cross-references** the baby's own health data against medical guidelines
- **Detects conflicts** between what the textbook says and what 10,000 parents on social media report
- **Knows when to stop** and escalate to a human reviewer instead of hallucinating
- **Cites every claim** so a pediatrician can audit the advice in 30 seconds

NurtureMind does this with a swarm of four agents, a reflection loop, and a human-in-the-loop interrupt gate — all running on AWS Bedrock with DynamoDB-backed checkpointing for async resume.

## Architecture

```
                          ┌──────────────────────────────────────────────────┐
                          │              LangGraph StateGraph                │
                          │                                                  │
  Parent Question ──────► │  ┌───────────┐    ┌─────────────────────┐       │
                          │  │ Supervisor │───►│  Data Scientist     │       │
                          │  │ (Router)   │    │  PhysiologyLog stats│       │
                          │  │            │    └──────────┬──────────┘       │
                          │  │            │               │                  │
                          │  │            │    ┌──────────▼──────────┐       │
                          │  │            │───►│  Medical Expert     │       │
                          │  │            │    │  Bedrock KB RAG     │       │
                          │  │            │    └──────────┬──────────┘       │
                          │  │            │               │                  │
                          │  │            │    ┌──────────▼──────────┐       │
                          │  │            │───►│  Social Researcher  │       │
                          │  │            │    │  Xiaohongshu MCP    │       │
                          │  └─────┬──────┘    └──────────┬──────────┘       │
                          │        │                      │                  │
                          │        │         ┌────────────▼───────────┐      │
                          │        │◄────────│  Critique Node         │      │
                          │        │ reject  │  (Reflection Loop)     │      │
                          │        │         └────────────┬───────────┘      │
                          │                    approve    │                  │
                          │                  ┌────────────▼───────────┐      │
                          │                  │  HITL Gate             │      │
                          │                  │  interrupt() if risky  │      │
                          │                  └────────────┬───────────┘      │
                          │                               │                  │
                          │                  ┌────────────▼───────────┐      │
                          │                  │  Synthesize            │      │
                          │                  │  Final ParentingAdvice │      │
                          └──────────────────┴────────────┬───────────┴──────┘
                                                          │
                                                          ▼
                                              Cited, reviewed advice
                                              with source transparency
```

### Agent Responsibilities

| Agent | Model | Role |
|-------|-------|------|
| **Data Scientist** | Pure Python | Statistical anomaly detection on feeding/sleep/diaper time-series. Expanding-window baseline, >25% deviation threshold, context event correlation. |
| **Medical Expert** | Claude Sonnet (Bedrock) | Three-tier execution: stub → LLM-only → full KB RAG. Retrieves from AAP/CDC/WHO knowledge base with HYBRID search, interprets trend data in medical context. |
| **Social Researcher** | Claude Sonnet (Bedrock) | Three-tier execution: stub → skip → Xiaohongshu MCP. JSON-RPC calls to XHS MCP server, engagement-weighted ranking, Chinese-language parenting community consensus. |
| **Moderator** | Claude Opus (Bedrock) | Orchestrates agent dispatch, runs reflection loop (rule-based + LLM critique), three-source confidence scoring, contradiction detection, HITL interrupt, and normal/degraded synthesis. |

### Key Design Decisions

**Three-Tier Graceful Degradation** — Each agent has three execution modes (stub/LLM-only/full) controlled by config flags. If KB retrieval fails mid-request, the Medical Expert falls back to LLM-only rather than crashing. If the MCP server is unreachable, the Social Researcher reports "not cross-checked" rather than fabricating consensus. The system always produces output.

**Reflection Loop** — Every piece of advice passes through a Critique node before delivery. The critique runs up to 2 iterations, checking safety, citation grounding, and cross-agent conflict resolution. If the LLM critique fails, a rule-based fallback ensures the loop still functions.

**Three-Source Confidence Model** — Confidence isn't a single number from one LLM call. It's computed from three independent signals: KB retrieval success, LLM reasoning quality, and social consensus agreement. Contradictions between medical and social sources lower confidence and trigger explicit conflict disclosure.

**Human-in-the-Loop** — When confidence falls below 0.8 or the medical risk is HIGH, the graph pauses via `interrupt()`. The state is checkpointed; a human reviewer can inspect, modify, and resume asynchronously. The eval framework auto-approves interrupts via `Command(resume=...)` for CI.

**Degraded Synthesis** — When confidence is critically low (<0.4) or the medical agent produced no insight, the system switches to degraded mode: raw source snippets are presented directly with a disclaimer, instead of a poorly synthesized answer that might mislead.

## Eval Framework

The evaluation system is the source of truth for all agent changes. It runs the full LangGraph pipeline end-to-end (not mocked) and scores output on three dimensions.

### Scoring Dimensions

| Dimension | What It Measures |
|-----------|-----------------|
| **Safety (1-5)** | Disclaimer presence, harmful keyword absence, emergency guidance for high-risk scenarios |
| **Medical Accuracy (1-5)** | Risk level correctness, topic coverage, authoritative citations, confidence calibration |
| **Source Grounding (1-5)** | Citation count and specificity, source type diversity, agent coverage |

### Dual Judge System

| Judge | Activation | Strengths |
|-------|-----------|-----------|
| **Rule-Based** | `EVAL_JUDGE_MODE=rule_based` (default) | Deterministic, fast, good for CI regression gates |
| **LLM-Based** | `EVAL_JUDGE_MODE=llm_based` | Claude Opus as judge via `with_structured_output`. Semantic matching, nuanced findings, catches paraphrasing that rules miss |

### Regression Detection

The eval framework maintains a `baseline.json` and detects regressions on two axes:
- **Absolute floor**: any dimension average < 3.0 fails the build
- **Relative drop**: any dimension dropping > 0.5 vs. saved baseline fails the build

### Baseline Scores

```
Safety=5.0  Accuracy=3.6  Grounding=5.0  Overall=4.53  Passed=4/5
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Agent Orchestration | LangGraph StateGraph (7 nodes, conditional routing, interrupt) |
| LLM | Amazon Bedrock — Claude Sonnet 4 (sub-agents), Claude Opus 4.6 (moderator/judge) |
| Knowledge Base | Amazon Bedrock Knowledge Bases (HYBRID search, S3 + OpenSearch) |
| Social Data | Xiaohongshu MCP server (JSON-RPC) |
| Schema Validation | Pydantic V2 (strict typing for all agent state and outputs) |
| Backend | AWS Amplify Gen 2 (DynamoDB, AppSync, Cognito) |
| Persistence | DynamoDB-backed LangGraph Checkpointer (async HITL resume) |
| Testing | pytest — 122 tests (103 unit + 19 eval) |

## Data Model

```
Family (multi-tenant root)
  └── Baby
        ├── PhysiologyLog    [GSI: babyId + startTime]
        │     feeding (ml), sleep (min), diaper (count)
        ├── ContextEvent     [GSI: babyId + startDate]
        │     vaccine, travel, illness, milestone
        └── AgentSession
              LangGraph checkpoint reference
```

## Project Structure

```
src/
├── agent/
│   ├── agents/
│   │   ├── data_scientist.py     # Statistical anomaly detection
│   │   ├── medical_expert.py     # Bedrock KB RAG (3-tier)
│   │   ├── social_researcher.py  # Xiaohongshu MCP (3-tier)
│   │   └── moderator.py          # Orchestration + critique + HITL + synthesis
│   ├── graph/
│   │   └── builder.py            # LangGraph StateGraph construction
│   ├── models/
│   │   ├── domain.py             # Baby, PhysiologyLog, ContextEvent
│   │   ├── outputs.py            # ParentingAdvice, Citation, RiskLevel, CritiqueResult
│   │   └── state.py              # AgentState (TypedDict)
│   ├── prompts/
│   │   └── templates.py          # All system/human prompts
│   ├── tools/
│   │   └── mock_data.py          # Dev fixtures (7-day DTaP scenario)
│   └── config.py                 # Environment-based config singleton
├── eval/
│   ├── judge.py                  # Rule-based + LLM-based scoring
│   ├── runner.py                 # End-to-end graph execution + HITL auto-approval
│   ├── models.py                 # EvalScore, EvalResult, EvalReport, LLMJudgeOutput
│   └── test_eval.py              # Gold dataset integrity + scoring + LLM judge tests
tests/
├── test_critique.py              # 29 tests — reflection loop, confidence model, degraded mode
├── test_data_scientist.py        # Anomaly detection + correlation
├── test_medical_expert.py        # 3-tier execution, KB fallback, citation extraction
├── test_social_researcher.py     # MCP calls, skip mode, query building
├── test_graph_structure.py       # Graph topology + end-to-end
├── test_source_transparency.py   # SourceStatus propagation across all fallback paths
└── test_models.py                # Pydantic model validation
eval/
├── gold_dataset.json             # 5 scored test scenarios
└── baseline.json                 # Regression detection baseline
amplify/
├── auth/resource.ts              # Cognito config
└── data/resource.ts              # DynamoDB schema (5 tables + GSIs)
```

## Quick Start

### Prerequisites

- Python 3.12+
- Node.js 18+ (for Amplify)
- AWS credentials with Bedrock access (`us-west-2`)

### Setup

```bash
# Clone
git clone https://github.com/builderxin11/babycare-ai-agent.git
cd babycare-ai-agent

# Python environment
python -m venv venv && source venv/bin/activate
pip install -e ".[dev]"

# Environment variables
cp .env.example .env
# Edit .env — at minimum set BEDROCK_KB_ID if you have a Knowledge Base
```

### Run Tests

```bash
# Unit tests (103 tests, no AWS calls)
pytest tests/ -v

# Eval framework (19 tests, includes mock-mode end-to-end)
pytest src/eval/ -v

# Full live eval against Bedrock (requires AWS credentials)
USE_MOCK_DATA=false BEDROCK_KB_ID=<your-kb-id> python src/eval/judge.py

# LLM-based judge (Claude Opus scores the output)
EVAL_JUDGE_MODE=llm_based USE_MOCK_DATA=false BEDROCK_KB_ID=<your-kb-id> python src/eval/judge.py
```

### Run the Agent

```bash
# Mock mode (no AWS calls)
python src/agent/main.py

# Live mode with Bedrock RAG
USE_MOCK_DATA=false BEDROCK_KB_ID=<your-kb-id> python src/agent/main.py
```

### Amplify Backend

```bash
# Start local sandbox
npx ampx sandbox

# Deploy
npx ampx pipeline-deploy
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-west-2` | AWS region for Bedrock and DynamoDB |
| `SONNET_MODEL_ID` | `us.anthropic.claude-sonnet-4-20250514-v1:0` | Sub-agent LLM |
| `OPUS_MODEL_ID` | `us.anthropic.claude-opus-4-6-v1` | Moderator/Judge LLM |
| `BEDROCK_KB_ID` | *(empty)* | Bedrock Knowledge Base ID for medical RAG |
| `XHS_MCP_URL` | *(empty)* | Xiaohongshu MCP server endpoint |
| `USE_MOCK_DATA` | `true` | Use stubs instead of live AWS calls |
| `USE_DYNAMODB_CHECKPOINTER` | `false` | Enable DynamoDB-backed graph persistence |
| `EVAL_JUDGE_MODE` | `rule_based` | `rule_based` or `llm_based` judge for eval |
| `CONFIDENCE_THRESHOLD` | `0.8` | Below this → HITL interrupt |
| `MAX_CRITIQUE_ITERATIONS` | `2` | Max reflection loop iterations |

## License

MIT
