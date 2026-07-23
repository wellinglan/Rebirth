# Daily Insight Freshness

## Status

Sprint 9C code implementation is in progress. Automated verification does not replace the Windows and Android manual matrices in `docs/manual_tests/23_daily_insight_freshness.md`.

## Goal

Completed Daily Insight reports derive a live freshness state by rebuilding the report's original local-date input with its original selected scopes:

```text
stored Daily report metadata
→ existing Daily bundle assembler
→ existing canonical JSON and SHA-256 hash
→ compare with stored inputHash
→ Current / Stale / Unavailable
```

Weekly reports do not participate.

## States

- **Current**: the rebuilt current input hash equals the report's stored hash.
- **Stale**: the hashes differ. The old report remains a valid historical conclusion.
- **Unavailable**: the comparison cannot be trusted, including missing legacy metadata, invalid hashes, unsupported contract versions, or source read/build failures.

Unknown states never default to Current. Complete hashes and canonical payloads are not shown in the freshness UI or logs.

## Hash And Scope Semantics

Freshness calls `AiCoachInputAssembler.buildDailyInsight`; it does not implement another canonical encoder or hash algorithm. This preserves:

- Today, Health, and Journal scope selection;
- selected-missing scopes as empty arrays;
- explicit `0` versus `null`;
- Journal confirmation and inclusion semantics;
- `AiInputContract.schemaVersion` and `daily-insight-v1`;
- source normalization and SHA-256 behavior.

Only originally selected scopes are rebuilt. Changes in unselected scopes do not affect freshness. Adding a record to a selected-missing scope, deleting a selected record, or changing `null` to `0` changes the canonical input and therefore produces Stale under the current bundle contract.

## Rebuild Metadata

No database column or schema version was added. New reports store a versioned metadata envelope in the existing `ai_reports.input_sources_json` text column:

- metadata version;
- input schema version;
- original selected scopes;
- source references.

The repository continues to read the legacy source-reference array. Legacy reports without recoverable scopes are displayed as Unavailable rather than guessed Current.

## Stale To Preview

The Stale detail action opens the existing Daily Preview flow with the report's original local date and selected scopes. The latest local preview is rebuilt automatically. Remote generation still requires the existing explicit final confirmation.

- Opening Detail never sends a generation request.
- Cancelling confirmation creates no pending report, Binding, or POST.
- A confirmed refresh creates a new local report.
- The stale historical report is retained and is never overwritten or deleted.
- A successfully completed refreshed report evaluates as Current.

Freshness recalculates when detail opens, when the page is re-entered, and after returning from exact-date Today or Journal source navigation. It uses no polling or background listeners.

## UI

Daily Detail shows a lightweight status card near the top:

- `与当前记录一致`
- `当前记录已发生变化`
- `暂时无法确认`

Weekly Detail has no freshness card. The layout is covered at 320 px, 360 px, and `TextScaler 2.0`.

## Database And Cloud Impact

- Flutter changes: yes.
- SQLite schema version: unchanged at `3`.
- Server/API contract changes: none.
- Alembic/PostgreSQL changes: none.
- Database backup: not required for this change.
- API GHCR image or cloud Compose update: not required.
- Endpoint changes: none.
- Cloud remains Development + Fake Provider + Tailscale private Alpha, not Production.

Windows and Android release clients must be rebuilt for manual acceptance.

## Automated Coverage

Coverage includes service status rules, scope isolation, selected-missing, null/zero, invalid and legacy metadata, Provider refresh/disposal/re-entry, status UI, explicit Preview/confirmation behavior, historical-report retention, and responsive layouts. Existing AI Coach regression tests continue to cover Daily manual generation, reusable reports, source integrity, Binding-before-POST, recovery, mixed History, source navigation, and soft delete.

## Known Limitations

- Legacy reports that predate selected-scope metadata cannot be reliably reconstructed and remain Unavailable.
- Freshness is local and derived on demand; it is not synchronized or persisted.
- There is no continuous database listener. A visible detail refreshes after source navigation or when re-entered.
- Manual Windows and Android acceptance remains required.
