# Rebirth Growth System Foundation

> Sprint: 12B
> Status: implemented; manual product gates closed and accepted
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

## 1. Problem And Goal

The previous Growth implementation read Today, Health, and Journal repositories
directly and merged their domain records in a fixed aggregator. Every future
source would therefore have required another business-repository dependency and
another Growth-specific extraction path.

Sprint 12B rebuilds Growth as the first formal upper-layer consumer of the
Personal Data Aggregation Framework:

```text
PersonalDataProviderRegistry
  -> PersonalDataAggregationEngine
  -> PersonalDataAggregationResult
  -> GrowthProjectionContext
  -> GrowthDimensionContributorRegistry
  -> GrowthProjectionEngine
  -> GrowthProjection
  -> Growth UI
```

Growth remains local, read-only, reproducible derived data. It adds no
persistence, synchronization, server request, or AI behavior.

## 2. Aggregation Boundary

`GrowthRepositoryImpl` now only:

1. creates the current 7-day or 30-day local calendar range;
2. creates a bounded `PersonalDataQuery`;
3. requests daily state, reflection, and wellbeing capabilities from
   `PersonalDataAggregationEngine`;
4. passes the result to `GrowthProjectionEngine`;
5. maps the projection to the existing `GrowthSnapshot` compatibility surface.

It does not import Today, Health, Journal, or Plan repositories and does not
query Drift. Existing Growth controllers and chart widgets can continue to use
`GrowthSnapshot` while the snapshot also carries its source projection.

## 3. Contributor Contract

`GrowthDimensionContributor` is pure Dart. A contributor declares:

- a stable namespaced dimension ID;
- display metadata and deterministic order;
- required personal-data capabilities;
- output sensitivity;
- a deterministic projection function that consumes only
  `PersonalDataAggregationResult` and `GrowthProjectionContext`.

Contributors cannot read repositories or databases, call the network, invoke
sync, or invoke AI. Missing facts stay missing and are never converted to zero.

`GrowthDimensionContributorRegistry` is immutable, rejects duplicate dimension
IDs, sorts deterministically, supports ID and capability lookup, and is assembled
in the Riverpod composition root. The engine does not construct built-in
contributors itself.

## 4. Projection Engine

`GrowthProjectionEngine` invokes contributors independently and validates:

- dimension and metric identity;
- duplicate metric IDs;
- period coverage;
- deterministic ordering;
- sensitivity propagation.

A failed contributor becomes a privacy-safe `GrowthProjectionFailure`; healthy
dimensions remain available. Provider failures and degraded source quality flow
through the aggregation result and contributors as partial or unavailable data.

## 5. Projection, Evidence, And Traceability

Each `GrowthMetricProjection` carries:

- metric ID and dimension ID;
- display name and stable definition;
- time range, current value or raw series, and unit;
- observed, expected, and missing counts;
- quality and sensitivity;
- source provider IDs and capabilities;
- sorted evidence references;
- UTC generation time.

`GrowthEvidence` identifies a safe provider, hashed aggregation item reference,
fact key, local date, quality, and sensitivity. It contains no database object,
complete database UUID, raw JSON, Journal body, Health note, token, User Key,
Endpoint, cloud user ID, or local user ID.

Coverage reports observations rather than performance. Quality never upgrades a
conflicted, stale, partial, or unavailable source to complete. Sensitivity may
be preserved or raised, never lowered.

## 6. Initial Dimensions

### Focus

Uses Today research and learning durations. It preserves minutes, null versus
zero, and period coverage without judging whether a duration is good or bad.

### Recovery

Uses Health sleep and exercise durations. It is always highly sensitive, omits
Health notes and associations, preserves missing values, and makes no medical
interpretation.

### Subjective State

Uses Today mood and energy scores as original 1-5 observations. Missing values
remain distinct from the minimum score. It makes no psychological diagnosis or
directional value judgment.

### Reflection

Uses Journal existence and stable status metadata only:

- `missing`: no active Journal exists for the date;
- `draft`: an active Journal exists with draft status;
- `completed`: an active Journal exists with completed status.

Product wording is consistently `未记录`, `草稿`, and `已完成`.

### Plan Execution

Deferred. The current Plan personal-data contribution is useful for local
overview, but Sprint 12B does not introduce or infer a new execution-rate
definition. A future contributor can be added when reliable typed execution
facts and product semantics are agreed.

## 7. Generic UI And Partial Availability

The Growth page keeps existing charts and adds a generic projection overview.
It iterates descriptors and metrics without a provider-ID business switch.
Unknown future dimensions therefore render with their display metadata,
coverage, quality, sensitivity, and source labels.

One unavailable provider or contributor does not replace the page with a
full-screen error. The affected dimension is partial or unavailable, healthy
dimensions stay visible, and manual refresh remains available.

## 8. Journal State Machine

Journal now has an explicit product lifecycle:

```text
missing
  -> save draft -> draft
  -> complete reflection -> completed
  -> confirm reopen -> draft
```

`missing` is derived and is never persisted. New and draft entries offer
`保存草稿` and `完成复盘`; both require at least one non-empty answer. Completing
saves the current edited content and completed status atomically. Completed
entries are read-only until the user explicitly confirms `重新编辑`.

Repository operations are `saveDraft`, `complete`, and `reopen`. They reuse the
existing Journal write and sync metadata semantics: update `updatedAt`, set
pending status, use the current installation as origin, preserve server version
and existing synchronization metadata where required, and never start sync.

Draft/completed status remains in the existing Journal payload. Cross-device
changes continue through `SyncCoordinator`, OCC, conflict recovery, tombstones,
Adopt Remote, and Keep Local. Concurrent draft/completed edits are not silently
resolved.

Successful Journal mutations invalidate the current Journal state, Personal
Data aggregation, and Growth projection for the active account. Account switch
and logout continue to rebuild account-scoped providers; authenticated-offline
mode remains local and usable.

## 9. Privacy And Non-Goals

- Growth reads no Journal body and no Health note.
- Growth writes no business or derived record.
- No Growth database table, cache, migration, or server endpoint is added.
- No automatic sync, cursor movement, device registration, or account-binding
  mutation is added.
- No LLM, AI recommendation, diagnosis, comparison claim, score, streak, or
  behavior judgment is produced.
- Future AI Context Builder work requires a separate consent and minimization
  design. Sprint 12B only establishes traceable local evidence.

Flutter schemaVersion remains 8. PostgreSQL schema, Alembic, API Version 1,
Sync Protocol 2, and Server runtime are unchanged.

## 10. Future Contributor Checklist

1. Define a stable namespaced dimension ID.
2. Define required capabilities.
3. Define typed metrics and stable definitions.
4. Define expected and observed coverage.
5. Propagate quality.
6. Propagate or raise sensitivity.
7. Build privacy-safe source evidence.
8. Implement the pure-Dart contributor.
9. Register it in the composition root.
10. Add core and failure-isolation tests.
11. Add privacy tests.
12. Add a generic UI test.

Do not modify `GrowthProjectionEngine` for a new contributor.

## 11. Product Gates

Manual acceptance is tracked in
`docs/manual_tests/37_growth_system_foundation.md`.

- Growth System Product Gate: `CLOSED / ACCEPTED`
- Journal State Semantics Gate: `CLOSED / ACCEPTED`
- Account Boundary Isolation Gate: `CLOSED / ACCEPTED`

On 2026-07-29, Windows and Android acceptance passed all 71 safely executable
checks, including Journal lifecycle, cross-device conflict recovery, Growth
source accuracy, privacy, independent-account isolation, 320px layout, maximum
font size, and keyboard operation. Six partial-availability rows remain
`NOT EXECUTED` because no safe product-level Provider or Contributor failure
injection is available; automated tests cover those internal invariants.
