# Journal Cross-device Synchronization

> Sprint: 11B
> Baseline: `3be1632b75a42928d20eb54b804a729c02742936`
> Status: implemented; manual acceptance pending
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

## Scope

Journal joins the existing manual `SyncCoordinator` flow. The implementation
adds no background synchronization, Health/Growth/AI synchronization, account
boundary change, PostgreSQL migration, or new transport endpoint.

## Data Contract

The local Journal UUID is the cross-device record identity. The typed payload
contains the natural date, timezone offset, five optional reflection answers,
draft/completed status, and original creation time. At least one answer must be
present. `today_record_id` is a local association and is never uploaded; pull
rederives it from the active local Today record for the same date.

The existing Journal table already contains `updated_at`, `deleted_at`,
`sync_status`, `server_version`, `last_synced_at`, and `origin_device_id`.
Therefore Flutter schemaVersion remains 8 and no migration is required.

## Push, Pull, And Delete

Local create, edit, and confirmed soft delete set `pending` and the current
installation origin. Push uses Sync Protocol v2 and Server OCC. Server assigns
`server_version`; client timestamps never choose a winner. Acknowledgement
updates only sync metadata in a transaction.

Pull validates the complete typed batch before applying it transactionally.
Malformed payloads, duplicate active dates, local pending changes, and apply
failures do not partially write data and do not advance the Journal cursor.
Deletion is represented by a payload-free tombstone and is never converted to
a physical delete.

## Conflict Recovery

Journal registers an explicit handler in the generic conflict UI:

- **Adopt Remote** persists the request, hydrates and validates the current
  remote snapshot, then transactionally applies the remote upsert or tombstone.
- **Keep Local** rereads current local content, adopts the latest remote OCC
  baseline, marks the row pending, and resolves only after normal push
  acknowledgement.

Same-date independent UUIDs retain both identities as conflict evidence until
the user chooses. There is no automatic winner, field merge, last-write-wins,
cursor reset, or silent conflict deletion. Requested operations remain
retryable after restart.

## Server Runtime

The generic `/sync/push` and `/sync/pull` endpoints now enforce the typed
Journal contract, immutable `entry_date`, one active Journal per user/date,
payload-free tombstones, UUID metadata, and JWT user isolation. Structured
same-date conflicts return `journal_entry_date_conflict` and the remote record
identity.

API version remains 1 and Sync Protocol remains 2. PostgreSQL schema and
Alembic are unchanged. Because validation runs in the API process, deployment
requires publishing and updating the Alpha API image only; PostgreSQL must not
be rebuilt and its volume must not be deleted.

## Product Surface

Settings shows Journal synchronization state, latest successful run time, a
manual Journal action, and the existing shared conflict entry. Journal pages
offer confirmed soft deletion. The generic conflict detail renders typed
Journal summaries and Journal-specific confirmations.

Manual Windows and Android evidence belongs in
`docs/manual_tests/34_journal_cross_device_sync.md`. Automated results must not
be recorded as manual PASS.
