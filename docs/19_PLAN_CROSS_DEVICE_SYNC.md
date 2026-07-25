# Plan Cross-device Sync

> Sprint: 10B
> Status: Sprint 10B pushed and Quality-verified; Alpha deployment and manual acceptance pending
> API: version 1
> Sync protocol: version 2

## Scope

Sprint 10B adds manual Plan synchronization to the existing Sync Foundation.
It reuses the configured Endpoint, Development session, Device Registration,
`SyncCoordinator`, `/sync/push`, `/sync/pull`, and the
Endpoint/user/scope-bound cursor store.

Implemented product scope:

- Profile remains manually pushable and pullable.
- Plan has one manual two-way action in Settings.
- Today, Journal, Health, Growth, and AI Reports are not synchronized.
- There is no startup, timer, background, or realtime synchronization.

## Identity And Ownership

Each local Goal UUID is its stable cross-device cloud record ID. Pulling a new
Goal uses that UUID locally, and `parent_goal_id` references the same UUID.
There is no second cloud-only Goal ID.

The Server ignores local ownership as a trust boundary. It derives cloud
ownership only from the bearer JWT. A pulled Goal is inserted under the current
active local Profile ID. Neither payloads nor responses can replace that local
owner.

## Typed Payload

An active Goal payload contains:

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

Transport fields remain outside the payload:

```text
record id
updated_at
deleted_at
origin_device_id
client_version
server_version
```

Tombstones use an empty payload plus `deleted_at`. The payload never contains
local `user_id`, `sync_status`, `last_synced_at`, Endpoint, token, database
path, filter state, or breadcrumbs.

## Strict Optimistic Concurrency

The Server no longer lets client timestamps decide stale writes.

- A cloud-new record requires `client_version == 0`.
- An existing record update requires
  `client_version == existing.server_version`.
- A mismatched version returns `stale_client`, even when client
  `updated_at` is equal to or newer than the cloud value.
- Conflict responses include the current version but no cloud business
  payload.

An exact retry is idempotent when canonical payload JSON, `updated_at`,
`deleted_at`, and `origin_device_id` match the stored record. It returns the
existing version without changing `server_updated_at` or advancing
`sync_clock`.

Push is request-atomic. Duplicate keys, versions, Plan payloads, projected
hierarchy, and tombstone effects are checked before any server version is
allocated. Any real conflict rejects all new writes in that request and does
not advance `sync_clock`. Valid-but-collateral records use
`request_conflict`; they remain pending locally.

## Hierarchy Rules

The Server and Flutter adapter both validate:

- Goal and parent IDs are UUIDs;
- a Goal cannot parent itself;
- every active parent exists locally/cloud-side or in the same batch;
- the projected active graph has no cycle;
- tombstones cannot leave active children pointing at deleted parents.

Pending active Goals are uploaded parent before child. Pending tombstones are
uploaded child before parent. Ties use `sort_order`, `created_at`, and UUID for
stable ordering.

Pull validates the complete page before business writes. It then applies new
parents before children in one Drift transaction. A payload error, orphan,
cycle, or conflict prevents other business changes in the page and prevents
cursor advancement.

## Local Metadata

Create keeps:

```text
sync_status = local_only
server_version = null
last_synced_at = null
origin_device_id = local installation ID
```

Edit, reparent, status, completion, archive, restore, and soft delete set
`sync_status = pending`, update `updated_at`, and set the current installation
as origin while preserving `server_version` and `last_synced_at`.

Archive/restore and soft delete update an entire subtree in one Drift
transaction. Soft delete remains a queryable tombstone and never hard-deletes
the Goal.

Accepted acknowledgements are validated against the exact submitted ID set and
applied transactionally. Accepted rows become `synced`; stale conflicts become
`conflict`; collateral `request_conflict` rows remain pending.

## Pull And Replay

- A higher-version remote upsert inserts or updates a synced Goal.
- A same/older version is ignored as an idempotent replay.
- A higher remote version never overwrites `local_only`, `pending`, or
  `conflict` content.
- A missing remote tombstone stays row-free.
- A synced local row receives a remote tombstone without hard deletion.
- Plan cursor advancement happens only after the entire local apply succeeds.
- Profile and Plan cursors remain separate scopes.

## Persistent Conflict Recovery

Sprint 10B.1 preserves conflicting local content, marks explicit conflict
state, persists typed snapshots, shows an endpoint/user-scoped inbox, and
leaves the Plan cursor unchanged. It does not choose a winner by device time
or perform field-level merge.

Pull conflicts save local and remote snapshots in the same Drift transaction
that marks the Goal `conflict`. If one item conflicts, no other business change
from that page is applied and the cursor does not advance.

Push conflict responses contain only the current server version. The client
therefore saves `awaiting_remote_snapshot` without inventing a payload, then
runs one controlled Plan pull-only hydration. Failed hydration keeps the local
Goal and requested state for a user-triggered retry.

Resolution is explicit:

- Adopt server current version persists `adopt_remote_requested`, keeps the
  local Goal unchanged before network access, validates the complete projected
  hierarchy, then applies the latest pull version and resolves transactionally.
- Keep current local version rereads the current Goal, uses the conflict's
  remote version as the strict client baseline, marks the Goal pending, and
  resolves only after server acknowledgement.

Both paths support upserts and tombstones. Network failure, process restart,
and cursor replay retain a recoverable requested state. Resolved rows remain as
history; a later higher-version conflict creates a new active row.

## Database And Deployment

- Flutter `schemaVersion` is `4`.
- Drift migration `v3 -> v4` adds only the local generic `sync_conflicts`
  table and its indexes.
- No Alembic revision was added.
- No PostgreSQL schema or dedicated Goal table was added.
- SyncItem remains the cloud storage model.
- API version remains `1`.
- Sync Protocol remains `2`.

Sprint 10B server behavior was published in implementation commit
`713f46a71ab5aa46be45ae62051a366859ab9a39`; Quality run `30148891653` and
Publish Alpha Images run `30148891659` passed. The matching API image exists,
but deployment to the Beijing Alpha server is still pending confirmation.

Sprint 10B.1 changes only Flutter local storage and client behavior. It does
not require a new API image, API container recreation, PostgreSQL rebuild,
Compose change, Endpoint change, or Alembic migration.

Manual acceptance is defined in
`docs/manual_tests/25_plan_cross_device_sync.md` and persistent recovery
acceptance in `docs/manual_tests/26_sync_conflict_recovery.md`. Both remain
separate from automated results.
