# Rebirth Growth Analytics

> Status: Sprint 7B Growth UI MVP  
> Scope: local read-only aggregation and visualization for 7-day and 30-day snapshots

## Product Positioning

Growth is Rebirth's trend analysis module. It helps the user inspect research,
learning, health, mood, energy, and reflection patterns without judging the
result. The page uses neutral, factual summaries and does not calculate a
growth score, streak, reward, previous-period comparison, or AI conclusion.

Sprint 7A established the Domain/Data foundation. Sprint 7B adds the read-only
controller and Material 3 presentation layer while retaining the same data
semantics.

## Architecture Boundary

```text
GrowthPage
  -> GrowthController
  -> GrowthRepository
  -> TodayRepository.listByDateRange
  -> HealthRepository.listByDateRange
  -> JournalRepository.listByDateRange
  -> GrowthAggregator
  -> GrowthSnapshot
```

Growth remains a derived-data module. The page never accesses a Repository,
Drift, or `AppDatabase` directly. The controller has only the read operation
defined by `GrowthRepository`. Presentation mappers convert domain days into
plain chart models; `fl_chart` types are confined to presentation widgets.

No Growth table, cache, migration, write action, API request, or sync item is
introduced. Flutter `schemaVersion` remains 3.

## Period And Controller Semantics

The only supported periods are:

- `GrowthPeriod.sevenDays`: 7 local calendar days, selected by default.
- `GrowthPeriod.thirtyDays`: 30 local calendar days.

Each inclusive range ends on the current local calendar day and is generated
by `DateTimeService.recentLocalDateRange`. Saved historical local dates are not
rewritten for the current timezone.

`GrowthController` provides initial loading, period switching, reload, and
error states. A request sequence guards every refresh. If the user switches
periods rapidly, only the newest request may replace the state. Existing data
stays visible during refresh. A refresh failure retains the last successful
snapshot and displays a non-blocking message; an initial failure uses the full
error state and retry action.

## Complete Date Skeleton

Aggregation always starts with every date in the requested period. A 7-day
snapshot has exactly 7 ascending `GrowthDaySnapshot` values and a 30-day
snapshot has exactly 30. Missing Today, Health, or Journal records do not remove
a date.

The Sprint 7A aggregator remains the single owner of aggregation. It indexes
Repository results by saved local date and merges them into the skeleton in
approximately O(N) time. Invalid dates, negative durations, invalid scores, or
ambiguous duplicate records raise `GrowthDataIntegrityException`.

## Metric Sources

| Growth metric | Source |
|---|---|
| `researchMinutes` | `TodayEntry.researchMinutes` |
| `learningMinutes` | `TodayEntry.learningMinutes` |
| `moodScore` | `TodayEntry.moodScore` |
| `energyScore` | `TodayEntry.energyScore` |
| `sleepMinutes` | `HealthEntry.sleepDurationMinutes` |
| `exerciseMinutes` | `HealthEntry.exerciseDurationMinutes` |
| `journalRecorded` | `JournalEntry.hasContent` |
| `journalCompleted` | `hasContent && status == completed` |

Health metrics are read only from `HealthRepository`; the embedded Today health
summary is not a second Growth source.

## Missing Values And Zero

`null` means the metric was not recorded. `0` means the user explicitly recorded
zero. Growth preserves the distinction end to end:

- Presentation models retain nullable integer values.
- A line-series `null` becomes an `FlSpot.nullSpot`, producing a gap.
- A missing exercise value has no bar rod.
- An explicit zero remains a point or bar at the baseline.
- Tooltips and summaries do not invent values for missing data.

A completely missing series displays a local empty message rather than a fake
all-zero chart.

## Summary Rules

Only non-null values participate in summaries. Explicit zero counts as a
recorded day and is included in the denominator. The UI presents:

- Research total duration.
- Learning total duration.
- Exercise total duration.
- Average sleep duration.
- Average Mood score.
- Average Energy score.
- Journal recorded days out of the selected period.

Durations are formatted without unnecessary decimals. Score averages use one
decimal place on the original 1-5 scale. Missing summaries display `暂无数据`.

## Growth Page

The Material 3 page is a constrained `ListView` using `AppLayout.pagePadding`
and `AppLayout.wideContentWidth`. It contains:

1. Header, 7/30-day segmented selector, and formatted date range.
2. Responsive seven-metric summary grid.
3. Research and Learning dual line chart.
4. Independent Sleep line chart and Exercise bar chart.
5. Mood and Energy dual line chart on the 1-5 scale.
6. Journal coverage cells for missing, recorded draft, and completed days.

On narrow screens summary cards wrap to one or two columns and recovery charts
stack vertically. On wider Windows content they use three or four summary
columns and the recovery charts may sit side by side. Thirty-day charts retain
all 30 points but label only the first, last, and representative intermediate
dates.

Series are differentiated by text legends and line styles in addition to
color. Period controls expose selected semantics, summary cards expose their
label and value, charts expose objective aggregate descriptions, and each
Journal cell exposes its date and state.

## Empty And Partial States

A snapshot is completely empty only when all six numeric summaries have
`recordedDayCount == 0` and `journalRecordedDays == 0`. The page then keeps the
header, period selector, date range, and a calm empty-state card.

If any metric is recorded, the full page structure remains available. Populated
sections render normally and each wholly missing chart uses its own local empty
message. Missing Journal data does not hide other trends, and missing Health
data does not hide Today trends.

## Persistence, Sync, Network, And AI

`GrowthSnapshot` is reproducible local derived data. It is not persisted,
cached, uploaded, or synchronized. Loading Growth requires no server, Docker,
FastAPI, login, or network connection. Profile sync behavior is unchanged.

Sprint 7B has no previous-period comparison, streak, growth score, medical
interpretation, AI explanation, or cloud synchronization. A future AI Coach
may consume a snapshot only after explicit authorization and data-sharing
design; it must not mutate source facts.
