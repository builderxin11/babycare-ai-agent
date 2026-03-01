"""Data Scientist agent — FUNCTIONAL.

Performs pure-Python statistical analysis on PhysiologyLog data:
- Daily aggregation of feeding volume, sleep duration, diaper count
- Mean-deviation anomaly detection (>25% threshold)
- Correlation with ContextEvents (e.g., vaccines)
"""

from __future__ import annotations

from collections import defaultdict
from datetime import date

from langchain_core.messages import AIMessage

from agent.models.domain import ContextEvent, PhysiologyLog
from agent.models.enums import PhysiologyLogType
from agent.models.outputs import Citation, TrendAnalysis, TrendAnomaly
from agent.models.state import AgentState
from agent.tools.mock_data import MOCK_CONTEXT_EVENTS, generate_mock_physiology_logs

# Anomaly detection threshold: flag if >25% deviation from mean
ANOMALY_THRESHOLD = 0.25


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


def data_scientist_node(state: AgentState) -> dict:
    """Analyze physiology logs and detect anomalies.

    TODO: Replace mock data with DynamoDB queries via Amplify API.
    TODO: Replace pure-Python stats with LLM-assisted interpretation.
    """
    # Use mock data for now
    logs = generate_mock_physiology_logs()
    events = MOCK_CONTEXT_EVENTS

    # Step 1: Aggregate daily
    daily = _aggregate_daily(logs)

    # Step 2: Detect anomalies
    anomalies = _detect_anomalies(daily)

    # Step 3: Correlate with context events
    correlations = _correlate_events(anomalies, events)

    # Build output
    num_days = len(daily)
    num_anomalies = len(anomalies)

    summary = (
        f"Analyzed {num_days} days of physiology data for {state.get('baby_name', 'baby')}. "
        f"Detected {num_anomalies} anomalies across feeding, sleep, and diaper metrics."
    )
    if correlations:
        summary += f" Found {len(correlations)} correlation(s) with context events."

    trend = TrendAnalysis(
        summary=summary,
        anomalies=anomalies,
        correlations=correlations,
        citations=[Citation(
            source_type="data_analysis",
            reference=f"PhysiologyLog analysis ({num_days} days, {len(logs)} records)",
        )],
    )

    return {
        "trend_analysis": trend,
        "agents_completed": ["data_scientist"],
        "messages": [AIMessage(
            content=f"[data_scientist] {summary}",
            name="data_scientist",
        )],
    }
