"""Tests for the SourceStatus transparency feature.

Validates that every agent node produces appropriate SourceStatus entries
so the end user knows which data sources were used, degraded, or skipped.
"""

from unittest.mock import patch

import pytest

from agent.models.outputs import (
    Citation,
    CritiqueResult,
    MedicalInsight,
    RiskLevel,
    SocialInsight,
    SourceStatus,
    SourceStatusCode,
    TrendAnalysis,
    TrendAnomaly,
)


# ---------------------------------------------------------------------------
# TestSourceStatusModel
# ---------------------------------------------------------------------------


class TestSourceStatusModel:
    """Basic model construction and serialization."""

    def test_construction(self):
        s = SourceStatus(
            source="Test Source",
            status=SourceStatusCode.OK,
            message="All good.",
        )
        assert s.source == "Test Source"
        assert s.status == SourceStatusCode.OK
        assert s.message == "All good."

    def test_serialization_roundtrip(self):
        s = SourceStatus(
            source="KB",
            status=SourceStatusCode.FALLBACK,
            message="KB failed.",
        )
        data = s.model_dump()
        assert data["status"] == "fallback"
        restored = SourceStatus.model_validate(data)
        assert restored == s


# ---------------------------------------------------------------------------
# TestDataScientistStatus
# ---------------------------------------------------------------------------


class TestDataScientistStatus:
    def test_returns_ok_status(self):
        from agent.agents.data_scientist import data_scientist_node

        state = {
            "question": "Test",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": [],
        }
        result = data_scientist_node(state)
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.OK
        assert statuses[0].source == "Baby Data Analysis"
        assert "days" in statuses[0].message


# ---------------------------------------------------------------------------
# TestMedicalExpertStatus
# ---------------------------------------------------------------------------


class TestMedicalExpertStatus:
    def _make_state(self) -> dict:
        return {
            "question": "Baby eating less after vaccine?",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": ["data_scientist"],
            "trend_analysis": TrendAnalysis(
                summary="Test trend",
                anomalies=[],
                correlations=["VACCINE correlation"],
                citations=[Citation(source_type="data_analysis", reference="test")],
            ),
        }

    def test_stub_returns_ok(self, monkeypatch):
        """Mock mode (stub) should return OK status."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(mod, "config", AgentConfig(use_mock_data=True))

        result = mod.medical_expert_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.OK
        assert statuses[0].source == "Medical Knowledge Base"

    def test_kb_failure_returns_fallback(self, monkeypatch):
        """When KB retrieval fails, should return FALLBACK status."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(
            mod, "config", AgentConfig(use_mock_data=False, bedrock_kb_id="kb-123")
        )

        # Make _run_rag raise _KBRetrievalFailed
        def fake_run_rag(state):
            raise mod._KBRetrievalFailed()

        monkeypatch.setattr(mod, "_run_rag", fake_run_rag)

        # _run_llm_only needs to return something
        fake_insight = MedicalInsight(
            summary="LLM-only fallback",
            risk_level=RiskLevel.LOW,
            recommendations=[],
            citations=[],
        )
        monkeypatch.setattr(mod, "_run_llm_only", lambda state: fake_insight)

        result = mod.medical_expert_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.FALLBACK
        assert "failed" in statuses[0].message.lower()

    def test_no_kb_configured_returns_fallback(self, monkeypatch):
        """When no KB is configured, should return FALLBACK status."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(
            mod, "config", AgentConfig(use_mock_data=False, bedrock_kb_id="")
        )

        fake_insight = MedicalInsight(
            summary="LLM-only no KB",
            risk_level=RiskLevel.LOW,
            recommendations=[],
            citations=[],
        )
        monkeypatch.setattr(mod, "_run_llm_only", lambda state: fake_insight)

        result = mod.medical_expert_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.FALLBACK
        assert "configured" in statuses[0].message.lower()


# ---------------------------------------------------------------------------
# TestSocialResearcherStatus
# ---------------------------------------------------------------------------


class TestSocialResearcherStatus:
    def _make_state(self) -> dict:
        return {
            "question": "Baby eating less?",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": ["data_scientist", "medical_expert"],
        }

    def test_no_mcp_url_returns_skipped(self, monkeypatch):
        """When no MCP URL configured, should return SKIPPED."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(
            mod, "config", AgentConfig(use_mock_data=False, xhs_mcp_url="")
        )

        result = mod.social_researcher_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.SKIPPED
        assert "configured" in statuses[0].message.lower()

    def test_mcp_failure_returns_skipped(self, monkeypatch):
        """When MCP call fails, should return SKIPPED."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(
            mod, "config", AgentConfig(use_mock_data=False, xhs_mcp_url="http://fake")
        )

        # Make _fetch_xhs_notes raise
        monkeypatch.setattr(
            mod, "_fetch_xhs_notes", lambda q, **kw: (_ for _ in ()).throw(RuntimeError("MCP down"))
        )

        result = mod.social_researcher_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.SKIPPED
        assert "unreachable" in statuses[0].message.lower()

    def test_stub_returns_ok(self, monkeypatch):
        """Mock mode (stub) should return OK status."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        monkeypatch.setattr(mod, "config", AgentConfig(use_mock_data=True))

        result = mod.social_researcher_node(self._make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.OK


# ---------------------------------------------------------------------------
# TestCritiqueStatus
# ---------------------------------------------------------------------------


class TestCritiqueStatus:
    def _make_state(self) -> dict:
        return {
            "question": "Baby eating less after vaccine?",
            "baby_age_months": 4,
            "trend_analysis": TrendAnalysis(
                summary="Test",
                anomalies=[],
                correlations=["VACCINE"],
                citations=[Citation(source_type="data_analysis", reference="test")],
            ),
            "medical_insight": MedicalInsight(
                summary="Normal",
                risk_level=RiskLevel.LOW,
                recommendations=["Monitor"],
                citations=[Citation(source_type="book", reference="AAP")],
            ),
            "social_insight": SocialInsight(
                summary="Parents agree",
                consensus_points=["Common"],
                sample_size=100,
                citations=[Citation(source_type="xhs_post", reference="XHS")],
            ),
            "critique_count": 0,
            "messages": [],
            "agents_completed": ["data_scientist", "medical_expert", "social_researcher"],
        }

    def test_rule_based_returns_ok(self):
        from agent.agents.moderator import _run_rule_based

        result = _run_rule_based(self._make_state(), iteration=1)
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.OK
        assert statuses[0].source == "Quality Review"

    def test_llm_failure_returns_fallback(self):
        from agent.agents.moderator import _run_llm

        with patch("agent.agents.moderator._call_critique_llm", side_effect=RuntimeError("down")):
            result = _run_llm(self._make_state(), iteration=1)

        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.FALLBACK
        assert "unavailable" in statuses[0].message.lower()

    def test_max_iterations_returns_degraded(self):
        from agent.agents.moderator import _run_rule_based

        state = self._make_state()
        state["trend_analysis"] = None  # create an issue
        result = _run_rule_based(state, iteration=2)  # max_critique_iterations=2
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.DEGRADED
        assert "force-approved" in statuses[0].message.lower()


# ---------------------------------------------------------------------------
# TestEndToEndTransparency
# ---------------------------------------------------------------------------


class TestEndToEndTransparency:
    """Full graph run (mock mode) should populate sources_used on final advice."""

    def test_full_graph_populates_sources_used(self):
        from agent.graph.builder import compile_graph

        app = compile_graph()
        initial_state = {
            "question": "Baby eating less after vaccine?",
            "baby_id": "baby-001",
            "baby_name": "Mia",
            "baby_age_months": 4,
            "messages": [],
            "agents_completed": [],
            "critique_count": 0,
            "requires_human_review": False,
            "human_review_reason": "",
        }
        config = {"configurable": {"thread_id": "test-transparency"}}

        result = app.invoke(initial_state, config)
        advice = result.get("final_advice")
        assert advice is not None, "Expected final_advice in result"
        assert len(advice.sources_used) == 4, (
            f"Expected 4 source statuses (data_scientist, medical, social, critique), "
            f"got {len(advice.sources_used)}: {[s.source for s in advice.sources_used]}"
        )

        sources_by_name = {s.source: s for s in advice.sources_used}
        assert "Baby Data Analysis" in sources_by_name
        assert "Medical Knowledge Base" in sources_by_name
        assert "Social Cross-Check (Xiaohongshu)" in sources_by_name
        assert "Quality Review" in sources_by_name

        # In mock mode, all should be OK
        for s in advice.sources_used:
            assert s.status == SourceStatusCode.OK, (
                f"{s.source} expected OK, got {s.status}: {s.message}"
            )
