"""Data Scientist agent — two-tier execution.

Performs pure-Python statistical analysis on PhysiologyLog data:
- Daily aggregation of feeding volume, sleep duration, diaper count
- Mean-deviation anomaly detection (>25% threshold)
- Correlation with ContextEvents (e.g., vaccines)

Execution tiers:
  1. DynamoDB tables configured -> _run_dynamodb()   (SourceStatus OK)
     any DynamoDB error         -> fallback _run_fallback() (SourceStatus FALLBACK)
  2. No tables configured       -> _run_fallback()   (SourceStatus FALLBACK)
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import date

from langchain_core.messages import AIMessage

from agent.config import config
from agent.models.domain import ContextEvent, PhysiologyLog
from agent.models.enums import PhysiologyLogType
from agent.models.outputs import Citation, SourceStatus, SourceStatusCode, TrendAnalysis, TrendAnomaly
from agent.models.state import AgentState
from agent.tools.dynamodb import DynamoDBQueryError, query_context_events, query_physiology_logs

logger = logging.getLogger(__name__)

# Anomaly detection threshold: flag if >25% deviation from mean
ANOMALY_THRESHOLD = 0.25


# ---------------------------------------------------------------------------
# Pure analysis helpers (shared by all tiers)
# ---------------------------------------------------------------------------


def _aggregate_daily(logs: list[PhysiologyLog]) -> dict[str, dict[str, float]]:
    """Aggregate logs into daily totals per metric."""
    daily: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))

    for log in logs:
        day_key = log.start_time.strftime("%Y-%m-%d")

        if log.type in (
            PhysiologyLogType.MILK_BREAST,
            PhysiologyLogType.MILK_FORMULA,
            PhysiologyLogType.MILK_SOLID,
        ):
            daily[day_key]["feeding_ml"] += log.amount or 0.0
        elif log.type == PhysiologyLogType.SLEEP:
            daily[day_key]["sleep_min"] += log.amount or 0.0
        elif log.type in (
            PhysiologyLogType.DIAPER_WET,
            PhysiologyLogType.DIAPER_DIRTY,
        ):
            daily[day_key]["diaper_count"] += log.amount or 0.0

    return dict(daily)


def _detect_anomalies(
    daily: dict[str, dict[str, float]],
) -> list[TrendAnomaly]:
    """Detect anomalies using expanding-window baseline.

    The baseline is computed from the first half of days (rounded up),
    then each subsequent day is compared against that stable baseline.
    This prevents anomalous days from diluting the baseline.
    """
    if not daily:
        return []

    sorted_days = sorted(daily.keys())
    # Use the first half as the baseline window
    baseline_end = max((len(sorted_days) + 1) // 2, 1)
    baseline_days = sorted_days[:baseline_end]

    metrics = ["feeding_ml", "sleep_min", "diaper_count"]
    baselines: dict[str, float] = {}
    for metric in metrics:
        values = [daily[d].get(metric, 0.0) for d in baseline_days]
        baselines[metric] = sum(values) / len(values) if values else 0.0

    anomalies: list[TrendAnomaly] = []
    for day_key in sorted_days:
        day_data = daily[day_key]
        for metric in metrics:
            value = day_data.get(metric, 0.0)
            baseline = baselines[metric]
            if baseline == 0:
                continue

            deviation = (value - baseline) / baseline
            if abs(deviation) > ANOMALY_THRESHOLD:
                direction = "above" if deviation > 0 else "below"
                anomalies.append(TrendAnomaly(
                    date=day_key,
                    metric=metric,
                    value=value,
                    baseline=round(baseline, 1),
                    deviation_pct=round(deviation * 100, 1),
                    description=f"{metric} is {abs(deviation)*100:.0f}% {direction} baseline on {day_key}",
                ))

    return anomalies


def _correlate_events(
    anomalies: list[TrendAnomaly],
    events: list[ContextEvent],
) -> list[str]:
    """Find context events that overlap with anomaly dates."""
    correlations: list[str] = []
    anomaly_dates = {a.date for a in anomalies}

    for event in events:
        event_start = event.start_date.isoformat()
        event_end = (event.end_date or event.start_date).isoformat()

        for adate in sorted(anomaly_dates):
            if event_start <= adate <= event_end or (
                # Also check if anomaly is within 2 days after event
                event.start_date <= date.fromisoformat(adate) <= date.fromisoformat(event_end + "Z"[:0])
            ):
                correlations.append(
                    f"{event.type.value}: '{event.title}' on {event_start} "
                    f"correlates with anomalies on {adate}"
                )
                break
        else:
            # Check proximity: anomalies within 3 days after event start
            for adate in sorted(anomaly_dates):
                days_after = (date.fromisoformat(adate) - event.start_date).days
                if 0 <= days_after <= 3:
                    correlations.append(
                        f"{event.type.value}: '{event.title}' on {event_start} "
                        f"likely correlates with anomalies on {adate} "
                        f"({days_after} day(s) after event)"
                    )
                    break

    return correlations


# ---------------------------------------------------------------------------
# Shared analysis pipeline
# ---------------------------------------------------------------------------


def _build_data_summary(
    daily: dict[str, dict[str, float]],
    events: list[ContextEvent],
    logs: list[PhysiologyLog],
) -> str:
    """Build a human-readable summary of raw daily aggregates and context events."""
    lines: list[str] = []

    if daily:
        lines.append("Daily totals (last 7 days):")
        for day_key in sorted(daily.keys()):
            day_data = daily[day_key]
            feeding = day_data.get("feeding_ml", 0)
            sleep = day_data.get("sleep_min", 0)
            diapers = int(day_data.get("diaper_count", 0))
            lines.append(
                f"- {day_key}: feeding {feeding:.0f}ml, sleep {sleep:.0f}min, diapers {diapers}"
            )
    else:
        lines.append("No physiology data recorded.")

    if events:
        lines.append("")
        lines.append("Context events:")
        for event in sorted(events, key=lambda e: e.start_date):
            lines.append(
                f"- {event.start_date.isoformat()}: {event.type.value} — \"{event.title}\""
            )
    else:
        lines.append("")
        lines.append("No context events recorded.")

    return "\n".join(lines)


def _analyze(
    logs: list[PhysiologyLog],
    events: list[ContextEvent],
    baby_name: str,
) -> tuple[TrendAnalysis, int]:
    """Run aggregation -> anomaly detection -> correlation -> build TrendAnalysis.

    Returns (TrendAnalysis, num_records) so callers can build SourceStatus messages.
    """
    daily = _aggregate_daily(logs)
    anomalies = _detect_anomalies(daily)
    correlations = _correlate_events(anomalies, events)

    num_days = len(daily)
    num_anomalies = len(anomalies)

    summary = (
        f"Analyzed {num_days} days of physiology data for {baby_name}. "
        f"Detected {num_anomalies} anomalies across feeding, sleep, and diaper metrics."
    )
    if correlations:
        summary += f" Found {len(correlations)} correlation(s) with context events."

    data_summary = _build_data_summary(daily, events, logs)

    trend = TrendAnalysis(
        summary=summary,
        data_summary=data_summary,
        anomalies=anomalies,
        correlations=correlations,
        citations=[Citation(
            source_type="data_analysis",
            reference=f"PhysiologyLog analysis ({num_days} days, {len(logs)} records)",
        )],
    )

    return trend, len(logs)


# ---------------------------------------------------------------------------
# Execution tiers
# ---------------------------------------------------------------------------


def _run_fallback(state: AgentState) -> tuple[TrendAnalysis, int]:
    """Return an empty analysis when no real data is available.

    Used when DynamoDB tables are not configured or when a query fails.
    """
    baby_name = state.get("baby_name", "baby")
    return _analyze([], [], baby_name)


def _run_dynamodb(state: AgentState) -> tuple[TrendAnalysis, int]:
    """Query DynamoDB for real data and run analysis pipeline.

    Raises DynamoDBQueryError on any failure so the caller can fall back.
    """
    baby_id = state.get("baby_id", "")
    baby_name = state.get("baby_name", "baby")

    logs = query_physiology_logs(
        table_name=config.physiology_log_table,
        baby_id=baby_id,
        lookback_days=config.data_lookback_days,
        region=config.aws_region,
    )
    events = query_context_events(
        table_name=config.context_event_table,
        baby_id=baby_id,
        lookback_days=config.data_lookback_days,
        region=config.aws_region,
    )

    return _analyze(logs, events, baby_name)


# ---------------------------------------------------------------------------
# Graph node entry point
# ---------------------------------------------------------------------------


def data_scientist_node(state: AgentState) -> dict:
    """Analyze physiology logs and detect anomalies.

    Routes to DynamoDB or fallback depending on configuration.
    DynamoDB errors fall back to empty analysis with FALLBACK status.
    """
    if config.physiology_log_table and config.context_event_table:
        try:
            trend, num_records = _run_dynamodb(state)
            source_status = SourceStatus(
                source="Baby Data Analysis",
                status=SourceStatusCode.OK,
                message=f"Analyzed {len(trend.anomalies)} anomalies from {num_records} records (DynamoDB).",
            )
        except DynamoDBQueryError:
            logger.warning(
                "DynamoDB query failed; no baby data available.",
                exc_info=True,
            )
            trend, num_records = _run_fallback(state)
            source_status = SourceStatus(
                source="Baby Data Analysis",
                status=SourceStatusCode.FALLBACK,
                message=(
                    "DynamoDB query failed. No baby data available; "
                    "trend analysis is empty."
                ),
            )
    else:
        logger.info(
            "DynamoDB table names not configured; no baby data available.",
        )
        trend, num_records = _run_fallback(state)
        source_status = SourceStatus(
            source="Baby Data Analysis",
            status=SourceStatusCode.FALLBACK,
            message=(
                "No DynamoDB tables configured. No baby data available; "
                "trend analysis is empty."
            ),
        )

    return {
        "trend_analysis": trend,
        "agents_completed": ["data_scientist"],
        "source_statuses": [source_status],
        "messages": [AIMessage(
            content=f"[data_scientist] {trend.summary}",
            name="data_scientist",
        )],
    }
