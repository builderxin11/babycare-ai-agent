"""DynamoDB query helpers for PhysiologyLog and ContextEvent tables.

Uses boto3.resource (Table.query) which returns plain Python dicts,
avoiding manual DynamoDB attribute unmarshalling.

Lazy-imports boto3 inside functions so mock mode never touches AWS SDK.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone

from agent.models.domain import ContextEvent, PhysiologyLog

logger = logging.getLogger(__name__)


class DynamoDBQueryError(Exception):
    """Raised when a DynamoDB query fails."""


def query_physiology_logs(
    table_name: str,
    baby_id: str,
    lookback_days: int,
    region: str,
) -> list[PhysiologyLog]:
    """Query PhysiologyLog GSI for the last N days of data.

    GSI: physiologyLogsByBabyIdAndStartTime
      - Partition key: babyId (S)
      - Sort key: startTime (S, ISO-8601)
    """
    import boto3
    from boto3.dynamodb.conditions import Key

    try:
        table = boto3.resource("dynamodb", region_name=region).Table(table_name)
        start_iso = (
            datetime.now(tz=timezone.utc) - timedelta(days=lookback_days)
        ).isoformat()

        items: list[dict] = []
        kwargs = {
            "IndexName": "physiologyLogsByBabyIdAndStartTime",
            "KeyConditionExpression": (
                Key("babyId").eq(baby_id) & Key("startTime").gte(start_iso)
            ),
        }

        while True:
            response = table.query(**kwargs)
            items.extend(response.get("Items", []))
            last_key = response.get("LastEvaluatedKey")
            if not last_key:
                break
            kwargs["ExclusiveStartKey"] = last_key

        logs = [PhysiologyLog.model_validate(item) for item in items]
        logger.info(
            "Queried %d PhysiologyLog records for baby %s (last %d days)",
            len(logs),
            baby_id,
            lookback_days,
        )
        return logs

    except Exception as exc:
        raise DynamoDBQueryError(
            f"Failed to query PhysiologyLog table '{table_name}': {exc}"
        ) from exc


def query_context_events(
    table_name: str,
    baby_id: str,
    lookback_days: int,
    region: str,
) -> list[ContextEvent]:
    """Query ContextEvent GSI for the last N days of data.

    GSI: contextEventsByBabyIdAndStartDate
      - Partition key: babyId (S)
      - Sort key: startDate (S, ISO-8601 date)
    """
    import boto3
    from boto3.dynamodb.conditions import Key

    try:
        table = boto3.resource("dynamodb", region_name=region).Table(table_name)
        start_date = (date.today() - timedelta(days=lookback_days)).isoformat()

        items: list[dict] = []
        kwargs = {
            "IndexName": "contextEventsByBabyIdAndStartDate",
            "KeyConditionExpression": (
                Key("babyId").eq(baby_id) & Key("startDate").gte(start_date)
            ),
        }

        while True:
            response = table.query(**kwargs)
            items.extend(response.get("Items", []))
            last_key = response.get("LastEvaluatedKey")
            if not last_key:
                break
            kwargs["ExclusiveStartKey"] = last_key

        events = [ContextEvent.model_validate(item) for item in items]
        logger.info(
            "Queried %d ContextEvent records for baby %s (last %d days)",
            len(events),
            baby_id,
            lookback_days,
        )
        return events

    except Exception as exc:
        raise DynamoDBQueryError(
            f"Failed to query ContextEvent table '{table_name}': {exc}"
        ) from exc
