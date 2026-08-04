# AI Report Persistence Foundation

## Scope

Sprint 14B establishes AI Report as a local, versioned domain aggregate. It
adds persistence, lifecycle rules, account isolation, and read-only history UI.
It does not add automatic generation, chat, agents, tool calling, or editable
AI conclusions. Sprint 14C subsequently adds manual cross-device report sync;
see `docs/46_AI_REPORT_CROSS_DEVICE_SYNC.md`.

## Aggregate And Version Model

`ai_reports` remains the single report aggregate table. Schema 10 adds a title,
generation source, sensitivity, quality, and current version projection. The
existing generation request fields remain compatible with Daily Insight and
Weekly Report recovery.

`ai_report_versions` is append-only and contains terminal generation results:

- report ID and positive version number;
- completed or failed status;
- generation source and non-secret model metadata;
- report content or a controlled error code;
- sensitivity, quality, and timestamps.

The unique `(report_id, version)` key and SQLite update/delete guards make old
versions immutable. A new result creates the next version. The aggregate's
current content fields are a compatibility projection, not the historical
source of truth.

Schema 9 completed and failed reports migrate to version 1. Draft or pending
records remain without a fabricated version.

## Lifecycle

The report lifecycle is explicit:

```text
draft -> generating -> completed
                    -> failed

completed -> generating  (create a new version)
failed    -> generating   (retry into a new version)
draft/completed/failed -> archived
```

The legacy `pending` state remains only for existing remote request recovery
and may terminate as completed or failed. Completed content cannot transition
directly to another completed state and cannot overwrite a stored version.
Archived reports are terminal.

## Generation Boundary

`AiReportGenerationService` is a provider-neutral future boundary. Sprint 14B
includes only a deterministic local `FakeAiReportGenerationService` for tests.
The AI Report library contains no generation button and never calls a Provider.
Existing explicit AI Coach generation is not expanded by this Sprint.

## Privacy And Account Boundary

Report content is highly sensitive local data:

- every query is scoped through the active local profile;
- account A cannot list, open, or enumerate account B report versions;
- logout retains local rows, while the Router Auth Gate blocks access;
- session rejection cannot reach the protected report routes;
- report content is not consumed by Growth or Personal Data Aggregation;
- report content is not written into Journal or ordinary logs;
- reports synchronize only through the explicit Sprint 14C `ai_reports`
  aggregate adapter; versions remain immutable children and are never separate
  sync records;
- UI never displays API keys, tokens, prompts, Provider secrets, raw model
  metadata, or full internal IDs.

## UI

Settings exposes a separate `AI 报告` destination. It provides a local-only
list, empty/loading/error states, report details, lifecycle status, and version
history. The screen is read-only, Material 3, and designed for Windows,
Android, 320 px width, and TextScaler 2.0.

## Database And Compatibility

- Flutter schemaVersion: `11` after Sprint 14D extends the generic conflict
  table constraint to persist scoped `ai_reports` conflicts. The AI report and
  immutable version tables themselves are unchanged.
- New local table: `ai_report_versions`.
- PostgreSQL/Alembic: unchanged.
- API Version: `1`.
- Sync Protocol: `2`.
- AI Report cross-device sync: manual aggregate sync supported from Sprint 14C.
- Automatic downgrade remains unsupported; an older app must not write a
  schema 10 database.

## Release Gate

`AI Report Persistence Gate` closes only after persistence, immutable versions,
account isolation, privacy boundaries, read-only UI, CI, and the manual matrix
all pass. Automated tests do not count as manual PASS.
