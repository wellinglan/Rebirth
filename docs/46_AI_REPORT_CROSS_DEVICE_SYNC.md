# AI Report Cross-device Synchronization

Sprint 14C adds AI reports to the existing Sync Protocol v2 transport. It is a
manual, account-bound synchronization capability, not an AI generation feature.

## Contract Audit

1. Protocol v2 already carries a typed `table`, record ID, JSON payload,
   server version, origin device, cursor, tombstone, and optimistic concurrency
   control. `ai_reports` is registered as one additional typed table.
2. The only new sync entity is `ai_reports`. `ai_report_versions` is not an
   independently synchronized entity: it is an immutable child collection of
   its report aggregate and travels atomically in the parent payload.
3. Server persistence reuses the existing generic `sync_items` table. No new
   PostgreSQL model or Alembic revision is required because the table already
   persists all Protocol v2 entity tables per cloud user and record ID.
4. A report payload contains its safe report projection and terminal immutable
   versions. It excludes input snapshots, prompts, provider/model runtime
   metadata, API credentials, tokens, usage data, and generation leases.
5. A conflict is resolved at report-aggregate level. Adopting remote replaces
   only the safe projection and appends absent immutable versions; keeping local
   rebases the report against the remote version before a normal v2 push.
6. A tombstone belongs to the report root. Version history is never deleted or
   overwritten as a resolution shortcut.
7. No endpoint was added. Existing `POST /sync/push` and `POST /sync/pull`
   remain the transport; API Version remains 1 and Sync Protocol remains 2.

## Limits And Privacy

- Only completed, failed, or archived reports can be uploaded.
- Draft, pending, and generating report state remains local until terminal.
- Report content is present in the encrypted/account-bound sync payload but is
  never rendered in sync center rows, conflict lists, or diagnostics.
- Report generation, AI usage controls, provider configuration, prompts,
  request IDs, tokens, and AI reports do not gain automatic/background sync.
- Flutter schemaVersion remains 10; the existing report sync columns and
  immutable version-table guards are reused.

## Conflict And Delete Behavior

The app keeps the local aggregate on an OCC conflict and writes a scoped
conflict record. The user can explicitly retrieve the remote version, adopt it,
or keep the local version. Existing version number/ID/content changes are
rejected by the server and adapter. Deleting a report creates a normal v2 root
tombstone; it never deletes historical rows through a conflict action.
