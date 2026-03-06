"""FastAPI wrapper for the NurtureMind multi-agent system.

Run: uvicorn src.api.server:app --port 8000 --reload
"""

from __future__ import annotations

import uuid

from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from agent.graph.builder import compile_graph
from agent.models.outputs import DailyReport, ParentingAdvice
from agent.report.generator import generate_daily_report
from api import dynamodb_crud

app = FastAPI(title="NurtureMind Agent API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # Web frontend
        "*",  # Allow iOS simulator and other local clients (dev only)
    ],
    allow_methods=["GET", "POST", "DELETE"],
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


class ReportRequest(BaseModel):
    """Request body for daily report generation."""

    baby_id: str = Field(min_length=1)
    baby_name: str = Field(min_length=1)
    baby_age_months: int = Field(ge=0)


class ReportResponse(BaseModel):
    """Mirrors DailyReport for JSON serialization."""

    baby_id: str
    baby_name: str
    report_date: str
    health_status: str
    confidence_score: float
    trend_direction: str
    summary: str
    observations: list[str]
    action_items: list[str]
    warnings: list[str]
    citations: list[dict]
    data_snapshot: dict
    baseline_snapshot: dict
    generated_at: str
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


@app.post("/report", response_model=ReportResponse)
async def generate_report(req: ReportRequest) -> ReportResponse:
    """Generate a daily health report for a baby.

    This runs a lightweight agent pipeline (Data Scientist → Medical Expert → Critique)
    without Social Researcher or HITL interrupts for faster execution.
    """
    try:
        report: DailyReport = generate_daily_report(
            baby_id=req.baby_id,
            baby_name=req.baby_name,
            baby_age_months=req.baby_age_months,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Report generation failed: {e}",
        ) from e

    return ReportResponse(
        baby_id=report.baby_id,
        baby_name=report.baby_name,
        report_date=report.report_date.isoformat(),
        health_status=report.health_status.value,
        confidence_score=report.confidence_score,
        trend_direction=report.trend_direction.value,
        summary=report.summary,
        observations=report.observations,
        action_items=report.action_items,
        warnings=report.warnings,
        citations=[c.model_dump() for c in report.citations],
        data_snapshot=report.data_snapshot,
        baseline_snapshot=report.baseline_snapshot,
        generated_at=report.generated_at.isoformat(),
        disclaimer=report.disclaimer,
    )


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


# -----------------------------------------------------------------------------
# Baby CRUD Endpoints
# -----------------------------------------------------------------------------


class CreateBabyRequest(BaseModel):
    family_id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    birth_date: str = Field(min_length=10)  # YYYY-MM-DD
    gender: str | None = None
    notes: str | None = None


@app.get("/babies")
async def list_babies() -> list[dict[str, Any]]:
    """List all babies."""
    try:
        return dynamodb_crud.list_babies()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.get("/babies/{baby_id}")
async def get_baby(baby_id: str) -> dict[str, Any]:
    """Get a single baby by ID."""
    try:
        baby = dynamodb_crud.get_baby(baby_id)
        if not baby:
            raise HTTPException(status_code=404, detail="Baby not found")
        return baby
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/babies")
async def create_baby(req: CreateBabyRequest) -> dict[str, Any]:
    """Create a new baby."""
    try:
        return dynamodb_crud.create_baby(
            family_id=req.family_id,
            name=req.name,
            birth_date=req.birth_date,
            gender=req.gender,
            notes=req.notes,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.delete("/babies/{baby_id}")
async def delete_baby(baby_id: str) -> dict[str, str]:
    """Delete a baby by ID."""
    try:
        dynamodb_crud.delete_baby(baby_id)
        return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


# -----------------------------------------------------------------------------
# PhysiologyLog CRUD Endpoints
# -----------------------------------------------------------------------------


class CreateLogRequest(BaseModel):
    type: str = Field(min_length=1)
    start_time: str = Field(min_length=1)  # ISO-8601 datetime
    end_time: str | None = None
    amount: float | None = None
    unit: str | None = None
    notes: str | None = None


@app.get("/babies/{baby_id}/logs")
async def list_logs(baby_id: str, limit: int = 50) -> list[dict[str, Any]]:
    """List physiology logs for a baby."""
    try:
        return dynamodb_crud.list_physiology_logs(baby_id, limit)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/babies/{baby_id}/logs")
async def create_log(baby_id: str, req: CreateLogRequest) -> dict[str, Any]:
    """Create a new physiology log."""
    try:
        return dynamodb_crud.create_physiology_log(
            baby_id=baby_id,
            log_type=req.type,
            start_time=req.start_time,
            end_time=req.end_time,
            amount=req.amount,
            unit=req.unit,
            notes=req.notes,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.delete("/logs/{log_id}")
async def delete_log(log_id: str) -> dict[str, str]:
    """Delete a physiology log by ID."""
    try:
        dynamodb_crud.delete_physiology_log(log_id)
        return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


# -----------------------------------------------------------------------------
# ContextEvent CRUD Endpoints
# -----------------------------------------------------------------------------


class CreateEventRequest(BaseModel):
    type: str = Field(min_length=1)
    title: str = Field(min_length=1)
    start_date: str = Field(min_length=10)  # YYYY-MM-DD
    end_date: str | None = None
    notes: str | None = None
    metadata: dict | None = None


@app.get("/babies/{baby_id}/events")
async def list_events(baby_id: str, limit: int = 20) -> list[dict[str, Any]]:
    """List context events for a baby."""
    try:
        return dynamodb_crud.list_context_events(baby_id, limit)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/babies/{baby_id}/events")
async def create_event(baby_id: str, req: CreateEventRequest) -> dict[str, Any]:
    """Create a new context event."""
    try:
        return dynamodb_crud.create_context_event(
            baby_id=baby_id,
            event_type=req.type,
            title=req.title,
            start_date=req.start_date,
            end_date=req.end_date,
            notes=req.notes,
            metadata=req.metadata,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.delete("/events/{event_id}")
async def delete_event(event_id: str) -> dict[str, str]:
    """Delete a context event by ID."""
    try:
        dynamodb_crud.delete_context_event(event_id)
        return {"status": "deleted"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
