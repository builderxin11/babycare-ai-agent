"""Entry point for the NurtureMind multi-agent system.

Run: python src/agent/main.py
"""

from __future__ import annotations

import uuid

from langgraph.types import interrupt

from agent.models.outputs import SourceStatusCode


DEMO_QUESTION = (
    "My 4-month-old daughter Mia got her DTaP vaccine 2 days ago and has been "
    "sleeping more and eating less since then. Is this normal? Should I be worried?"
)


def run_demo() -> None:
    """Run a full demo of the multi-agent parenting advisor."""
    # Import here to allow clean error messages if deps are missing
    from agent.graph.builder import compile_graph

    print("NurtureMind AI Agent -- Demo Run")
    print(f"Question: {DEMO_QUESTION}")
    print()

    app = compile_graph()
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state = {
        "question": DEMO_QUESTION,
        "baby_id": "baby-001",
        "baby_name": "Mia",
        "baby_age_months": 4,
        "messages": [],
        "agents_completed": [],
        "critique_count": 0,
        "requires_human_review": False,
        "human_review_reason": "",
    }

    # Stream execution
    try:
        for event in app.stream(initial_state, config, stream_mode="updates"):
            for node_name, updates in event.items():
                messages = updates.get("messages", [])
                for msg in messages:
                    content = msg.content if hasattr(msg, "content") else str(msg)
                    print(f"  {content}")
    except Exception as e:
        # Check if this is a GraphInterrupt (HITL)
        if "interrupt" in type(e).__name__.lower() or "GraphInterrupt" in str(type(e)):
            print("\n  [HITL] Graph interrupted for human review.")
            print("  Resuming with approval...")
            print()

            # Resume with human feedback
            for event in app.stream(
                {"human_feedback": "Approved. Advice looks appropriate."},
                config,
                stream_mode="updates",
            ):
                for node_name, updates in event.items():
                    messages = updates.get("messages", [])
                    for msg in messages:
                        content = msg.content if hasattr(msg, "content") else str(msg)
                        print(f"  {content}")
        else:
            raise

    # Get final state
    final_state = app.get_state(config)
    advice = final_state.values.get("final_advice")

    print()
    if advice:
        print("=" * 60)
        print("FINAL PARENTING ADVICE")
        print("=" * 60)
        if advice.sources_used:
            _STATUS_LABELS = {
                SourceStatusCode.OK: "OK",
                SourceStatusCode.DEGRADED: "DG",
                SourceStatusCode.FALLBACK: "FB",
                SourceStatusCode.SKIPPED: "--",
            }
            print("  Data Sources:")
            for src in advice.sources_used:
                label = _STATUS_LABELS.get(src.status, "??")
                print(f"    [{label}] {src.source}: {src.message}")
            print()
        print(f"  Confidence: {advice.confidence_score}")
        print(f"  Risk Level: {advice.risk_level}")
        print()
        print("  Summary:")
        print(f"    {advice.summary}")
        print()
        print("  Key Points:")
        for i, point in enumerate(advice.key_points, 1):
            print(f"    {i}. {point}")
        print()
        print("  Action Items:")
        for i, item in enumerate(advice.action_items, 1):
            print(f"    {i}. {item}")
        print()
        citations_str = ", ".join(
            f"[{c.source_type}: {c.reference}]" for c in advice.citations
        )
        print(f"  Citations: {citations_str}")
        print()
        print(f"  Disclaimer: {advice.disclaimer}")
    else:
        print("ERROR: No final advice produced.")


if __name__ == "__main__":
    run_demo()
