"""Tests for the DynamoDB query module."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from agent.models.domain import ContextEvent, PhysiologyLog
from agent.tools.dynamodb import DynamoDBQueryError, query_context_events, query_physiology_logs


def _make_physiology_item(**overrides) -> dict:
    """Create a raw DynamoDB item dict for PhysiologyLog."""
    item = {
        "id": "log-001",
        "babyId": "baby-001",
        "type": "MILK_FORMULA",
        "startTime": "2026-02-25T08:00:00",
        "endTime": "2026-02-25T08:20:00",
        "amount": 120.0,
        "unit": "ML",
    }
    item.update(overrides)
    return item


def _make_context_event_item(**overrides) -> dict:
    """Create a raw DynamoDB item dict for ContextEvent."""
    item = {
        "id": "evt-001",
        "babyId": "baby-001",
        "type": "VACCINE",
        "title": "DTaP Vaccine",
        "startDate": "2026-02-24",
    }
    item.update(overrides)
    return item


def _mock_boto3_table(mock_resource, query_return):
    """Wire up mock_resource -> Table -> query to return the given data."""
    mock_table = MagicMock()
    mock_resource.return_value.Table.return_value = mock_table
    if isinstance(query_return, list):
        mock_table.query.side_effect = query_return
    else:
        mock_table.query.return_value = query_return
    return mock_table


class TestQueryPhysiologyLogs:
    """Tests for query_physiology_logs."""

    @patch("boto3.resource")
    def test_returns_list_of_physiology_logs(self, mock_resource):
        """Should return a list of PhysiologyLog models from DynamoDB items."""
        mock_table = _mock_boto3_table(mock_resource, {
            "Items": [_make_physiology_item(), _make_physiology_item(id="log-002")],
        })

        result = query_physiology_logs("TestTable", "baby-001", 7, "us-west-2")

        assert len(result) == 2
        assert all(isinstance(r, PhysiologyLog) for r in result)
        assert result[0].id == "log-001"
        assert result[1].id == "log-002"

    @patch("boto3.resource")
    def test_uses_correct_gsi(self, mock_resource):
        """Should query the physiologyLogsByBabyIdAndStartTime GSI."""
        mock_table = _mock_boto3_table(mock_resource, {"Items": []})

        query_physiology_logs("TestTable", "baby-001", 7, "us-west-2")

        call_kwargs = mock_table.query.call_args[1]
        assert call_kwargs["IndexName"] == "physiologyLogsByBabyIdAndStartTime"

    @patch("boto3.resource")
    def test_handles_pagination(self, mock_resource):
        """Should follow LastEvaluatedKey for paginated results."""
        mock_table = _mock_boto3_table(mock_resource, [
            {
                "Items": [_make_physiology_item(id="log-001")],
                "LastEvaluatedKey": {"id": "log-001"},
            },
            {
                "Items": [_make_physiology_item(id="log-002")],
            },
        ])

        result = query_physiology_logs("TestTable", "baby-001", 7, "us-west-2")

        assert len(result) == 2
        assert mock_table.query.call_count == 2

    @patch("boto3.resource")
    def test_raises_dynamodb_query_error_on_failure(self, mock_resource):
        """Should wrap exceptions in DynamoDBQueryError."""
        mock_table = MagicMock()
        mock_resource.return_value.Table.return_value = mock_table
        mock_table.query.side_effect = Exception("Connection refused")

        with pytest.raises(DynamoDBQueryError, match="Failed to query PhysiologyLog"):
            query_physiology_logs("TestTable", "baby-001", 7, "us-west-2")

    @patch("boto3.resource")
    def test_empty_result(self, mock_resource):
        """Should return empty list when no items match."""
        _mock_boto3_table(mock_resource, {"Items": []})

        result = query_physiology_logs("TestTable", "baby-001", 7, "us-west-2")

        assert result == []


class TestQueryContextEvents:
    """Tests for query_context_events."""

    @patch("boto3.resource")
    def test_returns_list_of_context_events(self, mock_resource):
        """Should return a list of ContextEvent models from DynamoDB items."""
        _mock_boto3_table(mock_resource, {
            "Items": [_make_context_event_item()],
        })

        result = query_context_events("TestTable", "baby-001", 7, "us-west-2")

        assert len(result) == 1
        assert isinstance(result[0], ContextEvent)
        assert result[0].title == "DTaP Vaccine"

    @patch("boto3.resource")
    def test_uses_correct_gsi(self, mock_resource):
        """Should query the contextEventsByBabyIdAndStartDate GSI."""
        mock_table = _mock_boto3_table(mock_resource, {"Items": []})

        query_context_events("TestTable", "baby-001", 7, "us-west-2")

        call_kwargs = mock_table.query.call_args[1]
        assert call_kwargs["IndexName"] == "contextEventsByBabyIdAndStartDate"

    @patch("boto3.resource")
    def test_handles_pagination(self, mock_resource):
        """Should follow LastEvaluatedKey for paginated results."""
        mock_table = _mock_boto3_table(mock_resource, [
            {
                "Items": [_make_context_event_item(id="evt-001")],
                "LastEvaluatedKey": {"id": "evt-001"},
            },
            {
                "Items": [_make_context_event_item(id="evt-002", title="Milestone")],
            },
        ])

        result = query_context_events("TestTable", "baby-001", 7, "us-west-2")

        assert len(result) == 2
        assert mock_table.query.call_count == 2

    @patch("boto3.resource")
    def test_raises_dynamodb_query_error_on_failure(self, mock_resource):
        """Should wrap exceptions in DynamoDBQueryError."""
        mock_table = MagicMock()
        mock_resource.return_value.Table.return_value = mock_table
        mock_table.query.side_effect = Exception("Access denied")

        with pytest.raises(DynamoDBQueryError, match="Failed to query ContextEvent"):
            query_context_events("TestTable", "baby-001", 7, "us-west-2")

    @patch("boto3.resource")
    def test_handles_awsjson_metadata(self, mock_resource):
        """Should parse AWSJSON string metadata into a dict."""
        _mock_boto3_table(mock_resource, {
            "Items": [
                _make_context_event_item(metadata='{"vaccine_type": "DTaP"}'),
            ],
        })

        result = query_context_events("TestTable", "baby-001", 7, "us-west-2")

        assert result[0].metadata == {"vaccine_type": "DTaP"}
