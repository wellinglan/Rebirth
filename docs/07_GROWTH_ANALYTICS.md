# Rebirth Growth Analytics

> Status: Sprint 7A Domain/Data Foundation  
> Scope: local read-only aggregation for 7-day and 30-day snapshots

## Product Positioning

Growth is Rebirth's trend analysis module. It helps the user understand whether
research, learning, health, mood, energy, and reflection patterns are changing
over time. The data should support understanding rather than judge performance
or decorate the interface.

Sprint 7A implements only the Domain/Data foundation. `GrowthPage` remains a
placeholder. Charts, period controls, loading/error states, and other UI belong
to Sprint 7B.

## Architecture Boundary

Growth is a read-only derived-data module:

```text
GrowthRepository
  -> TodayRepository.listByDateRange
  -> HealthRepository.listByDateRange
  -> JournalRepository.listByDateRange
  -> GrowthAggregator
  -> GrowthSnapshot
```

`GrowthRepositoryImpl` does not access Drift, `AppDatabase`, a local data
source, `ApiClient`, or a server API. Each underlying Repository is queried once
per load. The three range queries start together, and any failure is propagated
without returning a partial snapshot.

## Period Semantics

The public periods are deliberately limited to:

- `GrowthPeriod.sevenDays`: 7 local calendar days.
- `GrowthPeriod.thirtyDays`: 30 local calendar days.

The range is inclusive and ends on the current local calendar day. For example,
if today is `2026-07-16`, the 7-day range is `2026-07-10` through `2026-07-16`,
and the 30-day range is `2026-06-17` through `2026-07-16`.

`DateTimeService.recentLocalDateRange` is the only range generator. It handles
month, year, and leap-year boundaries without replacing local calendar dates
with UTC dates. Output is always ordered from the earliest date to the latest.
Saved historical `recordDate` and `entryDate` values are never rewritten for
the current timezone.

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

Health metrics are read only from `HealthRepository`. Growth does not read the
embedded `TodayEntry.health` summary, avoiding two business sources for the same
metric. Weight, water intake, exercise type, physical state, and Health notes
are outside Sprint 7A.

## Complete Date Skeleton

Aggregation begins with every date in the requested period. A 7-day snapshot
always contains 7 `GrowthDaySnapshot` values, and a 30-day snapshot always
contains 30. Missing Today, Health, or Journal records do not remove a date.

The aggregator indexes each Repository result by its saved local date and then
merges it into the skeleton in approximately O(N) time. Records with valid dates
outside the requested range are ignored. Duplicate in-range Today or Health
dates, duplicate Journals with actual content, invalid dates, negative minutes,
and scores outside 1-5 raise `GrowthDataIntegrityException` instead of being
silently corrected.

## Missing Values And Zero

`null` means the user did not record that metric. `0` means the user explicitly
recorded zero. Growth preserves both states:

- A missing Today record produces `researchMinutes = null`.
- A Today record with `researchMinutes = 0` produces `researchMinutes = 0`.

No missing numeric metric is filled with zero. This distinction is retained in
daily snapshots and all summaries.

## Summary Rules

Each duration or score summary contains:

- `recordedDayCount`
- `total`
- `average`
- `minimum`
- `maximum`

Only non-null values participate. An explicit zero counts as a recorded day and
is included in the average denominator. When all values are missing,
`recordedDayCount` and `total` are zero while `average`, `minimum`, and `maximum`
remain null. Durations stay in integer minutes; score averages may be `double`.
The Domain layer does not format minutes as hours or produce localized text.

`journalRecordedDays` counts days with actual Journal content.
`journalCompletedDays` counts content-bearing entries whose status is
`completed`. An empty Journal is not recorded, even if its status is completed.
Sprint 7A does not calculate a current streak, longest streak, completion-rate
judgment, or growth score.

## Persistence, Sync, And Network

`GrowthSnapshot` is reproducible derived data, not a new fact source. It is not
stored in SQLite, cached, uploaded, or synchronized. Sprint 7A adds no Drift
table or migration and keeps Flutter `schemaVersion` at 3.

Growth does not change `sync_status`, Profile sync, `SyncCursorStore`, Server,
FastAPI, Docker, PostgreSQL, or Android networking. Loading Growth requires no
network connection.

## Future Consumers

Sprint 7B may add a lightweight Growth UI that reads `GrowthSnapshot`, switches
between the two supported periods, and renders charts that clarify the data.
It should not introduce write actions, streak rewards, growth scores, or value
judgments.

A future AI Coach may consume a `GrowthSnapshot` as read-only structured input
after explicit data-sharing design and authorization. It must not mutate the
snapshot or use AI output to overwrite Today, Health, or Journal facts. Sprint
7A contains no AI calls or conclusions.
