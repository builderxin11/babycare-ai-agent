"""Tests for the Medical Expert agent."""

from unittest.mock import MagicMock

import pytest
from langchain_core.documents import Document
from langchain_core.messages import AIMessage

from agent.agents.medical_expert import (
    _build_retrieval_query,
    _extract_citations_from_docs,
    _format_docs_as_context,
    medical_expert_node,
)
from agent.models.outputs import (
    Citation,
    MedicalInsight,
    RiskLevel,
    TrendAnalysis,
    TrendAnomaly,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_state(**overrides) -> dict:
    """Create a minimal AgentState dict for testing."""
    state = {
        "question": "Why is my baby eating less after vaccination?",
        "baby_id": "baby-001",
        "baby_name": "Mia",
        "baby_age_months": 4,
        "messages": [],
        "agents_completed": [],
    }
    state.update(overrides)
    return state


def _make_trend(**overrides) -> TrendAnalysis:
    """Create a TrendAnalysis for testing."""
    defaults = {
        "summary": "Feeding volume dropped 25% post-vaccine.",
        "anomalies": [
            TrendAnomaly(
                date="2025-01-15",
                metric="feeding_volume_ml",
                value=120.0,
                baseline=160.0,
                deviation_pct=-25.0,
                description="Feeding volume below baseline",
            ),
        ],
        "correlations": ["DTaP Vaccine (2025-01-14)", "Growth spurt phase", "Teething onset"],
        "citations": [
            Citation(source_type="data_analysis", reference="PhysiologyLog analysis"),
        ],
    }
    defaults.update(overrides)
    return TrendAnalysis(**defaults)


def _make_doc(content: str = "Sample content", **meta) -> Document:
    """Create a langchain Document for testing."""
    return Document(page_content=content, metadata=meta)


# ---------------------------------------------------------------------------
# TestBuildRetrievalQuery
# ---------------------------------------------------------------------------


class TestBuildRetrievalQuery:
    """Tests for _build_retrieval_query helper."""

    def test_includes_question(self):
        state = _make_state()
        query = _build_retrieval_query(state)
        assert "eating less" in query

    def test_includes_age(self):
        state = _make_state(baby_age_months=6)
        query = _build_retrieval_query(state)
        assert "6-month-old infant" in query

    def test_includes_trend_summary(self):
        trend = _make_trend(summary="Sleep disruption detected")
        state = _make_state(trend_analysis=trend)
        query = _build_retrieval_query(state)
        assert "Sleep disruption detected" in query

    def test_limits_correlations_to_three(self):
        trend = _make_trend(
            correlations=["A", "B", "C", "D", "E"],
        )
        state = _make_state(trend_analysis=trend)
        query = _build_retrieval_query(state)
        assert "A" in query
        assert "B" in query
        assert "C" in query
        assert "D" not in query
        assert "E" not in query

    def test_no_trend(self):
        """Without trend_analysis, query should still include question and age."""
        state = _make_state(trend_analysis=None)
        query = _build_retrieval_query(state)
        assert "eating less" in query
        assert "4-month-old infant" in query


# ---------------------------------------------------------------------------
# TestExtractCitations
# ---------------------------------------------------------------------------


class TestExtractCitations:
    """Tests for _extract_citations_from_docs helper."""

    def test_empty_docs(self):
        assert _extract_citations_from_docs([]) == []

    def test_s3_uri_parsed(self):
        doc = _make_doc(
            content="Vaccine info",
            source="s3://my-bucket/books/aap-immunization-guide.pdf",
        )
        citations = _extract_citations_from_docs([doc])
        assert len(citations) == 1
        assert citations[0].source_type == "book"
        assert "Aap Immunization Guide" in citations[0].reference

    def test_missing_uri_fallback(self):
        doc = _make_doc(content="Some content")
        citations = _extract_citations_from_docs([doc])
        assert len(citations) == 1
        assert citations[0].reference == "Knowledge Base Document"

    def test_detail_truncation(self):
        long_content = "x" * 500
        doc = _make_doc(content=long_content, source="s3://b/file.pdf")
        citations = _extract_citations_from_docs([doc])
        assert len(citations[0].detail) == 200

    def test_s3_location_nested(self):
        """Extract URI from nested location.s3Location.uri metadata."""
        doc = _make_doc(
            content="Content",
            location={"s3Location": {"uri": "s3://bucket/path/cdc-guide.pdf"}},
        )
        citations = _extract_citations_from_docs([doc])
        assert "Cdc Guide" in citations[0].reference


# ---------------------------------------------------------------------------
# TestFormatDocsAsContext
# ---------------------------------------------------------------------------


class TestFormatDocsAsContext:
    """Tests for _format_docs_as_context helper."""

    def test_empty_docs(self):
        result = _format_docs_as_context([])
        assert "No relevant documents" in result

    def test_multi_doc_formatting(self):
        docs = [
            _make_doc("First doc content", source="s3://b/a.pdf", score=0.9),
            _make_doc("Second doc content", source="s3://b/b.pdf", score=0.7),
        ]
        result = _format_docs_as_context(docs)
        assert "Document 1" in result
        assert "Document 2" in result
        assert "First doc content" in result
        assert "Second doc content" in result

    def test_score_included(self):
        docs = [_make_doc("Content", score=0.85)]
        result = _format_docs_as_context(docs)
        assert "0.85" in result


# ---------------------------------------------------------------------------
# TestMedicalExpertFallback
# ---------------------------------------------------------------------------


class TestMedicalExpertFallback:
    """Test fallback behaviour for KB and LLM failures."""

    def test_kb_failure_falls_back_to_llm_only(self, monkeypatch):
        """If KB retrieval fails, should fall back to _run_llm_only."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(bedrock_kb_id="fake-kb-id")
        monkeypatch.setattr(mod, "config", mock_config)

        # Track whether _run_llm_only was called
        llm_only_called = []
        fake_insight = MedicalInsight(
            summary="LLM-only fallback",
            risk_level=RiskLevel.LOW,
            recommendations=["See doctor"],
            citations=[],
        )

        def _fake_llm_only(state):
            llm_only_called.append(True)
            return fake_insight

        monkeypatch.setattr(mod, "_run_llm_only", _fake_llm_only)

        # Make the KB retriever import & invoke raise inside _run_rag
        import types
        fake_langchain_aws = types.ModuleType("langchain_aws")

        class BrokenRetriever:
            def __init__(self, **kwargs):
                raise RuntimeError("KB unreachable")

        fake_langchain_aws.AmazonKnowledgeBasesRetriever = BrokenRetriever
        monkeypatch.setitem(__import__("sys").modules, "langchain_aws", fake_langchain_aws)

        result = medical_expert_node(_make_state())

        assert llm_only_called, "_run_llm_only should have been called as fallback"
        assert result["medical_insight"].summary == "LLM-only fallback"

    def test_llm_failure_propagates(self, monkeypatch):
        """If Bedrock LLM fails, the error should propagate (no silent fallback)."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(bedrock_kb_id="")  # LLM-only path
        monkeypatch.setattr(mod, "config", mock_config)

        def _boom(state):
            raise RuntimeError("Bedrock model invocation failed")

        monkeypatch.setattr(mod, "_run_llm_only", _boom)

        with pytest.raises(RuntimeError, match="Bedrock model invocation failed"):
            medical_expert_node(_make_state())

    def test_no_kb_returns_fallback_status(self, monkeypatch):
        """Without KB configured, should return FALLBACK for KB and OK for LLM."""
        import agent.agents.medical_expert as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(bedrock_kb_id="")
        monkeypatch.setattr(mod, "config", mock_config)

        fake_insight = MedicalInsight(
            summary="LLM-only no KB",
            risk_level=RiskLevel.LOW,
            recommendations=[],
            citations=[],
            kb_available=False,
        )
        monkeypatch.setattr(mod, "_run_llm_only", lambda state: fake_insight)

        result = medical_expert_node(_make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 2
        assert statuses[0].status.value == "fallback"
        assert "configured" in statuses[0].message.lower()
        assert statuses[1].source == "Medical Expert LLM"
