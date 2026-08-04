# AI Report Lifecycle And Conflict Readiness

Sprint 14D exposes the existing archive lifecycle for a completed AI Report.
It is a lifecycle and manual-sync readiness increment, not new AI generation.

## Archive Semantics

`completed -> archived` is explicit and reversible only through future product
work; this sprint does not add unarchive. Archive is not deletion:

- the current report body remains readable;
- all immutable report versions remain readable and unchanged;
- no report version is created, edited, or deleted;
- no provider, prompt, usage control, or AI generation service is called;
- the report aggregate is marked pending for the existing manual AI Report
  sync, where applicable.

The report library continues to display both completed and archived reports.
Only completed reports expose the archive action.

## Sync And Conflict

Archive uses the existing `AiReportSyncAdapter`, `SyncCoordinator`,
`SyncEntityType.aiReport`, and shared conflict center. It is transferred as
safe aggregate status metadata in Sync Protocol 2; automatic sync is not added.

Archive versus delete and archive versus an old local state are ordinary report
aggregate OCC conflicts. A user can retrieve the remote version, adopt remote,
or keep local. Resolution clears the scoped conflict only after the existing
resolution operation succeeds; it neither clears cursors speculatively nor
rewrites historical versions.

The conflict UI may show only report title, period, status, and version count.
It hides report body, version body, prompt, source inputs, provider/model
runtime metadata, credentials, tokens, and secrets.

## Account And Database Boundaries

All report, version, archive, and conflict operations remain bound to the active
local account scope. Account B cannot enumerate Account A report details,
history, archive state, or scoped conflicts.

Flutter schemaVersion is `11`. The v10-to-v11 migration rebuilds the generic
`sync_conflicts` table only so its entity-type CHECK constraint permits
`ai_reports`; it preserves existing rows and re-creates the same indexes. No AI
report business table changes, server database migration, API Version change,
or Sync Protocol change are made.

See `docs/46_AI_REPORT_CROSS_DEVICE_SYNC.md` for the report aggregate transport
contract and `docs/manual_tests/52_ai_report_lifecycle_conflict_readiness.md`
for the release acceptance matrix.
