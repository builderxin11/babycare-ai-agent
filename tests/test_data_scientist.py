"""Tests for the Data Scientist agent."""

from __future__ import annotations

from unittest.mock import patch

from agent.agents.data_scientist import _analyze, _run_fallback, data_scientist_node
from agent.models.outputs import SourceStatusCode, TrendAnalysis
from agent.tools.dynamodb import DynamoDBQueryError
from agent.tools.mock_data import MOCK_CONTEXT_EVENTS, generate_mock_physiology_logs


def _make_state(**overrides) -> dict:
    """Create a minimal AgentState dict for testing."""
    state = {
        "question": "Test question",
        "baby_id": "baby-001",
        "baby_name": "Mia",
        "baby_age_months": 4,
        "messages": [],
        "agents_completed": [],
    }
    state.update(overrides)
    return state


class TestDataScientistFallback:
    """Tests for the fallback (no DynamoDB configured) execution path."""

    def test_produces_trend_analysis(self):
        """Node should produce a TrendAnalysis in its return dict."""
        result = data_scientist_node(_make_state())
        assert "trend_analysis" in result
        assert isinstance(result["trend_analysis"], TrendAnalysis)

    def test_fallback_has_no_anomalies(self):
        """Fallback with no data should produce zero anomalies."""
        result = data_scientist_node(_make_state())
        trend = result["trend_analysis"]
        assert len(trend.anomalies) == 0, "Expected no anomalies in empty fallback"

    def test_fallback_has_no_correlations(self):
        """Fallback with no data should produce zero correlations."""
        result = data_scientist_node(_make_state())
        trend = result["trend_analysis"]
        assert len(trend.correlations) == 0, "Expected no correlations in empty fallback"

    def test_has_citations(self):
        """Output should include data analysis citations."""
        result = data_scientist_node(_make_state())
        trend = result["trend_analysis"]
        assert len(trend.citations) > 0
        assert trend.citations[0].source_type == "data_analysis"

    def test_marks_agent_completed(self):
        """Node should add 'data_scientist' to agents_completed."""
        result = data_scientist_node(_make_state())
        assert "data_scientist" in result["agents_completed"]

    def test_no_tables_returns_fallback_status(self):
        """Without table names configured, should produce FALLBACK status."""
        result = data_scientist_node(_make_state())
        status = result["source_statuses"][0]
        assert status.status == SourceStatusCode.FALLBACK
        assert "No DynamoDB tables configured" in status.message
        assert "No baby data available" in status.message


class TestAnalyzeHelper:
    """Tests for the shared _analyze() pipeline."""

    def test_returns_trend_and_count(self):
        """_analyze should return (TrendAnalysis, record_count)."""
        logs = generate_mock_physiology_logs()
        events = MOCK_CONTEXT_EVENTS
        trend, count = _analyze(logs, events, "Mia")
        assert isinstance(trend, TrendAnalysis)
        assert count == len(logs)

    def test_empty_data(self):
        """_analyze with no data should return zero anomalies."""
        trend, count = _analyze([], [], "Mia")
        assert count == 0
        assert len(trend.anomalies) == 0
        assert "0 days" in trend.summary


class TestRunFallback:
    """Tests for _run_fallback tier."""

    def test_returns_trend_analysis(self):
        """_run_fallback should return a valid but empty TrendAnalysis."""
        trend, count = _run_fallback(_make_state())
        assert isinstance(trend, TrendAnalysis)
        assert count == 0


class TestDataScientistTwoTier:
    """Tests for two-tier dispatch in data_scientist_node."""

    def test_dynamodb_success_returns_ok_status(self):
        """Successful DynamoDB query should produce SourceStatus OK."""
        logs = generate_mock_physiology_logs()
        events = MOCK_CONTEXT_EVENTS

        with (
            patch("agent.agents.data_scientist.config") as mock_config,
            patch("agent.agents.data_scientist.query_physiology_logs", return_value=logs),
            patch("agent.agents.data_scientist.query_context_events", return_value=events),
        ):
            mock_config.physiology_log_table = "PhysiologyLog-abc123"
            mock_config.context_event_table = "ContextEvent-abc123"
            mock_config.data_lookback_days = 7
            mock_config.aws_region = "us-west-2"
            result = data_scientist_node(_make_state())

        status = result["source_statuses"][0]
        assert status.status == SourceStatusCode.OK
        assert "DynamoDB" in status.message

    def test_dynamodb_failure_falls_back(self):
        """DynamoDB error should fall back to fixture data with FALLBACK status."""
        with (
            patch("agent.agents.data_scientist.config") as mock_config,
            patch(
                "agent.agents.data_scientist.query_physiology_logs",
                side_effect=DynamoDBQueryError("Connection refused"),
            ),
        ):
            mock_config.physiology_log_table = "PhysiologyLog-abc123"
            mock_config.context_event_table = "ContextEvent-abc123"
            result = data_scientist_node(_make_state())

        status = result["source_statuses"][0]
        assert status.status == SourceStatusCode.FALLBACK
        assert "DynamoDB query failed" in status.message
        # Should still produce a valid (but empty) TrendAnalysis
        assert isinstance(result["trend_analysis"], TrendAnalysis)
        assert len(result["trend_analysis"].anomalies) == 0

    def test_no_tables_returns_fallback(self):
        """No table config should produce FALLBACK."""
        with patch("agent.agents.data_scientist.config") as mock_config:
            mock_config.physiology_log_table = ""
            mock_config.context_event_table = ""
            result = data_scientist_node(_make_state())

        status = result["source_statuses"][0]
        assert status.status == SourceStatusCode.FALLBACK
        assert "No DynamoDB tables configured" in status.message

    def test_partial_table_config_returns_fallback(self):
        """Only one table configured should produce FALLBACK (needs both)."""
        with patch("agent.agents.data_scientist.config") as mock_config:
            mock_config.physiology_log_table = "PhysiologyLog-abc123"
            mock_config.context_event_table = ""  # missing
            result = data_scientist_node(_make_state())

        status = result["source_statuses"][0]
        assert status.status == SourceStatusCode.FALLBACK
