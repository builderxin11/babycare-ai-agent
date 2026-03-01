"""Mock data fixtures for development and testing.

Scenario: 4-month-old Mia received a DTaP vaccine on day 5.
Post-vaccine days (5-7) show reduced feeding and increased sleep — realistic
anomalies the Data Scientist agent should detect.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta

from agent.models.domain import Baby, ContextEvent, PhysiologyLog
from agent.models.enums import (
    BabyGender,
    ContextEventType,
    PhysiologyLogType,
    PhysiologyLogUnit,
)

MOCK_BABY = Baby(
    id="baby-001",
    familyId="family-001",
    name="Mia",
    birthDate=date(2025, 10, 15),
    gender=BabyGender.FEMALE,
    notes="Healthy, growing well",
)


def _ts(day: int, hour: int, minute: int = 0) -> datetime:
    """Helper: create a datetime for a given day offset and time."""
    base = date(2026, 2, 20)
    return datetime.combine(base + timedelta(days=day), datetime.min.time().replace(hour=hour, minute=minute))


def generate_mock_physiology_logs() -> list[PhysiologyLog]:
    """Generate 7 days of feeding + sleep + diaper logs.

    Days 1-4: normal baseline
    Day 5: DTaP vaccine administered — start of anomalies
    Days 5-7: reduced feeding (~20-30% less), longer sleep, fewer diapers
    """
    logs: list[PhysiologyLog] = []
    log_id = 0

    # Normal baseline values (per day)
    normal_feeding_ml = 720  # ~6 feeds × 120ml
    normal_sleep_min = 840   # ~14 hours
    normal_diapers = 8

    for day in range(7):
        is_post_vaccine = day >= 4  # days 5-7 (0-indexed day 4-6)

        # --- Feeding ---
        feeds_per_day = 5 if is_post_vaccine else 6
        ml_per_feed = 95 if is_post_vaccine else 120
        for feed in range(feeds_per_day):
            hour = 6 + feed * 3
            log_id += 1
            logs.append(PhysiologyLog(
                id=f"log-{log_id:03d}",
                babyId=MOCK_BABY.id,
                type=PhysiologyLogType.MILK_FORMULA,
                startTime=_ts(day, hour),
                endTime=_ts(day, hour, 20),
                amount=float(ml_per_feed + ((-1) ** feed) * 5),  # slight variation
                unit=PhysiologyLogUnit.ML,
            ))

        # --- Sleep ---
        sleep_minutes = 960 if is_post_vaccine else 840  # 16h vs 14h
        # Night sleep
        log_id += 1
        logs.append(PhysiologyLog(
            id=f"log-{log_id:03d}",
            babyId=MOCK_BABY.id,
            type=PhysiologyLogType.SLEEP,
            startTime=_ts(day, 20, 0),
            endTime=_ts(day, 20, 0) + timedelta(minutes=sleep_minutes * 2 // 3),
            amount=float(sleep_minutes * 2 // 3),
            unit=PhysiologyLogUnit.MINUTES,
        ))
        # Nap
        log_id += 1
        logs.append(PhysiologyLog(
            id=f"log-{log_id:03d}",
            babyId=MOCK_BABY.id,
            type=PhysiologyLogType.SLEEP,
            startTime=_ts(day, 13, 0),
            endTime=_ts(day, 13, 0) + timedelta(minutes=sleep_minutes // 3),
            amount=float(sleep_minutes // 3),
            unit=PhysiologyLogUnit.MINUTES,
        ))

        # --- Diapers ---
        diaper_count = 6 if is_post_vaccine else normal_diapers
        for d in range(diaper_count):
            hour = 7 + d * 2
            if hour >= 22:
                break
            log_id += 1
            dtype = PhysiologyLogType.DIAPER_WET if d % 3 != 0 else PhysiologyLogType.DIAPER_DIRTY
            logs.append(PhysiologyLog(
                id=f"log-{log_id:03d}",
                babyId=MOCK_BABY.id,
                type=dtype,
                startTime=_ts(day, hour),
                amount=1.0,
                unit=PhysiologyLogUnit.COUNT,
            ))

    return logs


MOCK_CONTEXT_EVENTS: list[ContextEvent] = [
    ContextEvent(
        id="evt-001",
        babyId=MOCK_BABY.id,
        type=ContextEventType.VACCINE,
        title="DTaP Vaccine (2nd dose)",
        startDate=date(2026, 2, 24),  # day 5 (0-indexed day 4)
        notes="Administered at pediatrician's office, mild fussiness afterward",
    ),
    ContextEvent(
        id="evt-002",
        babyId=MOCK_BABY.id,
        type=ContextEventType.MILESTONE,
        title="Rolling over (tummy to back)",
        startDate=date(2026, 2, 22),  # day 3
        notes="First time rolling over consistently",
    ),
]
