"""Tests for graph structure and end-to-end execution."""

import uuid

from agent.graph.builder import build_graph, compile_graph


EXPECTED_NODES = {
    "supervisor",
    "data_scientist",
    "medical_expert",
    "social_researcher",
    "critique",
    "hitl_check",
    "synthesize",
}


class TestGraphStructure:
    def test_graph_compiles(self):
        """Graph should compile without errors."""
        app = compile_graph()
        assert app is not None

    def test_has_all_nodes(self):
        """Graph should contain all 7 expected nodes."""
        graph = build_graph()
        # StateGraph stores nodes in a dict; node names are the keys
        node_names = set(graph.nodes.keys())
        assert EXPECTED_NODES.issubset(node_names), (
            f"Missing nodes: {EXPECTED_NODES - node_names}"
        )


class TestEndToEnd:
    def test_full_run_produces_advice(self):
        """Full graph run should produce final_advice in the state."""
        app = compile_graph()
        thread_id = str(uuid.uuid4())
        config = {"configurable": {"thread_id": thread_id}}

        initial_state = {
            "question": "My baby is sleeping more after vaccination. Is this normal?",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": [],
            "critique_count": 0,
            "requires_human_review": False,
            "human_review_reason": "",
        }

        # Run the full graph
        result = app.invoke(initial_state, config)

        assert result.get("final_advice") is not None, "Expected final_advice in output"
        advice = result["final_advice"]
        assert advice.confidence_score > 0, "Expected positive confidence"
        assert len(advice.citations) > 0, "Expected citations"

    def test_agents_all_completed(self):
        """All specialist agents should be marked as completed."""
        app = compile_graph()
        thread_id = str(uuid.uuid4())
        config = {"configurable": {"thread_id": thread_id}}

        initial_state = {
            "question": "Test question",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": [],
            "critique_count": 0,
            "requires_human_review": False,
            "human_review_reason": "",
        }

        result = app.invoke(initial_state, config)

        completed = set(result.get("agents_completed", []))
        assert "data_scientist" in completed
        assert "medical_expert" in completed
        assert "social_researcher" in completed
