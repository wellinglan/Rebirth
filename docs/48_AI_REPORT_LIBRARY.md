# AI Report Library Consolidation

Sprint 14E establishes one canonical AI Report Library. It consolidates
product navigation and presentation state; it does not add report generation,
editing, regeneration, automatic sync, or new AI behavior.

## Canonical Navigation

The supported product paths are:

- Settings -> AI Report Library -> report detail -> version history;
- AI Coach -> Local Reports -> Open AI Report Library;
- generation result actions -> the same canonical report detail.

`/ai-reports` and `/ai-reports/:reportId` are the canonical routes. Existing
`/ai-coach/reports/:reportId` deep links redirect to the canonical detail so
old navigation remains safe. AI Coach no longer owns a second report list,
controller, or detail implementation.

## Library Behavior

The library uses the existing account-scoped `AiReportRepository` through the
single `AiReportHistoryController`. It lists completed, failed, archived, and
locally pending lifecycle records and provides lightweight All, Completed,
Archived, and Failed filters.

Each ordinary list row shows only:

- title and report period;
- created and updated time;
- lifecycle status;
- version count;
- safe sync state: synced, pending, or conflict.

The app bar links to the existing manual Sync Center and the AI Report scoped
Conflict Center. These links do not trigger automatic sync.

The existing detail page remains authoritative for report content, immutable
version history, archive, deletion, and pending-request recovery. Archive does
not create or edit a version. Report body editing, unarchive, prompt changes,
and regeneration are not supported.

## Privacy And Account Boundary

The ordinary library list does not render report body, Prompt, AI input,
Provider, model, API state, token, secret, full user ID, internal report UUID,
serverVersion, cursor, or payload. Sync and conflict screens retain their
existing privacy projections.

All list, detail, version, archive, delete, and conflict reads remain scoped to
the active local account. Account switch, logout, and session rejection use
the existing account provider invalidation and authenticated routing gates;
one account cannot retain another account's in-memory report list.

## Technical Boundary

- Flutter schemaVersion remains `11`; there is no Drift migration.
- Server code and PostgreSQL are unchanged.
- API Version remains `1`.
- Sync Protocol remains `2`.
- AI Provider, Usage Ledger, Generation Ledger, prompts, and sync transport are
  unchanged.

See `docs/47_AI_REPORT_LIFECYCLE.md` for archive semantics,
`docs/46_AI_REPORT_CROSS_DEVICE_SYNC.md` for transport semantics, and
`docs/manual_tests/53_ai_report_library_consolidation.md` for manual release
acceptance.

## Acceptance

The Sprint 14E manual matrix closed on 2026-08-04 with 31 PASS, 0 FAIL, and
0 NOT EXECUTED on Windows release and Android arm64-v8a release. Canonical
entry, lifecycle, sync/conflict navigation, account isolation, privacy,
responsive layout, accessibility, Back navigation, and restart behavior were
accepted. The AI Report Library Consolidation release gate is closed.

Sprint 14F builds explicit local export on this canonical library. It adds one
single-report Markdown action and one complete active-account JSON action;
neither action changes lifecycle, versions, sync, conflicts, or AI generation.
See `docs/49_AI_REPORT_SAFE_EXPORT.md`.
