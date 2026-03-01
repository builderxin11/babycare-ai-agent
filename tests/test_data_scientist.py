"""Tests for the Data Scientist agent."""

from agent.agents.data_scientist import data_scientist_node
from agent.models.outputs import TrendAnalysis


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


class TestDataScientist:
    def test_produces_trend_analysis(self):
        """Node should produce a TrendAnalysis in its return dict."""
        result = data_scientist_node(_make_state())
        assert "trend_analysis" in result
        assert isinstance(result["trend_analysis"], TrendAnalysis)

    def test_detects_anomalies(self):
        """Mock data has post-vaccine anomalies — agent should detect them."""
        result = data_scientist_node(_make_state())
        trend = result["trend_analysis"]
        assert len(trend.anomalies) > 0, "Expected anomalies in mock data"

    def test_detects_vaccine_correlation(self):
        """Agent should correlate anomalies with the DTaP vaccine event."""
        result = data_scientist_node(_make_state())
        trend = result["trend_analysis"]
        assert len(trend.correlations) > 0, "Expected vaccine correlation"
        assert any(
            "VACCINE" in c.upper() for c in trend.correlations
        ), "Expected VACCINE in correlations"

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
