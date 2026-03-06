# Spec: Data Scientist Agent — DynamoDB Integration

## Status
Done

## Problem
The Data Scientist agent (`src/agent/agents/data_scientist.py`) hardcodes
`generate_mock_physiology_logs()` and `MOCK_CONTEXT_EVENTS` for all cases.
Every eval test case gets the same DTaP-vaccine anomaly data regardless of
the actual question, causing risk level and topic mismatches.

## Solution: Two-Tier Execution

```
data_scientist_node(state)
  ├─ tables configured    →  _run_dynamodb()  (SourceStatus OK)
  │   └─ DynamoDB error   →  _run_fallback()  (SourceStatus FALLBACK)
  └─ no tables configured →  _run_fallback()  (SourceStatus FALLBACK)
```

### Tier 1: DynamoDB
Queries `PhysiologyLog` and `ContextEvent` tables via GSIs using
`boto3.resource` (Table.query). Falls back to fixture data on any error.

### Tier 2: Fallback
Fixture data with `SourceStatusCode.FALLBACK` to signal that real
data was unavailable. Activated when DynamoDB table names are not
configured or when a query fails.

## Config Changes
New fields in `AgentConfig`:
- `physiology_log_table: str = ""` (env: `PHYSIOLOGY_LOG_TABLE`)
- `context_event_table: str = ""` (env: `CONTEXT_EVENT_TABLE`)
- `data_lookback_days: int = 7` (env: `DATA_LOOKBACK_DAYS`)

## DynamoDB Query Module (`src/agent/tools/dynamodb.py`)
- `DynamoDBQueryError` exception class
- `query_physiology_logs(table_name, baby_id, lookback_days, region)` — GSI: `physiologyLogsByBabyIdAndStartTime`
- `query_context_events(table_name, baby_id, lookback_days, region)` — GSI: `contextEventsByBabyIdAndStartDate`
- Lazy `import boto3` inside functions
- Handles DynamoDB pagination via `LastEvaluatedKey`

## Domain Model Change
`ContextEvent.metadata` field validator to handle AWSJSON strings from DynamoDB
(calls `json.loads()` if the value is a string).

## Key Design Decisions
- `boto3.resource` (not client) — `Table.query()` returns plain Python dicts,
  avoiding manual DynamoDB attribute unmarshalling.
- Environment variables for table names — Amplify Gen 2 generates dynamic
  table names that aren't in `amplify_outputs.json`.
- Shared `_analyze()` helper extracts the aggregation/anomaly/correlation
  pipeline so both fallback and DynamoDB paths share it.
- Three pure-Python analysis functions (`_aggregate_daily`, `_detect_anomalies`,
  `_correlate_events`) remain unchanged.
