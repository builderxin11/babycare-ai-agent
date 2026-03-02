"""Domain models mirroring the Amplify/DynamoDB schema.

Uses Pydantic with camelCase aliases for seamless DynamoDB ↔ Python interop.
"""

from __future__ import annotations

import json
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from .enums import BabyGender, ContextEventType, PhysiologyLogType, PhysiologyLogUnit


class Baby(BaseModel):
    """Baby profile — mirrors the Amplify Baby model."""

    model_config = ConfigDict(populate_by_name=True)

    id: str
    family_id: str = Field(alias="familyId")
    name: str
    birth_date: date = Field(alias="birthDate")
    gender: BabyGender | None = None
    notes: str | None = None


class PhysiologyLog(BaseModel):
    """Time-series routine data — mirrors the Amplify PhysiologyLog model."""

    model_config = ConfigDict(populate_by_name=True)

    id: str
    baby_id: str = Field(alias="babyId")
    type: PhysiologyLogType
    start_time: datetime = Field(alias="startTime")
    end_time: datetime | None = Field(default=None, alias="endTime")
    amount: float | None = None
    unit: PhysiologyLogUnit | None = None
    notes: str | None = None


class ContextEvent(BaseModel):
    """Non-routine events — mirrors the Amplify ContextEvent model."""

    model_config = ConfigDict(populate_by_name=True)

    id: str
    baby_id: str = Field(alias="babyId")
    type: ContextEventType
    title: str
    start_date: date = Field(alias="startDate")
    end_date: date | None = Field(default=None, alias="endDate")
    metadata: dict | None = None
    notes: str | None = None

    @field_validator("metadata", mode="before")
    @classmethod
    def _parse_awsjson_metadata(cls, v: object) -> dict | None:
        """DynamoDB AWSJSON stores dict fields as JSON strings."""
        if isinstance(v, str):
            return json.loads(v)
        return v
