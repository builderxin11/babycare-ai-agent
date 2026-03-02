"""FastAPI wrapper for the NurtureMind multi-agent system.

Run: uvicorn src.api.server:app --port 8000 --reload
"""

from __future__ import annotations

import uuid

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from agent.graph.builder import compile_graph
from agent.models.outputs import ParentingAdvice

app = FastAPI(title="NurtureMind Agent API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["POST"],
    allow_headers=["*"],
)


class AskRequest(BaseModel):
    question: str = Field(min_length=1)
    baby_id: str = Field(min_length=1)
    baby_name: str = Field(min_length=1)
    baby_age_months: int = Field(ge=0)


class AskResponse(BaseModel):
    """Mirrors ParentingAdvice for JSON serialization."""

    question: str
    summary: str
    key_points: list[str]
    action_items: list[str]
    risk_level: str
    confidence_score: float
    citations: list[dict]
    sources_used: list[dict]
    is_degraded: bool
    raw_sources: list[str]
    disclaimer: str


# Compile the graph once at startup so subsequent requests reuse it.
_graph = compile_graph()


@app.post("/ask", response_model=AskResponse)
async def ask_agent(req: AskRequest) -> AskResponse:
    """Invoke the multi-agent graph synchronously and return advice."""
    thread_id = str(uuid.uuid4())
    config = {"configurable": {"thread_id": thread_id}}

    initial_state = {
        "question": req.question,
        "baby_id": req.baby_id,
        "baby_name": req.baby_name,
        "baby_age_months": req.baby_age_months,
        "messages": [],
        "agents_completed": [],
        "critique_count": 0,
        "requires_human_review": False,
        "human_review_reason": "",
    }

    try:
        for _event in _graph.stream(initial_state, config, stream_mode="updates"):
            pass
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Agent failed: {e}",
        ) from e

    # Check if the graph paused at an interrupt (HITL).
    # In LangGraph 1.x, interrupt() does not raise — it stops the stream
    # and the graph state shows pending tasks.
    graph_state = _graph.get_state(config)

    if graph_state.tasks and any(
        hasattr(t, "interrupts") and t.interrupts for t in graph_state.tasks
    ):
        # Auto-approve for MVP: resume with human feedback using Command.
        from langgraph.types import Command
        try:
            for _event in _graph.stream(
                Command(resume="Approved via API (auto-approve)."),
                config,
                stream_mode="updates",
            ):
                pass
        except Exception as resume_err:
            raise HTTPException(
                status_code=500,
                detail=f"Agent failed during HITL resume: {resume_err}",
            ) from resume_err
        graph_state = _graph.get_state(config)

    advice: ParentingAdvice | None = graph_state.values.get("final_advice")

    if not advice:
        raise HTTPException(status_code=500, detail="Agent produced no advice.")

    response = AskResponse(
        question=advice.question,
        summary=advice.summary,
        key_points=advice.key_points,
        action_items=advice.action_items,
        risk_level=advice.risk_level.value,
        confidence_score=advice.confidence_score,
        citations=[c.model_dump() for c in advice.citations],
        sources_used=[s.model_dump() for s in advice.sources_used],
        is_degraded=advice.is_degraded,
        raw_sources=advice.raw_sources,
        disclaimer=advice.disclaimer,
    )

    # Free checkpoint data for this thread to prevent unbounded memory growth.
    # Each request uses a unique thread_id and never resumes, so the
    # checkpoint is no longer needed after the response is built.
    if hasattr(_graph.checkpointer, "delete_thread"):
        _graph.checkpointer.delete_thread(thread_id)

    return response


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
