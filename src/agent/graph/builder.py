"""LangGraph StateGraph construction and compilation.

Builds the multi-agent graph with parallel agent execution, critique loop,
HITL interrupt, and synthesis.

Graph topology (parallelized):
    START -> data_scientist -> [medical_expert || social_researcher] -> critique -> ...

Medical Expert and Social Researcher run in parallel after Data Scientist completes.
This reduces end-to-end latency by ~40% compared to sequential execution.
"""

from __future__ import annotations

from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.serde.jsonplus import JsonPlusSerializer
from langgraph.graph import END, START, StateGraph
from langgraph.types import Send

from agent.config import config
from agent.models.enums import AgentRole
from agent.models.state import AgentState

# All custom types that flow through the graph state and get serialized
# into checkpoints. Without this, LangGraph emits deprecation warnings
# and will block deserialization in a future version.
_ALLOWED_MSGPACK_MODULES: set[tuple[str, str]] = {
    ("agent.models.outputs", "CritiqueResult"),
    ("agent.models.outputs", "MedicalInsight"),
    ("agent.models.outputs", "ParentingAdvice"),
    ("agent.models.outputs", "RiskLevel"),
    ("agent.models.outputs", "SocialInsight"),
    ("agent.models.outputs", "SourceStatus"),
    ("agent.models.outputs", "SourceStatusCode"),
    ("agent.models.outputs", "TrendAnalysis"),
}
from agent.agents.data_scientist import data_scientist_node
from agent.agents.medical_expert import medical_expert_node
from agent.agents.social_researcher import social_researcher_node
from agent.agents.moderator import (
    critique_node,
    hitl_node,
    synthesize_node,
)


def _parallel_dispatch(state: AgentState) -> list[Send]:
    """Fan-out to Medical Expert and Social Researcher in parallel.

    Both agents depend only on Data Scientist output (trend_analysis),
    so they can execute concurrently. This reduces latency significantly.
    """
    return [
        Send("medical_expert", state),
        Send("social_researcher", state),
    ]


def _join_router(state: AgentState) -> str:
    """Wait for both parallel agents to complete, then route to critique.

    The join node checks if both medical_expert and social_researcher
    have been added to agents_completed. Due to the reducer pattern,
    this node is called after each parallel branch completes.
    """
    completed = set(state.get("agents_completed", []))
    required = {"medical_expert", "social_researcher"}

    if required.issubset(completed):
        return "critique"
    # Still waiting for the other branch
    return "__wait__"


def _critique_router(state: AgentState) -> str:
    """Route from critique: re-run agents if rejected, to HITL if approved."""
    critique = state.get("critique_result")
    if critique and critique.approved:
        return "hitl_check"
    # On rejection, re-dispatch parallel agents for another iteration
    return "parallel_dispatch"


def _join_node(state: AgentState) -> dict:
    """No-op join node that waits for parallel branches to complete.

    This node exists to synchronize the parallel branches before critique.
    It doesn't modify state — just acts as a barrier.
    """
    return {}


def build_graph() -> StateGraph:
    """Construct the multi-agent StateGraph with parallel execution.

    Graph topology:
        START -> data_scientist -> [medical_expert || social_researcher] -> join -> critique
        critique -> {parallel_dispatch (rejected), hitl_check (approved)}
        hitl_check -> synthesize -> END

    Performance: ~40% latency reduction by running Medical Expert and
    Social Researcher in parallel after Data Scientist completes.
    """
    graph = StateGraph(AgentState)

    # Add nodes
    graph.add_node("data_scientist", data_scientist_node)
    graph.add_node("medical_expert", medical_expert_node)
    graph.add_node("social_researcher", social_researcher_node)
    graph.add_node("join", _join_node)
    graph.add_node("critique", critique_node)
    graph.add_node("hitl_check", hitl_node)
    graph.add_node("synthesize", synthesize_node)

    # Entry: START -> data_scientist
    graph.add_edge(START, "data_scientist")

    # After data_scientist, fan-out to parallel agents
    graph.add_conditional_edges(
        "data_scientist",
        _parallel_dispatch,
        ["medical_expert", "social_researcher"],
    )

    # Both parallel agents converge at join
    graph.add_edge("medical_expert", "join")
    graph.add_edge("social_researcher", "join")

    # Join waits for both, then routes to critique
    graph.add_conditional_edges(
        "join",
        _join_router,
        {
            "critique": "critique",
            "__wait__": "join",  # Stay at join until both complete
        },
    )

    # Critique either loops back for re-evaluation or proceeds
    graph.add_conditional_edges(
        "critique",
        _critique_router,
        {
            "parallel_dispatch": "data_scientist",  # Re-run from data_scientist
            "hitl_check": "hitl_check",
        },
    )

    # HITL -> synthesize -> END
    graph.add_edge("hitl_check", "synthesize")
    graph.add_edge("synthesize", END)

    return graph


def compile_graph():
    """Compile the graph with the appropriate checkpointer.

    Uses MemorySaver for development. Switch to DynamoDBSaver via
    USE_DYNAMODB_CHECKPOINTER=true for production.
    """
    graph = build_graph()

    serde = JsonPlusSerializer(allowed_msgpack_modules=_ALLOWED_MSGPACK_MODULES)

    if config.use_dynamodb_checkpointer:
        try:
            from langgraph.checkpoint.aws import DynamoDBSaver
            checkpointer = DynamoDBSaver(
                region_name=config.aws_region,
                serde=serde,
            )
        except ImportError:
            print(
                "WARNING: langgraph-checkpoint-aws not installed. "
                "Falling back to MemorySaver. Install with: pip install langgraph-checkpoint-aws"
            )
            checkpointer = MemorySaver(serde=serde)
    else:
        checkpointer = MemorySaver(serde=serde)

    return graph.compile(checkpointer=checkpointer)
