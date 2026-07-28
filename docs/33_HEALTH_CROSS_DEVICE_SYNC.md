# Health Cross-device Synchronization

> Sprint: 11C
> Baseline: `d6ac3166f90638582495864da77cf8076a799fd6`
> Status: implemented; manual acceptance pending
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

## Scope

Health joins the existing manual `SyncCoordinator` flow. The implementation
adds no automatic or background synchronization, Growth/AI synchronization,
account-boundary change, PostgreSQL migration, Alembic revision, or new
transport endpoint.

## Ownership And Data Contract

The active local account owns each Health record. Its UUID is the
cross-device identity and `record_date` is the immutable natural-date
identity. The strict payload contains the timezone offset, nullable health
metrics, optional note, source metadata, and original creation time.

`today_record_id` is a local weak association. It is not uploaded. Pull may
rederive it from an active local Today record for the same account and date,
but Health can be created, synchronized, retained, and resolved without a
Today row.

The existing Health table already contains `updated_at`, `deleted_at`,
`sync_status`, `server_version`, `last_synced_at`, and `origin_device_id`.
Flutter schemaVersion therefore remains 8 and no migration is required.

## Push, Pull, And Tombstones

Local Health create, edit, and confirmed soft delete set `pending` and the
current installation origin. Push uses Sync Protocol v2 and Server OCC. The
Server assigns `server_version`; client timestamps never select a winner.
Acknowledgement updates sync metadata transactionally without rewriting
health content.

Pull validates the complete typed batch before applying it in one local
transaction. Invalid payloads, duplicate active dates, cross-account record
IDs, local pending changes, and apply failures cannot partially write Health
rows. The Coordinator advances the Health cursor only after successful apply.

Delete uses a payload-free tombstone. No Health synchronization path performs
a physical delete. Deleting or changing Today neither deletes nor uploads
Health.

## Conflict Recovery

Health registers with the generic conflict handler registry:

- **Adopt Remote** persists the request, validates and hydrates the current
  remote snapshot, then applies the remote upsert or tombstone transactionally.
- **Keep Local** rereads current local Health, adopts the latest remote OCC
  baseline, marks it pending, and resolves through the normal push path.

Same-date records with different UUIDs remain explicit conflicts until the
user chooses. There is no automatic merge, last-write-wins, cursor reset, or
silent conflict deletion. Requested operations remain durable and retryable
after restart.

## Server Runtime

The existing `/sync/push` and `/sync/pull` endpoints now validate typed Health
payloads, UUID metadata, immutable `record_date`, one active Health row per
JWT user/date, payload-free tombstones, and user isolation. Same-date identity
conflicts return `health_record_date_conflict` with the remote record identity.

API version remains 1 and Sync Protocol remains 2. PostgreSQL schema and
Alembic are unchanged. Because the API runtime changed, Alpha deployment
requires publishing and updating only the API container. PostgreSQL must not
be rebuilt and its volume must not be deleted.

## Privacy And AI Boundary

Health is sensitive personal data. Application logs, conflict lists, and
documentation must not contain health payloads, metric values, notes, tokens,
full private endpoints, or private identifiers. The conflict UI shows only
the date, record source/type, deletion state, version state, and a message
that health details are hidden.

Sprint 11C does not expose Health to AI Coach, AI Reports, Growth, or any new
analytics pipeline.

## Product Surface

Settings shows Health synchronization state, latest successful run time,
manual synchronization action, and the shared conflict entry. Health pages
offer confirmed soft deletion. Manual Windows and Android evidence belongs in
`docs/manual_tests/35_health_cross_device_sync.md`; automated verification
must not be recorded as manual PASS.
