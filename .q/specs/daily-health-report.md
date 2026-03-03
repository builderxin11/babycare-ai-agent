# Spec: Daily Health Report (P1)

## Status
MVP Complete (Phase 1)

## Problem
The current system is **pull-only** — parents must ask a question to get advice. Parents want proactive insights: "How did my baby do today?" without having to formulate a question. The system has all the data (PhysiologyLog, ContextEvent) but only analyzes it when explicitly queried.

## Solution: Push-Model Daily Report

A scheduled or event-triggered job that:
1. Queries the day's data for each baby
2. Runs the existing multi-agent pipeline (without a parent question)
3. Generates a structured `DailyReport`
4. Stores the report in DynamoDB for parent review

```
┌─────────────────────────────────────────────────────────────────┐
│                    Daily Report Pipeline                        │
│                                                                 │
│  Trigger (9 PM / data threshold)                               │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────┐                                                │
│  │ Report      │  For each baby with today's data:             │
│  │ Generator   │  - Query PhysiologyLog (today)                │
│  │             │  - Query ContextEvent (today)                 │
│  │             │  - Query 7-day baseline                       │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐  Self-generated question:                     │
│  │ Data        │  "Summarize {baby_name}'s health for today    │
│  │ Scientist   │   based on the logged data"                   │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐  Interprets trends, assigns health status     │
│  │ Medical     │  (healthy / monitor / concern)                │
│  │ Expert      │                                                │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐  Safety review (no HITL for daily reports)    │
│  │ Critique    │  Auto-approve if score >= 4                   │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐  Store to DynamoDB, optionally push notify    │
│  │ Report      │                                                │
│  │ Writer      │                                                │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Data Model

### New DynamoDB Table: `DailyReport`

```typescript
// amplify/data/resource.ts
DailyReport: a.model({
  babyId: a.id().required(),
  reportDate: a.date().required(),  // YYYY-MM-DD

  // Health assessment
  healthStatus: a.enum(['HEALTHY', 'MONITOR', 'CONCERN']),
  confidenceScore: a.float(),

  // Report content
  summary: a.string(),           // 2-3 sentence overview
  observations: a.string().array(),  // Key observations list
  trendComparison: a.enum(['IMPROVING', 'STABLE', 'DECLINING']),
  actionItems: a.string().array(),   // Actionable tips
  warnings: a.string().array(),      // Flags for pediatrician attention

  // Data snapshot
  dataSnapshot: a.json(),        // Raw aggregates for that day
  baselineSnapshot: a.json(),    // 7-day baseline used for comparison

  // Metadata
  generatedAt: a.datetime(),
  agentVersion: a.string(),

  // Authorization
  familyOwners: a.string().array(),
})
.secondaryIndexes(index => [
  index('babyId').sortKeys(['reportDate']).queryField('reportsByBabyAndDate'),
])
.authorization(allow => [
  allow.ownerDefinedIn('familyOwners'),
]),
```

### New Pydantic Model: `DailyReport`

```python
# src/agent/models/outputs.py

class HealthStatus(str, Enum):
    HEALTHY = "healthy"
    MONITOR = "monitor"
    CONCERN = "concern"

class TrendDirection(str, Enum):
    IMPROVING = "improving"
    STABLE = "stable"
    DECLINING = "declining"

class DailyReport(BaseModel):
    """Automated daily health report for a baby."""

    baby_id: str
    baby_name: str
    report_date: date

    # Assessment
    health_status: HealthStatus
    confidence_score: float = Field(ge=0.0, le=1.0)
    trend_direction: TrendDirection

    # Content
    summary: str = Field(description="2-3 sentence health overview")
    observations: list[str] = Field(description="Key observations from today's data")
    action_items: list[str] = Field(description="Actionable tips for parents")
    warnings: list[str] = Field(default_factory=list, description="Flags requiring attention")

    # Citations
    citations: list[Citation] = Field(default_factory=list)

    # Data context
    data_snapshot: dict[str, Any] = Field(description="Today's aggregated data")
    baseline_snapshot: dict[str, Any] = Field(description="7-day baseline for comparison")

    # Metadata
    generated_at: datetime = Field(default_factory=datetime.utcnow)
```

## Implementation Plan

### Phase 1: Report Generator Module

**File:** `src/agent/report/generator.py`

```python
def generate_daily_report(baby_id: str, baby_name: str, baby_age_months: int) -> DailyReport:
    """Generate a daily health report for a single baby.

    1. Query today's PhysiologyLog and ContextEvent
    2. Query 7-day baseline data
    3. Self-generate a question for the agent pipeline
    4. Run the graph (Data Scientist → Medical Expert → Critique)
    5. Transform ParentingAdvice into DailyReport format
    """
```

Key differences from `/ask` flow:
- **No parent question** — generate synthetic question from data
- **No Social Researcher** — skip XHS cross-check for daily reports (too slow, not relevant)
- **No HITL interrupt** — auto-approve all daily reports (reviewed by Critique only)
- **Different output model** — `DailyReport` instead of `ParentingAdvice`

### Phase 2: Modified Graph for Report Mode

**Option A: Conditional routing in existing graph**
- Add `report_mode: bool` to `AgentState`
- Supervisor skips Social Researcher when `report_mode=True`
- Synthesize outputs `DailyReport` instead of `ParentingAdvice`

**Option B: Separate lightweight graph** (Recommended)
- New graph in `src/agent/graph/report_builder.py`
- Nodes: `data_scientist → medical_expert → critique → report_writer`
- Simpler routing, no supervisor loop needed
- Reuses existing agent node implementations

### Phase 3: Trigger Mechanisms

**3a. Scheduled Trigger (Lambda / EventBridge)**
```python
# src/report/scheduler.py
def daily_report_job():
    """Run nightly at 9 PM for all babies with today's data."""
    babies = list_babies_with_todays_data()
    for baby in babies:
        report = generate_daily_report(baby.id, baby.name, baby.age_months)
        save_report_to_dynamodb(report)
        # Optional: send push notification
```

**3b. API Endpoint (Manual trigger)**
```python
# src/api/server.py
@app.post("/report/{baby_id}")
async def generate_report(baby_id: str) -> DailyReportResponse:
    """Manually trigger daily report generation."""
```

**3c. Data Threshold Trigger (Future)**
- Trigger when N new PhysiologyLog entries are added
- Requires DynamoDB Streams + Lambda

### Phase 4: Frontend Display

**New page:** `/baby/[id]/reports`
- List of historical daily reports
- Click to expand full report
- Health status badges (green/yellow/red)

**Dashboard integration:**
- Show latest report summary on baby card
- "New report available" indicator

## Prompt Template

```python
DAILY_REPORT_QUESTION_TEMPLATE = """\
Based on {baby_name}'s logged data for {report_date}, provide a daily health summary.

Today's data:
{data_summary}

7-day baseline:
{baseline_summary}

Analyze:
1. How does today compare to the baseline?
2. Are there any concerning patterns?
3. What actionable tips can help the parents?
"""
```

## Config Changes

```python
# src/agent/config.py
daily_report_hour: int = 21  # 9 PM local time
daily_report_min_logs: int = 3  # Minimum logs to generate report
skip_social_for_reports: bool = True  # Skip XHS for daily reports
```

## Test Plan

### Unit Tests
- `test_daily_report_model.py` — Pydantic model validation
- `test_report_generator.py` — Report generation with mock data
- `test_report_graph.py` — Graph structure and routing

### Integration Tests
- Generate report with real DynamoDB data
- Verify report stored correctly
- Verify health status mapping (anomalies → MONITOR/CONCERN)

### Eval Extension
- Add 2-3 daily report scenarios to `gold_dataset.json`
- Scoring: Safety, Accuracy, Actionability

## Rollout Plan

1. **MVP (Week 1)**
   - Manual API endpoint `/report/{baby_id}`
   - Basic report generation (no scheduling)
   - Store to DynamoDB

2. **Scheduled Reports (Week 2)**
   - EventBridge rule for nightly trigger
   - Lambda function to process all babies

3. **Frontend (Week 3)**
   - Reports list page
   - Dashboard integration

4. **Notifications (Future)**
   - Push notification when report is ready
   - Email digest option

## Open Questions

1. **Should daily reports include Social Researcher?**
   - Pro: More complete picture
   - Con: Slower, XHS results may not be relevant for daily summaries
   - **Recommendation:** Skip for MVP, add as optional flag later

2. **How to handle babies with no data today?**
   - Option A: Skip report generation
   - Option B: Generate "no data" report with reminder
   - **Recommendation:** Option A for MVP

3. **Report retention policy?**
   - Keep all reports forever?
   - Auto-delete after 90 days?
   - **Recommendation:** Keep all for MVP, add TTL later if storage costs matter

4. **Timezone handling?**
   - Use UTC or baby's local timezone?
   - **Recommendation:** Store UTC, display in user's timezone
