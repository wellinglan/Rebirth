# Today Cross-device Synchronization

> Sprint: 11A
> Baseline: `d0dc5f83f2bb33c37402ba3d1805182e5030a590`
> Status: implemented; local automated verification passed; manual gate open
> API: 1
> Sync Protocol: 2
> Flutter schema: 8 after Sprint 11A.1

## Scope

Sprint 11A adds Today to the existing Sync Foundation. It reuses the shared
`SyncCoordinator`, entity adapter registry, optimistic concurrency control,
per-entity cursor, generic conflict records, device registration, account
binding, and sync eligibility checks.

Synchronization remains manual. Profile, Plan, and Today are supported.
Journal, Health, Growth, AI reports, and AI consent remain local and are not
added to the wire contract.

## Local Model

`TodayRecord` remains the local source of Today business data. Its UUID is the
cross-device record identity and `record_date` is the natural date identity
within one account. Existing sync metadata supplies `sync_status`,
`server_version`, `last_synced_at`, `updated_at`, and `deleted_at`.

The synchronized payload contains:

- record date and timezone offset;
- three priority texts, completion flags, and optional Goal IDs;
- mood and energy scores;
- research and learning minutes;
- daily note;
- record status;
- creation time.

The payload does not contain `user_id`, sync metadata, device identity, or any
`HealthRecord` field. Health stays device-local. Applying a remote Today
transaction updates only the Today row and therefore preserves an existing
same-day Health aggregate.

## Canonical Payload

`TodaySyncPayload` is strongly typed. `TodaySyncPayloadCodec` validates the
complete field set and serializes keys in stable lexical order. The canonical
JSON is used for SHA-256 fingerprints and generic conflict snapshots.

Validation rejects invalid natural dates, timezone offsets outside
`-840..840`, scores outside `1..5`, negative minute values, malformed Goal
UUIDs, and inconsistent empty priorities. `null` and integer `0` are distinct
through encode, decode, persistence, and cross-device tests.

Tombstones carry no business payload.

## Adapter And Coordinator

`TodaySyncAdapter`:

1. collects pending upserts and tombstones for the active local user;
2. skips a blank `local_only` Today row created only by opening the page;
3. encodes and decodes only typed Today payloads;
4. acknowledges accepted server versions without changing business fields;
5. applies a validated remote batch in one Drift transaction;
6. records stale or competing local state in the shared `SyncConflict` store;
7. never advances a cursor itself.

The Coordinator performs the account guard before adapter, cursor, or network
work. Today has its own `today_records` cursor. Profile and Plan cursors are
not read, reset, or advanced by a Today run. A pull cursor advances only after
the entire remote Today batch applies successfully.

Opening Today may create a blank same-date placeholder before the first pull.
The adapter may replace that placeholder with the cloud UUID only when it is
still blank, `local_only`, unsynced, and has no linked Health row. Content,
sync history, and Health prevent replacement.

Optional priority Goal IDs must refer to an active Goal for the current local
user. If a referenced Goal is missing, remote apply fails transactionally and
the cursor does not advance. In manual cross-device testing, synchronize Plan
before Today when priorities contain Goal links.

## Conflict And Date Rules

The first version is local-first:

- a stale push creates a generic Today conflict;
- pending local content is not overwritten by pull;
- a nonblank local row with the same date but a different UUID is protected;
- no field-level merge or automatic last-write-wins is performed;
- Today conflict details were initially read-only.

Sprint 11A.1 adds explicit delete, remote snapshot hydration, adopt remote,
keep local, tombstone resolution, and same-date identity reconciliation. See
`docs/32_TODAY_CONFLICT_RECOVERY.md` for the current behavior.

The Server validates one active Today record per natural date for each JWT
user and treats `record_date` as immutable for a record UUID. Independent
same-date creation with different UUIDs is rejected instead of silently
merged. The user must retain the local evidence until a later explicit
resolution workflow is implemented.

## Server Contract

The generic `/sync/push` and `/sync/pull` endpoints remain unchanged. The JWT
is the only source of cloud user identity; clients cannot submit `user_id`.
Today payloads are strictly validated before write. OCC remains
`client_version == server_version`, and client `updated_at` never decides the
winner. Duplicate accepted pushes are idempotent.

Today continues to use the generic PostgreSQL `sync_items` store. No
PostgreSQL model, table, index, Alembic revision, API version, or Sync Protocol
version changed.

## UI And Provider Lifecycle

Settings now shows a manual Today sync action and the states idle, syncing,
success, conflict, and failed. Busy state prevents duplicate requests. A
successful run reloads Today and invalidates Today history. Account change,
logout, and re-login invalidate Today sync state through the existing account
scope invalidator.

There is no automatic startup, background, periodic, or real-time sync.

## Deployment And Gate

The Server runtime changed, so the Alpha API image must be republished and the
Beijing API container updated to the exact Sprint commit tag. Reuse the
existing PostgreSQL container and volume. Do not rebuild PostgreSQL, delete
the volume, or clear cursors.

Automated checks do not replace the Windows and Android matrix in
`docs/manual_tests/32_today_cross_device_sync.md`. The exercised matrix now
records `44 PASS / 0 FAIL / 8 NOT EXECUTED`. The gate remains open with partial
acceptance because the remaining rows require unsupported operations or
fixtures that were not available.

The 32 matrix remains immutable Sprint 11A evidence at
`44 PASS / 0 FAIL / 8 NOT EXECUTED`. Remaining product paths move to
`docs/manual_tests/33_today_conflict_recovery.md`; automated evidence does not
rewrite historical manual results.

## Local Verification

Executed on 2026-07-28:

| Check | Result |
|---|---|
| Flutter analyzer | PASS, no issues |
| Flutter tests | PASS, `921 passed / 2 skipped` |
| Server tests | PASS, `154 passed / 9 skipped` |
| Windows release build | PASS |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter schemaVersion | unchanged at `7` |
| PostgreSQL schema and Alembic | unchanged |
| API / Sync Protocol | unchanged at `1 / 2` |
| Manual Today matrix | PARTIAL, `44 PASS / 0 FAIL / 8 NOT EXECUTED` |

Android build retains the existing non-blocking CupertinoIcons asset warning.
