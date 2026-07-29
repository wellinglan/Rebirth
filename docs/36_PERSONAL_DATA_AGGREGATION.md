# Personal Data Aggregation Framework

> Sprint: 12A
> Status: implementation in verification
> Scope: local derived reads only
> Flutter schemaVersion: 8
> API Version: 1
> Sync Protocol: 2

## 1. Goal

Sprint 12A adds an extensible Personal Data Aggregation Framework. Profile,
Plan, Today, Journal, Health, and future modules contribute through one
module-independent provider contract. The framework powers a generic local
overview; it does not implement AI analysis, cloud aggregation, automatic
sync, or a new business source of truth.

## 2. Source Of Truth

Existing local business tables remain the source of truth. Aggregation results
are immutable, derived read results rebuilt for each query. They are not saved
to SQLite, synchronized, uploaded, or written back into any feature.

## 3. Provider Interface

`PersonalDataProvider` exposes only:

- a `PersonalDataProviderDescriptor`;
- declared capabilities;
- `collect(PersonalDataQuery)`.

The interface has no Flutter, Riverpod, Drift, database, `WidgetRef`, user ID,
network, Sync, or AI type. The current local user is injected only by the
trusted Composition Root when concrete adapters are created.

## 4. Descriptor And Provider Identity

Every provider has a stable lowercase namespaced ID, a display name,
description, positive schema version, capabilities, default sensitivity, and
display order. Runtime type and display text are never provider identity.
Descriptors contain no local/cloud user ID, Endpoint, device identity, token,
or binding metadata.

Duplicate provider IDs fail during registry construction. Domain descriptors
contain no `IconData` or `Color`; the generic UI uses a common visual fallback.

## 5. Capability Model

`PersonalDataCapability` wraps a validated extensible namespaced identifier.
Built-ins include identity, timeline, daily summary, goal tracking, daily
state, reflection, and wellbeing metrics. A future provider can introduce
`future.growth_progress` or another namespaced capability without editing the
Engine.

Capabilities support query filtering. They do not grant access, reduce
sensitivity, or replace provider identity.

## 6. Registry

`PersonalDataProviderRegistry` is immutable after construction. It validates
duplicate IDs, supports provider and capability lookup, filters provider
subsets, and returns deterministic order by `displayOrder` then provider ID.
It contains no database, UI, network, or business logic.

The Riverpod Composition Root registers exactly five current adapters for an
authenticated or authenticated-offline local account. Signed-out,
binding-required, and rejected sessions receive an empty account-scoped
registry.

## 7. Query And Time Range

`PersonalDataQuery` contains:

- `[startInclusiveUtc, endExclusiveUtc)`;
- bounded local date coverage;
- local timezone context;
- requested capabilities;
- optional provider filter;
- `localOverview`, `localTimeline`, or `diagnostics` purpose;
- a bounded per-provider item limit;
- an explicit deterministic UTC request time.

Daily queries derive local midnight boundaries without calling
`DateTime.now()`. System-local construction preserves the platform timezone
and DST boundary. Fixed positive and negative offsets are supported for
deterministic tests. Weekly and custom ranges use the same model.

## 8. Contribution, Item, Fact, And Typed Value

An aggregation result contains contributions and privacy-safe provider
failures rather than one five-module object.

Each contribution records provider identity/schema, covered range,
capabilities, sensitivity, quality, items, summary facts, and generated time.
Each item has a protected stable local ID, namespaced kind, title, optional
date/time/interval, typed facts, references, quality, and sensitivity.

Source UUIDs are SHA-256-derived into a short namespaced local identifier and
are never displayed. Facts use validated namespaced keys and deterministic
priority ordering.

`PersonalDataValue` is a sealed typed model supporting text, integer, decimal,
boolean, duration, count, score, date, date-time, percentage, categorical, and
presence values. Absence means no fact, so `null` remains different from `0`
and `false`.

## 9. Quality And Sensitivity

Quality states are `complete`, `partial`, `unavailable`, `unsupported`,
`conflicted`, and `stale`. No record is a valid empty result, not a failure.
Bounded truncation is `partial`; sync-conflicted source rows are
`conflicted`; read exceptions become provider failures.

Sensitivity levels are `standardPrivate`, `sensitive`, and
`highlySensitive`. Contributions, items, and facts cannot lower the provider
default. Profile and Journal are sensitive, Health is highly sensitive, and
Plan/Today are private local data.

## 10. Aggregation Engine

The Engine:

1. selects providers from the registry;
2. invokes them in stable sequence;
3. isolates each exception;
4. validates provider ID, schema, capability, time range, limits, unique item
   IDs/fact keys, and sensitivity;
5. returns deterministic contributions, failures, and a quality summary.

Sequential collection is intentional for the shared local Drift connection.
Asynchronous completion cannot reorder output. A provider failure never hides
healthy providers and never exposes an exception or business body to the UI.

The Engine imports no Profile, Plan, Today, Journal, Health, Flutter, Drift,
Riverpod, Sync, network, or AI module and contains no provider-specific switch.

## 11. Current Providers

### Profile

Reports profile presence, whether user-managed fields are set, and timezone.
It does not expose display name content, growth focus content, Profile/local/
cloud user UUID, User Key, JWT, Endpoint, installation, device, ownership, or
binding metadata.

### Plan

Uses a bounded overlapping date query, excludes tombstones, preserves goal
hierarchy facts without exposing parent UUIDs, and reports level, state,
archive state, dates, counts, and conflict quality. It generates no judgment
about incomplete goals.

### Today

Reads existing rows only. It never calls `getToday()` or another get-or-create
path and never creates a placeholder. It reports priority counts, stored
scores, durations, and record status while omitting Daily note text and all
Health fields. Nullable durations remain absent while zero is emitted as zero.

### Journal

The database query selects only Journal metadata columns. Contribution items
contain date, status, count, timestamps, and conflict quality. Journal body
columns, Markdown, and answer text are neither loaded into the contribution
nor logged or displayed.

### Health

Health is independent of Today and can aggregate when no Today row exists. It
reports stored structural metrics and source category, preserves nullable
metrics, and is always highly sensitive. It omits Health note,
`today_record_id`, source record identity, medical interpretation, risk
assessment, and advice.

## 12. Generic Local Overview

The Settings entry opens `/personal-data`, which remains behind the existing
Auth Gate. The page uses only the Aggregation Controller, Engine, and Registry.
It supports previous day, next day, today, and manual refresh.

Contribution, item, and fact renderers are generic. They contain no provider
ID switch. Unknown providers and capabilities use safe fallbacks. Highly
sensitive contributions are collapsed by sensitivity policy, not by a Health
special case. Raw JSON, complete UUIDs, credentials, Endpoint, AI suggestions,
and Journal bodies are never rendered.

The controller protects against duplicate same-date requests, stale
out-of-order completion, updates after disposal, and account invalidation.
Manual refresh is the current write-to-overview update mechanism; no broad
feature rewrite or automatic table listener was added.

## 13. Account Scope And Offline Behavior

The Composition Root takes `localUserId` only from an authenticated
`AppAuthState`. Each concrete query applies that user scope. Logout and account
boundary changes invalidate the registry and controller. A previous account's
result is not retained.

`authenticatedOffline` can aggregate because collection uses only local
SQLite. Collection does not probe an Endpoint, refresh JWT, register a device,
push, pull, advance a cursor, or modify account binding.

## 14. Privacy And AI Boundary

Local aggregation is not AI consent. Results are not sent to Server, AI
providers, logs, crash payloads, analytics, or documentation. No AI code is
called and no recommendation, emotion judgment, health judgment, prediction,
Daily Insight, or Weekly Report is generated.

A future AI layer must request an explicitly authorized capability subset and
apply a separate purpose/sensitivity consent policy. It must not consume the
entire aggregation result merely because local aggregation is enabled.

## 15. Determinism And Performance

Providers use explicit ordering and `limit + 1` bounded reads. The extra row
detects truncation without loading unlimited history. Contributions sort by
descriptor order and provider ID; items sort by time/date, display order, and
protected ID; facts sort by display priority and fact key.

No aggregation cache, background retry, network dependency, or N+1
cross-feature read was introduced.

## 16. Future Module Integration Checklist

1. Define a stable provider ID.
2. Define namespaced capabilities.
3. Implement `PersonalDataProvider`.
4. Output typed contributions.
5. Mark sensitivity and quality.
6. Register the provider in the Composition Root.
7. Add a provider test.
8. Add a privacy test.
9. Add a generic UI integration test.

Do not modify the Aggregation Engine, Aggregation Result, existing providers,
or generic UI switch. The automated `FakeGrowthPersonalDataProvider` evidence
proves that registration alone participates in Engine filtering and generic
rendering.

## 17. Persistence, Sync, Server, And Version Impact

- No Drift table or migration.
- Flutter schemaVersion remains 8.
- No PostgreSQL schema change.
- No Alembic revision.
- No Sync entity, adapter, cursor, conflict, push, pull, or protocol change.
- API Version remains 1.
- Sync Protocol remains 2.
- No Server runtime change.
- No Alpha deployment is required.

## 18. Current Limits

- The page is a framework-validation local overview, not Growth or AI insight.
- Writes in other features require manual overview refresh.
- Historical timezone boundaries use the device timezone database available to
  Dart; no independent IANA timezone package was added.
- Provider failure is normally covered by automated injection because safely
  forcing a real local database provider failure is not a product operation.
- Aggregation results are intentionally not cached or persisted.

## 19. Growth Consumer

Sprint 12B establishes Growth as the first formal upper-layer consumer of this
framework. Growth creates a bounded multi-day query, requests daily-state,
reflection, and wellbeing capabilities, and passes the unchanged aggregation
result to an independent contributor registry and projection engine.

Growth does not copy provider extraction logic, read business repositories, or
add persistence. Provider failures remain structured partial input and are
isolated again at the contributor boundary. The Personal Data Engine and
generic overview require no provider-specific change.

See `docs/37_GROWTH_SYSTEM_FOUNDATION.md`.

## 20. Manual Gate

Manual acceptance is tracked in
`docs/manual_tests/36_personal_data_aggregation.md`. On 2026-07-29, all 49
safely executable checks passed on Windows and Android. The five provider
failure checks remain `NOT EXECUTED` because no safe product operation can
force a local provider failure; automated fault-injection evidence covers
those internal invariants. The Personal Data Aggregation Product Gate and
Account Boundary Isolation Gate are `CLOSED / ACCEPTED`.

## Sprint 12C Journal Prompt Privacy

Personal Data Aggregation continues to select Journal metadata only. It does
not read `journal_prompt_definitions` or `journal_entry_prompt_items`, and it
does not expose prompt text, helper text, response text, UUIDs, or configuration
payloads. Schema 9 does not change contributor output or consent semantics.
