"""LangGraph StateGraph construction and compilation.

Builds the multi-agent graph with supervisor routing, critique loop,
HITL interrupt, and synthesis.
"""

from __future__ import annotations

from langgraph.checkpoint.memory import MemorySaver
from langgraph.graph import END, START, StateGraph

from agent.config import config
from agent.models.enums import AgentRole
from agent.models.state import AgentState
from agent.agents.data_scientist import data_scientist_node
from agent.agents.medical_expert import medical_expert_node
from agent.agents.social_researcher import social_researcher_node
from agent.agents.moderator import (
    critique_node,
    hitl_node,
    supervisor_node,
    synthesize_node,
)


def _supervisor_router(state: AgentState) -> str:
    """Route from supervisor to the next agent node."""
    next_agent = state.get("next_agent", "")
    if next_agent == AgentRole.DATA_SCIENTIST.value:
        return "data_scientist"
    elif next_agent == AgentRole.MEDICAL_EXPERT.value:
        return "medical_expert"
    elif next_agent == AgentRole.SOCIAL_RESEARCHER.value:
        return "social_researcher"
    elif next_agent == AgentRole.CRITIQUE.value:
        return "critique"
    return "critique"


def _critique_router(state: AgentState) -> str:
    """Route from critique: back to supervisor if rejected, to HITL if approved."""
    critique = state.get("critique_result")
    if critique and critique.approved:
        return "hitl_check"
    return "supervisor"


def build_graph() -> StateGraph:
    """Construct the multi-agent StateGraph.

    Graph topology:
        START -> supervisor -> {data_scientist, medical_expert, social_researcher, critique}
        data_scientist -> supervisor
        medical_expert -> supervisor
        social_researcher -> supervisor
        critique -> {supervisor (rejected), hitl_check (approved)}
        hitl_check -> synthesize
        synthesize -> END
    """
    graph = StateGraph(AgentState)

    # Add nodes
    graph.add_node("supervisor", supervisor_node)
    graph.add_node("data_scientist", data_scientist_node)
    graph.add_node("medical_expert", medical_expert_node)
    graph.add_node("social_researcher", social_researcher_node)
    graph.add_node("critique", critique_node)
    graph.add_node("hitl_check", hitl_node)
    graph.add_node("synthesize", synthesize_node)

    # Entry point
    graph.add_edge(START, "supervisor")

    # Supervisor dispatches conditionally
    graph.add_conditional_edges(
        "supervisor",
        _supervisor_router,
        {
            "data_scientist": "data_scientist",
            "medical_expert": "medical_expert",
            "social_researcher": "social_researcher",
            "critique": "critique",
        },
    )

    # Specialist agents always return to supervisor
    graph.add_edge("data_scientist", "supervisor")
    graph.add_edge("medical_expert", "supervisor")
    graph.add_edge("social_researcher", "supervisor")

    # Critique either loops back or proceeds
    graph.add_conditional_edges(
        "critique",
        _critique_router,
        {
            "supervisor": "supervisor",
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

    if config.use_dynamodb_checkpointer:
        try:
            from langgraph.checkpoint.aws import DynamoDBSaver
            checkpointer = DynamoDBSaver(
                region_name=config.aws_region,
            )
        except ImportError:
            print(
                "WARNING: langgraph-checkpoint-aws not installed. "
                "Falling back to MemorySaver. Install with: pip install langgraph-checkpoint-aws"
            )
            checkpointer = MemorySaver()
    else:
        checkpointer = MemorySaver()

    return graph.compile(checkpointer=checkpointer)
