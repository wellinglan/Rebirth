# Today Conflict Recovery

> Sprint: 11A.1
> Baseline: `86f0f3ce35e44582374ae1b4863bd2c5f965e7e6`
> Status: implemented; automated and manual gates tracked separately
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

## Scope

Sprint 11A.1 closes the Today synchronization product loop without adding
Journal, Health, Growth, or AI synchronization. Synchronization remains
manual and reuses `SyncCoordinator`, account guards, per-entity cursors,
strict OCC, and the generic `/sync/push` and `/sync/pull` endpoints.

After the Today product gate closes, the next feature Sprint is
`Sprint 11B - Journal Cross-device Synchronization`.

## Delete And Health

Today exposes confirmed soft deletion from the current page and history.
Deletion sets one UTC timestamp for `deleted_at` and `updated_at`, marks the
row `pending`, and records the current installation origin. Business fields,
`server_version`, and `last_synced_at` remain for tombstone upload and
diagnosis. No sync starts automatically, and an unresolved conflict cannot be
bypassed by direct deletion.

A blank `local_only` placeholder created after deletion is not uploaded, while
the older tombstone remains collectable. Saving again creates a new local
identity rather than silently reviving the synchronized tombstone.

Health remains local-only. Delete, remote tombstone, adopt, and keep-local do
not change Health business fields or sync metadata. Identity reconciliation
may update only `health_records.today_record_id` in the same transaction.

## Conflict And Remote Identity

The state machine covers same-UUID edits, local edit versus remote tombstone,
local tombstone versus remote edit, dual tombstones, stale push, pending-local
pull, and same-date independent UUID creation. There is no field merge,
automatic winner, last-write-wins, or background retry.

Flutter schema 8 adds nullable `sync_conflicts.remote_record_id`.
`record_id` remains the captured local identity; `remote_record_id` stores the
actual cloud identity. It is not embedded in payload JSON or device metadata.
The v7 to v8 migration is additive and existing rows receive `NULL`.

The Server returns structured `today_record_date_conflict` responses with the
remote identity and OCC baseline. This is additive under API 1 and Sync
Protocol 2. PostgreSQL schema and Alembic do not change.

## Hydration

A stale push initially persists `awaiting_remote_snapshot`. Explicit
hydration uses `SyncPullMode.preferRemoteConflictResolution`, requesting
Today from server version zero without clearing the persisted incremental
cursor. It stores only a validated current remote snapshot and identity, then
moves awaiting to unresolved. It does not apply business content, resolve the
conflict, or report ordinary sync success.

## Adopt Remote

Confirmation first persists `adopt_remote_requested` without changing Today
or cursor state. A conflict-mode pull fetches the Server current version,
validates payload and Goal references, and applies it transactionally.

For different UUIDs, the remote UUID becomes canonical. The old local
identity becomes inactive only after confirmation, Health is reconnected,
and the conflict becomes `resolved_adopt_remote`. The conflict history keeps
the abandoned local snapshot. Failure leaves the requested state retryable
after restart.

## Keep Local

Confirmation rereads current local content, applies the latest remote OCC
baseline, sets `pending`, current UTC `updated_at`, current installation
origin, and `keep_local_requested` in one transaction. The following
push-only run resolves the conflict only after acknowledgement.

For different UUIDs, current local content moves to `remote_record_id` and
Health is reconnected. The old local UUID remains inactive history and is not
uploaded as a fabricated cloud tombstone. Network failure leaves durable
pending/requested state; a later cloud change can form a new real conflict.

## Cursor, Replay, And Handler Registry

Adapters never read or write cursors. The Coordinator advances the Today
cursor only after a complete legal apply. Conflict, malformed Goal reference,
transaction failure, and hydration-only work do not advance it. Profile and
Plan cursors remain outside Today runs.

`SyncConflictDetailPage` now uses
`SyncConflictResolutionHandlerRegistry`. Plan and Today register explicit
handlers for hydration, adopt, keep-local, and retry. An unregistered entity
is read-only and never falls back to Plan. Handlers do not receive
`BuildContext`, access Drift, show SnackBars, call HTTP directly, or touch
cursors.

Journal and Health can later register handlers without rewriting the generic
detail page. Neither is synchronized in this Sprint.

## Gates

Product-visible checks belong to
`docs/manual_tests/33_today_conflict_recovery.md`. On 2026-07-28, the Windows
and Android release-client matrix passed all `51 / 51` checks. Internal cursor,
rollback, guard, and replay invariants belong to
`docs/test_evidence/11a1_today_conflict_recovery.md` as automated evidence.

The Today Sync Product Gate is `CLOSED / ACCEPTED` with no remaining product
release blocker. The broader Account Boundary Isolation Gate remains
`CONDITIONAL ACCEPTED` because a second independent Endpoint is unavailable.
