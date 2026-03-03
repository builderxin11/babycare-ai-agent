"""Tests for Daily Health Report generation."""

from datetime import date, datetime

import pytest

from agent.models.outputs import (
    Citation,
    DailyReport,
    HealthStatus,
    RiskLevel,
    TrendDirection,
)
from agent.report.generator import (
    _map_risk_to_health_status,
    _compute_trend_direction,
    _generate_synthetic_question,
)


class TestDailyReportModel:
    """Tests for the DailyReport Pydantic model."""

    def test_required_fields(self):
        """DailyReport should require core fields."""
        report = DailyReport(
            baby_id="baby-123",
            baby_name="Test Baby",
            report_date=date.today(),
            summary="Baby had a good day.",
        )
        assert report.baby_id == "baby-123"
        assert report.baby_name == "Test Baby"
        assert report.health_status == HealthStatus.HEALTHY  # default

    def test_health_status_enum(self):
        """HealthStatus enum values should serialize correctly."""
        assert HealthStatus.HEALTHY.value == "healthy"
        assert HealthStatus.MONITOR.value == "monitor"
        assert HealthStatus.CONCERN.value == "concern"

    def test_trend_direction_enum(self):
        """TrendDirection enum values should serialize correctly."""
        assert TrendDirection.IMPROVING.value == "improving"
        assert TrendDirection.STABLE.value == "stable"
        assert TrendDirection.DECLINING.value == "declining"

    def test_confidence_bounds(self):
        """Confidence score should be bounded 0-1."""
        report = DailyReport(
            baby_id="baby-123",
            baby_name="Test Baby",
            report_date=date.today(),
            summary="Test",
            confidence_score=0.95,
        )
        assert report.confidence_score == 0.95

        with pytest.raises(ValueError):
            DailyReport(
                baby_id="baby-123",
                baby_name="Test Baby",
                report_date=date.today(),
                summary="Test",
                confidence_score=1.5,  # Out of bounds
            )

    def test_default_disclaimer(self):
        """DailyReport should have a default disclaimer."""
        report = DailyReport(
            baby_id="baby-123",
            baby_name="Test Baby",
            report_date=date.today(),
            summary="Test",
        )
        assert "AI-generated" in report.disclaimer
        assert "not a substitute" in report.disclaimer

    def test_generated_at_auto(self):
        """generated_at should be auto-populated."""
        report = DailyReport(
            baby_id="baby-123",
            baby_name="Test Baby",
            report_date=date.today(),
            summary="Test",
        )
        assert report.generated_at is not None
        assert isinstance(report.generated_at, datetime)


class TestRiskToHealthMapping:
    """Tests for risk level to health status mapping."""

    def test_low_risk_maps_to_healthy(self):
        assert _map_risk_to_health_status(RiskLevel.LOW) == HealthStatus.HEALTHY

    def test_medium_risk_maps_to_monitor(self):
        assert _map_risk_to_health_status(RiskLevel.MEDIUM) == HealthStatus.MONITOR

    def test_high_risk_maps_to_concern(self):
        assert _map_risk_to_health_status(RiskLevel.HIGH) == HealthStatus.CONCERN


class TestTrendDirection:
    """Tests for trend direction computation."""

    def test_no_trend_returns_stable(self):
        """No trend analysis should return STABLE."""
        assert _compute_trend_direction(None) == TrendDirection.STABLE

    def test_empty_anomalies_returns_stable(self):
        """Empty anomalies list should return STABLE."""
        from agent.models.outputs import TrendAnalysis
        trend = TrendAnalysis(summary="Test", anomalies=[])
        assert _compute_trend_direction(trend) == TrendDirection.STABLE


class TestSyntheticQuestion:
    """Tests for synthetic question generation."""

    def test_includes_baby_name(self):
        """Synthetic question should include baby name."""
        question = _generate_synthetic_question("Luna", date(2026, 3, 2))
        assert "Luna" in question

    def test_includes_date(self):
        """Synthetic question should include report date."""
        question = _generate_synthetic_question("Luna", date(2026, 3, 2))
        assert "2026-03-02" in question

    def test_asks_for_summary(self):
        """Synthetic question should ask for health summary."""
        question = _generate_synthetic_question("Luna", date(2026, 3, 2))
        assert "health" in question.lower() or "summary" in question.lower()
