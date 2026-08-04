# AI Report Safe Export And Data Portability Foundation

Sprint 14F adds explicit, local export to the canonical AI Report Library. It
does not add import, restore, backup scheduling, cloud export, report editing,
regeneration, or any new AI behavior.

## Product Flow

The supported entry points are:

- AI Report detail -> Export current report -> Markdown;
- AI Report Library -> Export all reports -> JSON.

Both flows show a sensitive-data warning before opening the platform save
dialog. The user chooses the destination. Saving, cancellation, and failure do
not update the report, immutable versions, lifecycle status, sync status,
server version, cursor, tombstone, or conflicts. Export never starts AI
generation or manual sync.

## Architecture

The export path is:

```text
Widget
  -> AiReportExportController
  -> AiReportExportService
  -> account-scoped AiReportRepository reads
  -> Export DTO and encoder
  -> AiReportFileExportAdapter
  -> platform save dialog
```

Widgets neither query Drift nor write files. `AiReportExportService` checks the
authenticated local account before reading and again immediately before
opening the save dialog. Each report must belong to that same active account.
Logout, session rejection, or an account switch therefore stops the export
before file saving.

`PlatformAiReportExportAdapter` uses Android's native document save flow and
the Windows native save-location picker. It accepts UTF-8 bytes and returns
only saved or cancelled; no chosen path is retained in application state or
shown in an error message.

## Portable DTO

The export DTO is independent of Drift rows and contains only:

- title and report type;
- period start and end dates;
- lifecycle status;
- created and completed UTC timestamps;
- current report content;
- ordered immutable versions with version number, status, timestamps, and
  content.

Versions are exported in ascending version order. Nullable content and
completion timestamps remain JSON `null`; they are not replaced with guessed
values.

## Markdown Format

A single report uses UTF-8 Markdown format `1.0`. Its suggested file name is
derived only from the report period:

```text
rebirth-ai-report-YYYY-MM-DD.md
rebirth-ai-report-YYYY-MM-DD-to-YYYY-MM-DD.md
```

The document contains a metadata summary, current content, and version
history. The title is inside the file but is intentionally excluded from the
suggested file name.

## JSON Format

The complete active-account export is a UTF-8 JSON document:

```json
{
  "format_version": "1.0",
  "exported_at": "2026-08-05T01:02:03.000Z",
  "reports": []
}
```

The suggested name is `rebirth-ai-reports-YYYY-MM-DD.json`. Object keys and
the `1.0` format version are stable. A future incompatible format must use a
new version. Sprint 14F does not implement import, so this contract is a
portability foundation rather than a restore promise.

## Privacy Boundary

Report bodies are intentionally exportable because the user explicitly chose
the action and destination. The following are never mapped into an export:

- local/cloud user IDs, device IDs, report/version UUIDs, and source IDs;
- prompts, prompt versions, input hashes, input snapshots, and source scopes;
- provider, model, generation source, model metadata, and structured output;
- token, secret, Authorization, endpoint, request ledger, and usage ledger;
- sync status, server version, cursor, conflict payload, and tombstone data.

Failures use controlled UI messages and do not log file contents, private
paths, credentials, or internal exceptions.

## Technical Boundary

- Flutter schemaVersion remains `11`; there is no Drift migration.
- Server, PostgreSQL, and Alembic are unchanged.
- API Version remains `1`.
- Sync Protocol remains `2`.
- AI Provider, Generation Ledger, Usage Ledger, prompts, and sync transport are
  unchanged.

Manual release acceptance is tracked in
`docs/manual_tests/54_ai_report_safe_export.md`.
