"""Tests for Pydantic domain and output models."""

from datetime import date

from agent.models.domain import Baby, PhysiologyLog
from agent.models.enums import BabyGender, PhysiologyLogType, PhysiologyLogUnit
from agent.models.outputs import Citation, CritiqueResult, ParentingAdvice, RiskLevel


class TestBaby:
    def test_camel_case_alias(self):
        """Baby model accepts camelCase input (DynamoDB format)."""
        baby = Baby(
            id="b-1",
            familyId="f-1",
            name="Test",
            birthDate=date(2025, 1, 1),
            gender=BabyGender.MALE,
        )
        assert baby.family_id == "f-1"
        assert baby.birth_date == date(2025, 1, 1)

    def test_snake_case_field(self):
        """Baby model also accepts snake_case input."""
        baby = Baby(
            id="b-2",
            family_id="f-2",
            name="Test2",
            birth_date=date(2025, 6, 1),
        )
        assert baby.family_id == "f-2"


class TestPhysiologyLog:
    def test_camel_case_alias(self):
        log = PhysiologyLog(
            id="log-1",
            babyId="b-1",
            type=PhysiologyLogType.MILK_FORMULA,
            startTime="2026-02-20T08:00:00",
            amount=120.0,
            unit=PhysiologyLogUnit.ML,
        )
        assert log.baby_id == "b-1"
        assert log.amount == 120.0


class TestCitation:
    def test_required_fields(self):
        c = Citation(source_type="book", reference="AAP Guide")
        assert c.source_type == "book"
        assert c.reference == "AAP Guide"
        assert c.detail is None


class TestParentingAdvice:
    def test_confidence_bounds(self):
        """Confidence score must be between 0 and 1."""
        advice = ParentingAdvice(
            question="test",
            summary="test",
            confidence_score=0.85,
            risk_level=RiskLevel.LOW,
        )
        assert 0.0 <= advice.confidence_score <= 1.0

    def test_default_disclaimer(self):
        advice = ParentingAdvice(
            question="q",
            summary="s",
            confidence_score=0.5,
        )
        assert "not a substitute" in advice.disclaimer


class TestCritiqueResult:
    def test_confidence_bounds_enforced(self):
        """CritiqueResult should enforce 0-1 bounds via Pydantic."""
        result = CritiqueResult(approved=True, confidence_score=0.9)
        assert result.confidence_score == 0.9

    def test_approved_with_issues(self):
        result = CritiqueResult(
            approved=False,
            confidence_score=0.5,
            issues=["Missing citations"],
        )
        assert not result.approved
        assert len(result.issues) == 1
