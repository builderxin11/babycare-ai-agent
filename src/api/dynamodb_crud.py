"""DynamoDB CRUD operations for Baby, PhysiologyLog, and ContextEvent.

Uses boto3.resource for cleaner API and automatic type conversion.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key

from agent.config import config

logger = logging.getLogger(__name__)


def _get_table(table_name: str):
    """Get a DynamoDB table resource."""
    return boto3.resource("dynamodb", region_name=config.aws_region).Table(table_name)


# -----------------------------------------------------------------------------
# Baby CRUD
# -----------------------------------------------------------------------------


def list_babies(user_id: str | None = None) -> list[dict[str, Any]]:
    """List babies, optionally filtered by user ownership."""
    if not config.baby_table:
        logger.warning("BABY_TABLE not configured, returning empty list")
        return []

    table = _get_table(config.baby_table)
    items: list[dict] = []

    response = table.scan()
    items.extend(response.get("Items", []))

    while "LastEvaluatedKey" in response:
        response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
        items.extend(response.get("Items", []))

    # Filter by user ownership if authenticated
    if user_id:
        items = [
            item for item in items
            if user_id in item.get("familyOwners", [])
        ]

    logger.info("Listed %d babies for user %s", len(items), user_id or "anonymous")
    return items


def get_baby(baby_id: str) -> dict[str, Any] | None:
    """Get a single baby by ID."""
    if not config.baby_table:
        return None

    table = _get_table(config.baby_table)
    response = table.get_item(Key={"id": baby_id})
    return response.get("Item")


def create_baby(
    family_id: str,
    name: str,
    birth_date: str,
    gender: str | None = None,
    notes: str | None = None,
    user_id: str | None = None,
) -> dict[str, Any]:
    """Create a new baby."""
    if not config.baby_table:
        raise ValueError("BABY_TABLE not configured")

    table = _get_table(config.baby_table)
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "id": str(uuid.uuid4()),
        "familyId": family_id,
        "name": name,
        "birthDate": birth_date,
        "createdAt": now,
        "updatedAt": now,
    }

    if gender:
        item["gender"] = gender
    if notes:
        item["notes"] = notes
    if user_id:
        item["familyOwners"] = [user_id]

    table.put_item(Item=item)
    logger.info("Created baby: %s for user %s", item["id"], user_id or "anonymous")
    return item


def delete_baby(baby_id: str) -> bool:
    """Delete a baby by ID."""
    if not config.baby_table:
        return False

    table = _get_table(config.baby_table)
    table.delete_item(Key={"id": baby_id})
    logger.info("Deleted baby: %s", baby_id)
    return True


# -----------------------------------------------------------------------------
# PhysiologyLog CRUD
# -----------------------------------------------------------------------------


def list_physiology_logs(baby_id: str, limit: int = 50) -> list[dict[str, Any]]:
    """List physiology logs for a baby, most recent first."""
    if not config.physiology_log_table:
        logger.warning("PHYSIOLOGY_LOG_TABLE not configured, returning empty list")
        return []

    table = _get_table(config.physiology_log_table)
    items: list[dict] = []

    response = table.query(
        IndexName="physiologyLogsByBabyIdAndStartTime",
        KeyConditionExpression=Key("babyId").eq(baby_id),
        ScanIndexForward=False,  # Most recent first
        Limit=limit,
    )
    items.extend(response.get("Items", []))

    logger.info("Listed %d physiology logs for baby %s", len(items), baby_id)
    return items


def create_physiology_log(
    baby_id: str,
    log_type: str,
    start_time: str,
    end_time: str | None = None,
    amount: float | None = None,
    unit: str | None = None,
    notes: str | None = None,
) -> dict[str, Any]:
    """Create a new physiology log."""
    if not config.physiology_log_table:
        raise ValueError("PHYSIOLOGY_LOG_TABLE not configured")

    table = _get_table(config.physiology_log_table)
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "id": str(uuid.uuid4()),
        "babyId": baby_id,
        "type": log_type,
        "startTime": start_time,
        "createdAt": now,
        "updatedAt": now,
    }

    if end_time:
        item["endTime"] = end_time
    if amount is not None:
        item["amount"] = amount
    if unit:
        item["unit"] = unit
    if notes:
        item["notes"] = notes

    table.put_item(Item=item)
    logger.info("Created physiology log: %s", item["id"])
    return item


def delete_physiology_log(log_id: str) -> bool:
    """Delete a physiology log by ID."""
    if not config.physiology_log_table:
        return False

    table = _get_table(config.physiology_log_table)
    table.delete_item(Key={"id": log_id})
    logger.info("Deleted physiology log: %s", log_id)
    return True


# -----------------------------------------------------------------------------
# ContextEvent CRUD
# -----------------------------------------------------------------------------


def list_context_events(baby_id: str, limit: int = 20) -> list[dict[str, Any]]:
    """List context events for a baby, most recent first."""
    if not config.context_event_table:
        logger.warning("CONTEXT_EVENT_TABLE not configured, returning empty list")
        return []

    table = _get_table(config.context_event_table)
    items: list[dict] = []

    response = table.query(
        IndexName="contextEventsByBabyIdAndStartDate",
        KeyConditionExpression=Key("babyId").eq(baby_id),
        ScanIndexForward=False,  # Most recent first
        Limit=limit,
    )
    items.extend(response.get("Items", []))

    logger.info("Listed %d context events for baby %s", len(items), baby_id)
    return items


def create_context_event(
    baby_id: str,
    event_type: str,
    title: str,
    start_date: str,
    end_date: str | None = None,
    notes: str | None = None,
    metadata: dict | None = None,
) -> dict[str, Any]:
    """Create a new context event."""
    if not config.context_event_table:
        raise ValueError("CONTEXT_EVENT_TABLE not configured")

    table = _get_table(config.context_event_table)
    now = datetime.now(timezone.utc).isoformat()

    item = {
        "id": str(uuid.uuid4()),
        "babyId": baby_id,
        "type": event_type,
        "title": title,
        "startDate": start_date,
        "createdAt": now,
        "updatedAt": now,
    }

    if end_date:
        item["endDate"] = end_date
    if notes:
        item["notes"] = notes
    if metadata:
        item["metadata"] = metadata

    table.put_item(Item=item)
    logger.info("Created context event: %s", item["id"])
    return item


def delete_context_event(event_id: str) -> bool:
    """Delete a context event by ID."""
    if not config.context_event_table:
        return False

    table = _get_table(config.context_event_table)
    table.delete_item(Key={"id": event_id})
    logger.info("Deleted context event: %s", event_id)
    return True
