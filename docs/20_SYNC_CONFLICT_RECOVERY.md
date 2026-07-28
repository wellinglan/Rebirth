# Persistent Sync Conflict Recovery

> Sprint: 10B.1
> Scope: Flutter-local generic conflict store; Plan resolution only
> Status: implementation and Quality passed; manual acceptance blocked by cross-account local data ownership
> Flutter schemaVersion: 4

## Why Goal.syncStatus Is Not Enough

`Goal.syncStatus = conflict` protects the current local row from overwrite, but
does not preserve the server payload, server tombstone, remote version,
Endpoint, cloud user, or a crash-recoverable resolution request. Changing that
flag back to `pending` or `synced` without those facts can lose local edits,
apply an obsolete server version, break hierarchy, or advance the cursor
incorrectly.

Sprint 10B.1 therefore keeps the Goal flag as the business-row guard and adds a
separate persistent conflict record as the recovery state machine.

## Local Schema

The generic `sync_conflicts` table contains:

```text
id
local_user_id
endpoint_key
cloud_user_id
entity_type
record_id
local_payload_json
local_updated_at
local_deleted_at
local_server_version
local_origin_device_id
remote_payload_json
remote_operation
remote_updated_at
remote_deleted_at
remote_server_version
remote_origin_device_id
detected_at
last_seen_at
resolution_status
resolved_at
```

`remote_operation` is `upsert`, `delete`, or `unknown_pending_pull`.
Resolution states are:

```text
unresolved
awaiting_remote_snapshot
adopt_remote_requested
keep_local_requested
resolved_adopt_remote
resolved_keep_local
superseded
```

Indexes support local-user/status ordering, Endpoint/cloud-user/entity lookup,
entity/record lookup, and one unresolved row per
Endpoint/cloud-user/entity/record. Resolved rows remain historical; there is no
product delete or cleanup action in this Sprint.

## Identity And Privacy Boundaries

Every query is scoped by:

1. active local Profile UUID;
2. normalized current Endpoint;
3. cloud user ID from the Endpoint-bound JWT session;
4. entity type;
5. record ID.

Logout hides but does not delete rows. Re-login to the same Endpoint and cloud
user restores them. Endpoint or Development User Key changes cannot mix
conflict threads.

The UI never displays the full Endpoint, cloud user ID, record UUID, raw JSON,
token, database path, or secret.

## Snapshot Contract

Plan snapshots use the same `PlanSyncPayload` and
`PlanSyncPayloadCodec` as transport:

```text
parent_goal_id
title
description
goal_level
status
start_date
target_date
completed_at
archived_at
sort_order
created_at
```

Key order is stable and nullable keys remain present. Payloads contain no local
owner, `sync_status`, `last_synced_at`, Endpoint, token, cursor, filter, or
breadcrumb state. A tombstone has no fabricated payload and keeps its deletion
timestamp separately.

The stored local snapshot describes detection time. If the user edits the Goal
afterward, details compare it with the current typed local content and say that
the local version changed. Keep-local always rereads current content.

## Pull Conflict Persistence

When a higher remote version meets a local Goal that is not `synced`, the Plan
adapter performs one Drift transaction:

1. preserve all local business fields;
2. mark the Goal `conflict`;
3. save local and remote typed snapshots;
4. save operation, versions, timestamps, origin, Endpoint, cloud user, and
   local user;
5. update `last_seen_at` idempotently on replay.

If any item conflicts, no otherwise-applicable business row from the pull page
is applied. The Coordinator receives a conflict result and does not advance the
Plan cursor. A higher replay updates the remote snapshot; an older replay
cannot replace it.

## Push Conflict Hydration

The Protocol v2 push conflict response has no remote payload. A true stale
response therefore creates `awaiting_remote_snapshot` with the known remote
server version and `remote_operation = unknown_pending_pull`.
`request_conflict` collateral items do not create fake conflict rows.

After the two-way run reports a Plan conflict, the controller performs at most
one controlled Plan pull-only run through the existing `SyncCoordinator`.
Success fills the current remote upsert or tombstone and moves the row to
`unresolved`. Failure preserves the Goal and awaiting row; the user can retry.

## Adopt Server Current Version

Adopt is available only when the remote snapshot is complete. Confirmation
persists `adopt_remote_requested` before network access, without changing the
Goal. The subsequent Plan pull:

1. accepts the latest legal server change for that requested record;
2. updates the stored remote snapshot if the server version increased;
3. validates the whole projected parent graph;
4. applies parent-first upserts or child-first tombstones transactionally;
5. updates Goal sync metadata;
6. marks the conflict `resolved_adopt_remote`;
7. allows cursor advancement only after the transaction succeeds.

Network, payload, orphan, or cycle failure leaves the local Goal unchanged and
the request retryable.

## Keep Current Local Version

Keep-local starts with one local transaction:

1. reread the current Goal;
2. retain all current business fields and `deleted_at`;
3. set `server_version` to the conflict remote baseline;
4. set `sync_status = pending`;
5. set current UTC `updated_at` and local installation origin;
6. preserve `last_synced_at`;
7. persist `keep_local_requested`.

The normal Plan push then uses strict optimistic concurrency. A successful
acknowledgement marks both Goal and conflict resolved. Network failure leaves
the Goal pending and request retryable. A new stale response updates the
remote baseline, returns to awaiting hydration, and never starts an infinite
automatic retry.

## Crash And Replay

All local preparation and resolution transitions are durable. Restart after a
request transaction resumes from the requested status. Restart after server
success but before acknowledgement may resend the same canonical operation;
server idempotency and strict version checks make that safe. Restart after
local apply but before cursor persistence replays the page, and local server
versions make it idempotent.

The unsafe order is never used: the cursor is not saved before local apply.

## Hierarchy And Tombstones

Adopt uses the existing projected hierarchy validator. Orphans and cycles roll
back Goal and conflict updates. Remote tombstones can be adopted as soft
deletes. Current local tombstones can be retained and uploaded with the remote
version baseline. No hard delete is introduced.

## Migration

The Flutter migration is `v3 -> v4`. It creates `sync_conflicts` and indexes
without rebuilding or clearing business tables. Existing Goal UUIDs,
`sync_status`, `server_version`, local cursor data, Today, Journal, Health,
Profile, and AI Report rows remain.

An existing Goal already marked `conflict` has no reconstructable remote
snapshot. Migration preserves that status and does not fabricate a conflict
row. The next manual Plan pull can create and hydrate a real row.

## Current Limits

- Plan uses the generic persistent conflict store and details page.
- Profile uses its local sync status plus explicit `保留本地 Profile` and
  `采用云端 Profile` recovery actions added by Sprint 10B.3.1; it does not
  create generic Plan conflict rows.
- Today, Journal, Health, Growth, and AI Report do not sync.
- There is no field-level merge, last-write-wins, background retry, realtime
  push, or conflict-history cleanup.
- Server runtime, API version 1, Sync Protocol v2, PostgreSQL, and Alembic are
  unchanged.
- Sprint 10B Alpha deployment was confirmed on 2026-07-26.
- Automated tests do not close the Windows/Android/cross-device release gate.

Sprint 10C should not start until
`PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001` is corrected and the affected recovery
and account-isolation rows are rerun.

## Local Verification

Executed on 2026-07-25:

| Check | Result |
|---|---|
| Flutter analyzer | PASS, no issues |
| Targeted conflict and regression tests | PASS, `167 passed` |
| Full Flutter suite | PASS, `827 passed / 2 skipped` |
| Server non-PostgreSQL pytest | PASS, `139 passed / 1 skipped / 8 deselected` |
| Windows release build | PASS |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| PostgreSQL marker | NOT EXECUTED locally; PASS in GitHub Quality |
| Manual acceptance | NOT EXECUTED |

No test connected to the Alpha business database. Local success does not prove
deployment or device acceptance.

## GitHub Verification

- Implementation commit:
  `ba6cfc472ca2312aebcf5c5880ebebaa8040c333`
- Quality run: `30155446531`, PASS
- Server SQLite: PASS
- Server PostgreSQL Multiprocess And Multiworker: PASS
- Alembic upgrade: PASS
- PostgreSQL marker: PASS
- Multi-worker verification: PASS
- Flutter Analyze And Test: PASS
- Android Debug Build: PASS
- Publish Alpha Images: NOT RUN for this Flutter/docs-only implementation
- Sprint 10B Alpha deployment: PASS on 2026-07-26
- Windows, Android, and cross-device manual acceptance: IN PROGRESS
- Release Gate: OPEN, blocked by
  `PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001`

## Manual Discovery: Cross-account Awaiting Conflict

The manual matrix produced one conflict from an old local Goal that had
previously synchronized under Development User Key A. After the same
installation registered User Key B, deleting that Goal submitted A's nonzero
`serverVersion` in B's cloud scope. Strict OCC rejected the stale version, but
B had no remote record for a later pull to hydrate.

The conflict store safely preserved the local tombstone and correctly scoped
the conflict row to B. However, retry left the conflict count at one, retained
`awaiting_remote_snapshot`, showed no remote summary, exposed no adopt/keep
actions, and still displayed a success message. The app remained navigable and
no unrelated Plan row was overwritten or duplicated.

This is an upstream local data ownership defect, not evidence that conflict
row scoping should be weakened. The complete evaluation is in
`docs/21_CLOUD_ACCOUNT_LOCAL_DATA_ISOLATION.md`; recorded device evidence and
matrix status are in `docs/manual_tests/25_plan_cross_device_sync.md` and
`docs/manual_tests/26_sync_conflict_recovery.md`.

Profile re-entry remediation is documented separately in
`docs/24_LEGACY_SYNC_REENTRY_REMEDIATION.md`.

## Sprint 11A.1 Today Conflict Recovery

Today joins Plan in the persistent generic conflict center. Conflict actions
are dispatched by an explicit handler registry instead of a Plan controller
hard-coded in the detail page. Plan behavior remains registered and
unchanged; unregistered entities stay read-only.

Today persists local `record_id` and nullable `remote_record_id`. Hydration
and adopt use pull-only conflict mode from server version zero without
clearing the normal cursor. Keep-local prepares the remote OCC baseline
transactionally and uses push-only. Same-date different UUIDs converge to the
cloud UUID only after user confirmation. Health business fields and sync
metadata remain local and unchanged.

See `docs/32_TODAY_CONFLICT_RECOVERY.md` and
`docs/manual_tests/33_today_conflict_recovery.md`. Journal and Health conflict
handlers are not implemented in this Sprint.

## Sprint 11C Health Conflict Recovery

Health is registered in the generic conflict handler registry. Adopt Remote
persists an explicit request and then uses conflict-mode pull to validate and
apply the current remote upsert or tombstone. Keep Local rereads the current
Health row, adopts the remote OCC baseline, marks it pending, and continues
through the normal push path.

Same-date different UUID records keep local and remote identities until the
user chooses. Requested operations survive restart and remain retryable.
There is no automatic merge, last-write-wins, cursor reset, hard delete, or
silent resolution.

Conflict list and detail presentation deliberately omit Health metrics and
notes. They show only date, source/type, operation and synchronization state.
Today rows and Today conflicts are outside every Health resolution
transaction.
