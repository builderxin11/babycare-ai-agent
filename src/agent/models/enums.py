"""Enums mirroring the DynamoDB/Amplify schema."""

from __future__ import annotations

from enum import StrEnum


class PhysiologyLogType(StrEnum):
    """Maps to PhysiologyLog.type in Amplify schema."""

    MILK_BREAST = "MILK_BREAST"
    MILK_FORMULA = "MILK_FORMULA"
    MILK_SOLID = "MILK_SOLID"
    SLEEP = "SLEEP"
    DIAPER_WET = "DIAPER_WET"
    DIAPER_DIRTY = "DIAPER_DIRTY"


class PhysiologyLogUnit(StrEnum):
    """Maps to PhysiologyLog.unit in Amplify schema."""

    ML = "ML"
    OZ = "OZ"
    MINUTES = "MINUTES"
    COUNT = "COUNT"


class ContextEventType(StrEnum):
    """Maps to ContextEvent.type in Amplify schema."""

    VACCINE = "VACCINE"
    TRAVEL = "TRAVEL"
    JET_LAG = "JET_LAG"
    ILLNESS = "ILLNESS"
    MILESTONE = "MILESTONE"
    OTHER = "OTHER"


class AgentSessionType(StrEnum):
    """Maps to AgentSession.sessionType in Amplify schema."""

    DATA_ANALYSIS = "DATA_ANALYSIS"
    MEDICAL_ADVICE = "MEDICAL_ADVICE"
    SOCIAL_SEARCH = "SOCIAL_SEARCH"
    GENERAL = "GENERAL"


class AgentSessionStatus(StrEnum):
    """Maps to AgentSession.status in Amplify schema."""

    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    INTERRUPTED = "INTERRUPTED"


class BabyGender(StrEnum):
    """Maps to Baby.gender in Amplify schema."""

    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"


class AgentRole(StrEnum):
    """Internal routing roles for the multi-agent system."""

    DATA_SCIENTIST = "data_scientist"
    MEDICAL_EXPERT = "medical_expert"
    SOCIAL_RESEARCHER = "social_researcher"
    CRITIQUE = "critique"
    SYNTHESIZE = "synthesize"
