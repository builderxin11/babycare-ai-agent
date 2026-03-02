"""Tests for the Social Researcher agent."""

from unittest.mock import MagicMock, patch

import pytest
from langchain_core.messages import AIMessage

from agent.agents.social_researcher import (
    MCPError,
    _SKIP_SUMMARY,
    _build_search_query,
    _compute_sample_size,
    _extract_citations_from_notes,
    _format_notes_as_context,
    _mcp_call,
    _run_skip,
    social_researcher_node,
)
from agent.models.outputs import (
    Citation,
    SocialInsight,
    SourceStatusCode,
    TrendAnalysis,
    TrendAnomaly,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _make_state(**overrides) -> dict:
    """Create a minimal AgentState dict for testing."""
    state = {
        "question": "宝宝打完疫苗后不爱吃奶正常吗？",
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


def _make_notes() -> list[dict]:
    """Create sample XHS note data for testing."""
    return [
        {
            "id": "note-001",
            "title": "宝宝打疫苗后不吃奶怎么办",
            "author": "妈妈小红",
            "content": "我家宝宝打完疫苗后也不爱吃奶，持续了两天就好了。",
            "likes": 100,
            "comments": 30,
            "collects": 20,
        },
        {
            "id": "note-002",
            "title": "DTaP疫苗后宝宝反应分享",
            "author": "育儿达人",
            "content": "正常反应，一般1-3天恢复。注意多喝水。",
            "likes": 200,
            "comments": 50,
            "collects": 40,
        },
    ]


# ---------------------------------------------------------------------------
# TestSocialResearcherSkip
# ---------------------------------------------------------------------------


class TestSocialResearcherSkip:
    """Tests for the skip (no MCP configured) execution path."""

    def test_produces_social_insight(self):
        """Node should produce a SocialInsight in its return dict."""
        result = social_researcher_node(_make_state())
        assert "social_insight" in result
        assert isinstance(result["social_insight"], SocialInsight)

    def test_no_mcp_returns_skip_message(self):
        """Without MCP URL, node should return skip message."""
        result = social_researcher_node(_make_state())
        insight = result["social_insight"]
        assert insight.summary == _SKIP_SUMMARY
        assert insight.sample_size == 0

    def test_no_mcp_returns_skipped_status(self):
        """Without MCP URL, should return SKIPPED status."""
        result = social_researcher_node(_make_state())
        statuses = result["source_statuses"]
        assert len(statuses) == 1
        assert statuses[0].status == SourceStatusCode.SKIPPED

    def test_marks_agent_completed(self):
        """Node should add 'social_researcher' to agents_completed."""
        result = social_researcher_node(_make_state())
        assert "social_researcher" in result["agents_completed"]

    def test_returns_ai_message(self):
        """Node should include an AIMessage in messages."""
        result = social_researcher_node(_make_state())
        assert len(result["messages"]) == 1
        msg = result["messages"][0]
        assert isinstance(msg, AIMessage)
        assert msg.name == "social_researcher"
        assert "[social_researcher]" in msg.content


# ---------------------------------------------------------------------------
# TestBuildSearchQuery
# ---------------------------------------------------------------------------


class TestBuildSearchQuery:
    """Tests for _build_search_query helper."""

    def test_includes_question(self):
        state = _make_state()
        query = _build_search_query(state)
        assert "宝宝打完疫苗" in query

    def test_includes_chinese_age_format(self):
        state = _make_state(baby_age_months=4)
        query = _build_search_query(state)
        assert "4个月宝宝" in query

    def test_limits_correlations_to_two(self):
        trend = _make_trend(correlations=["A", "B", "C", "D"])
        state = _make_state(trend_analysis=trend)
        query = _build_search_query(state)
        assert "A" in query
        assert "B" in query
        assert "C" not in query
        assert "D" not in query

    def test_no_trend_fallback(self):
        """Without trend_analysis, query should still include question and age."""
        state = _make_state(trend_analysis=None)
        query = _build_search_query(state)
        assert "宝宝打完疫苗" in query
        assert "4个月宝宝" in query


# ---------------------------------------------------------------------------
# TestFormatNotesAsContext
# ---------------------------------------------------------------------------


class TestFormatNotesAsContext:
    """Tests for _format_notes_as_context helper."""

    def test_empty_notes_message(self):
        result = _format_notes_as_context([])
        assert "No Xiaohongshu posts" in result

    def test_multi_note_formatting(self):
        notes = _make_notes()
        result = _format_notes_as_context(notes)
        assert "Post 1" in result
        assert "Post 2" in result
        assert "宝宝打疫苗后不吃奶怎么办" in result
        assert "DTaP疫苗后宝宝反应分享" in result

    def test_engagement_included(self):
        notes = _make_notes()
        result = _format_notes_as_context(notes)
        assert "100 likes" in result
        assert "30 comments" in result
        assert "20 collects" in result


# ---------------------------------------------------------------------------
# TestExtractCitationsFromNotes
# ---------------------------------------------------------------------------


class TestExtractCitationsFromNotes:
    """Tests for _extract_citations_from_notes helper."""

    def test_correct_source_type_and_reference(self):
        notes = _make_notes()
        citations = _extract_citations_from_notes(notes)
        assert len(citations) == 2
        assert all(c.source_type == "xhs_post" for c in citations)
        assert "宝宝打疫苗后不吃奶怎么办" in citations[0].reference
        assert "妈妈小红" in citations[0].reference

    def test_empty_list(self):
        citations = _extract_citations_from_notes([])
        assert citations == []


# ---------------------------------------------------------------------------
# TestComputeSampleSize
# ---------------------------------------------------------------------------


class TestComputeSampleSize:
    """Tests for _compute_sample_size helper."""

    def test_sum_of_engagement(self):
        notes = _make_notes()
        # note-001: 100+30+20=150, note-002: 200+50+40=290 => 440
        assert _compute_sample_size(notes) == 440

    def test_empty_is_zero(self):
        assert _compute_sample_size([]) == 0


# ---------------------------------------------------------------------------
# TestMCPCall
# ---------------------------------------------------------------------------


class TestMCPCall:
    """Tests for _mcp_call helper."""

    @patch("agent.agents.social_researcher.config")
    def test_successful_call(self, mock_config):
        """Successful JSON-RPC call returns result."""
        mock_config.xhs_mcp_url = "http://localhost:18060/mcp"

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "jsonrpc": "2.0",
            "id": 1,
            "result": [{"id": "note-1", "title": "Test"}],
        }
        mock_response.raise_for_status = MagicMock()

        with patch("requests.post", return_value=mock_response) as mock_post:
            result = _mcp_call("search_notes", {"keyword": "test"})

        assert result == [{"id": "note-1", "title": "Test"}]
        mock_post.assert_called_once_with(
            "http://localhost:18060/mcp",
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "search_notes",
                "params": {"keyword": "test"},
            },
            timeout=15,
        )

    @patch("agent.agents.social_researcher.config")
    def test_http_error_raises(self, mock_config):
        """HTTP errors from requests should propagate."""
        mock_config.xhs_mcp_url = "http://localhost:18060/mcp"

        import requests

        mock_response = MagicMock()
        mock_response.raise_for_status.side_effect = requests.HTTPError("500 Server Error")

        with patch("requests.post", return_value=mock_response):
            with pytest.raises(requests.HTTPError):
                _mcp_call("search_notes", {"keyword": "test"})

    @patch("agent.agents.social_researcher.config")
    def test_jsonrpc_error_raises_mcp_error(self, mock_config):
        """JSON-RPC error in response body should raise MCPError."""
        mock_config.xhs_mcp_url = "http://localhost:18060/mcp"

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {"code": -32600, "message": "Invalid request"},
        }
        mock_response.raise_for_status = MagicMock()

        with patch("requests.post", return_value=mock_response):
            with pytest.raises(MCPError, match="MCP error"):
                _mcp_call("search_notes", {"keyword": "test"})


# ---------------------------------------------------------------------------
# TestRunSkip
# ---------------------------------------------------------------------------


class TestRunSkip:
    """Tests for _run_skip — the 'not configured' path."""

    def test_returns_skip_summary(self):
        insight = _run_skip()
        assert insight.summary == _SKIP_SUMMARY
        assert "No social media" in insight.summary

    def test_empty_consensus_and_citations(self):
        insight = _run_skip()
        assert insight.consensus_points == []
        assert insight.citations == []
        assert insight.sample_size == 0


# ---------------------------------------------------------------------------
# TestSocialResearcherFallback
# ---------------------------------------------------------------------------


class TestSocialResearcherFallback:
    """Test fallback behaviour for MCP failures and no-MCP configs."""

    def test_no_mcp_url_returns_skip(self, monkeypatch):
        """Without MCP URL configured, node should return skip message."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(xhs_mcp_url="")
        monkeypatch.setattr(mod, "config", mock_config)

        result = social_researcher_node(_make_state())
        assert result["social_insight"].summary == _SKIP_SUMMARY
        assert result["social_insight"].sample_size == 0

    def test_mcp_failure_returns_skip(self, monkeypatch):
        """If MCP retrieval fails, should return skip message (not call LLM)."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(
            xhs_mcp_url="http://localhost:18060/mcp",
        )
        monkeypatch.setattr(mod, "config", mock_config)

        def _boom(method, params):
            raise ConnectionError("MCP server unreachable")

        monkeypatch.setattr(mod, "_mcp_call", _boom)

        result = social_researcher_node(_make_state())
        assert result["social_insight"].summary == _SKIP_SUMMARY

    def test_empty_mcp_results_returns_skip(self, monkeypatch):
        """If MCP returns empty results, should return skip message."""
        import agent.agents.social_researcher as mod
        from agent.config import AgentConfig

        mock_config = AgentConfig(
            xhs_mcp_url="http://localhost:18060/mcp",
        )
        monkeypatch.setattr(mod, "config", mock_config)

        def _empty(method, params):
            return []

        monkeypatch.setattr(mod, "_mcp_call", _empty)

        result = social_researcher_node(_make_state())
        assert result["social_insight"].summary == _SKIP_SUMMARY
