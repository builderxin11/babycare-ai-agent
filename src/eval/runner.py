"""Eval runner — executes the LangGraph graph on gold dataset test cases.

Handles HITL auto-approval so the graph completes without human input.
"""

from __future__ import annotations

import json
import time
import uuid
from pathlib import Path

from agent.graph.builder import compile_graph
from agent.models.outputs import ParentingAdvice
from agent.models.state import AgentState

from .models import TestCase

GOLD_DATASET_PATH = Path(__file__).resolve().parent.parent.parent / "eval" / "gold_dataset.json"


def load_test_cases(path: Path | None = None) -> list[TestCase]:
    """Parse eval/gold_dataset.json into a list of TestCase objects."""
    dataset_path = path or GOLD_DATASET_PATH
    with open(dataset_path) as f:
        raw = json.load(f)
    return [TestCase(**entry) for entry in raw]


def run_single_case(
    tc: TestCase,
) -> tuple[ParentingAdvice | None, dict, float]:
    """Run the graph on a single test case.

    Returns:
        (advice, final_state_values, elapsed_seconds)
    """
    app = compile_graph()
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state: dict = {
        "question": tc.question,
        "baby_id": tc.baby_id,
        "baby_name": tc.baby_name,
        "baby_age_months": tc.baby_age_months,
        "messages": [],
        "agents_completed": [],
        "critique_count": 0,
        "requires_human_review": False,
        "human_review_reason": "",
    }

    start = time.monotonic()

    try:
        for event in app.stream(initial_state, config, stream_mode="updates"):
            pass  # consume all events
    except Exception as e:
        # Handle HITL interrupt — auto-approve and resume
        if "interrupt" in type(e).__name__.lower() or "GraphInterrupt" in str(type(e)):
            try:
                for event in app.stream(
                    {"human_feedback": "[EVAL] Auto-approved"},
                    config,
                    stream_mode="updates",
                ):
                    pass
            except Exception:
                pass  # second interrupt is unexpected but don't crash eval
        else:
            raise

    elapsed = time.monotonic() - start

    final_state = app.get_state(config)
    advice = final_state.values.get("final_advice")
    return advice, dict(final_state.values), elapsed


def run_all_cases(
    path: Path | None = None,
) -> list[tuple[TestCase, ParentingAdvice | None, dict, float]]:
    """Run the graph on every test case in the gold dataset.

    Returns list of (test_case, advice, final_state_values, elapsed_seconds).
    """
    test_cases = load_test_cases(path)
    results = []
    for tc in test_cases:
        advice, state_values, elapsed = run_single_case(tc)
        results.append((tc, advice, state_values, elapsed))
    return results
