# Rebirth Growth Analytics

> Status: Sprint 12B extensible foundation implemented
> Scope: local read-only 7-day and 30-day projections
> Product gates: CLOSED / ACCEPTED on 2026-07-29

## Product Positioning

Growth helps the user inspect factual patterns in focus, recovery, subjective
state, and reflection without judging the result. It does not calculate a
growth score, streak, reward, causal conclusion, diagnosis, action advice, or
fabricated previous-period comparison.

Sprint 12B replaces the fixed business-repository aggregation introduced by the
Growth MVP with a contributor-based projection layer above the Personal Data
Aggregation Framework.

## Current Architecture

```text
GrowthPage
  -> GrowthController
  -> GrowthRepository
  -> PersonalDataAggregationEngine
  -> GrowthProjectionEngine
  -> GrowthDimensionContributorRegistry
  -> GrowthProjection
  -> GrowthSnapshot compatibility mapper
```

Growth no longer imports or reads Today, Health, Journal, or Plan repositories,
and it does not query Drift. The compatibility mapper preserves the existing
summary, chart, and daily-detail surfaces while `GrowthSnapshot` also carries
the traceable projection.

The pure-Dart contributor contract, immutable registry, projection validation,
safe evidence, coverage, quality, sensitivity, initial dimensions, partial
failure behavior, privacy rules, and future contributor checklist are defined
in `docs/37_GROWTH_SYSTEM_FOUNDATION.md`.

## Period And Controller Semantics

The only supported periods remain:

- `GrowthPeriod.sevenDays`: seven local calendar days, selected by default.
- `GrowthPeriod.thirtyDays`: thirty local calendar days.

Each inclusive range ends on the current local calendar date. Range endpoints
are constructed as local calendar boundaries rather than by adding 24-hour
durations, avoiding daylight-saving drift.

`GrowthController` retains initial loading, period switching, manual refresh,
non-blocking refresh error, request sequencing, and duplicate suppression.
Growth stays available in authenticated-offline mode and is rebuilt for account
changes or logout through the existing account-scoped providers.

## Dimensions And Sources

| Dimension | Typed source facts | Sensitivity |
|---|---|---|
| Focus | Today research and learning duration | private |
| Recovery | Health sleep and exercise duration | highly sensitive |
| Subjective State | Today mood and energy | private |
| Reflection | Journal existence and draft/completed status | private |

Plan Execution is deferred until the product has stable, reliable typed
execution facts. Growth does not infer an execution rate from plan counts.

## Missing Values, Zero, And Status

`null` means not recorded; explicit `0` remains a real observation. Missing
values do not enter totals or averages and remain gaps in charts. Each metric
reports observed, expected, and missing counts.

Reflection uses exactly:

- `未记录`
- `草稿`
- `已完成`

The ambiguous old `已记录` status is no longer used. Journal text itself never
enters Growth.

## Projection Overview And Existing Charts

The page retains:

1. header, period selector, refresh action, and local date range;
2. objective summary metrics;
3. focus, recovery, and subjective-state charts;
4. Journal status coverage;
5. collapsed read-only daily details.

It also renders a generic projection overview containing dimension metadata,
coverage, quality, sensitivity, and source labels. The widget iterates unknown
future dimensions without a provider-ID switch. A provider or contributor
failure affects only its dimension; healthy dimensions remain visible.

Charts show observations only. Text legends, semantics, and daily details keep
the content understandable without relying on color. Existing responsive
coverage spans 320-1200px and TextScaler 2.0.

## Evidence And Privacy

Growth Evidence retains a safe provider reference, hashed item reference, fact
key, local date, quality, and sensitivity. It exposes no complete database UUID,
raw JSON, account identifier, credential, Endpoint, Journal body, or Health
note.

Recovery is highly sensitive and has no medical interpretation. Subjective
State has no psychological interpretation. Evidence remains local and is not
uploaded or given to AI.

## Persistence, Sync, Network, And AI

Growth remains reproducible derived data. There is no Growth table, cache,
migration, write action, API request, cursor, sync entity, automatic sync, or
AI call.

Flutter schemaVersion remains 8. API Version remains 1, Sync Protocol remains
2, and PostgreSQL schema, Alembic, and Server runtime are unchanged.

Future AI Context Builder and real AI Coach work must use separate consent,
minimization, and safety design. Sprint 12B does not implement either.
