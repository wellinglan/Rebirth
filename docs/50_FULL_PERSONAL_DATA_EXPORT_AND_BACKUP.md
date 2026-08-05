# Full Personal Data Export and Backup Foundation

> Status: **Implemented locally / manual Gate OPEN**  
> Sprint: **15A**  
> Source baseline: `c835a24c74c2ba3a92894ce6ba05d47fff1ab810`  
> Flutter schemaVersion: `11`  
> API Version: `1`  
> Sync Protocol: `2`

## Product Boundary

Sprint 15A adds an explicit, account-scoped export of the current user's local
personal business data. The user starts the operation from Settings, reviews a
sensitive-data warning, confirms the scope, and chooses a destination through
the native Windows or Android save dialog.

The resulting file is plaintext UTF-8 JSON. It can contain Journal responses,
Health notes, and AI Report bodies. It is not automatically encrypted, uploaded,
or synchronized. The user must keep it in a trusted location.

This Sprint establishes a versioned, integrity-checked format that a future
restore design may consume. It **does not implement import or restore**, merge,
scheduled backup, cloud backup, or recovery. The product must not claim that the
current file can restore an account.

## User Flow

```text
Settings
  -> Personal data and privacy
  -> Export all personal data
  -> sensitive-data and scope disclosure
  -> explicit confirmation
  -> current-account snapshot transaction
  -> deterministic encoding and integrity verification
  -> native save dialog
  -> saved, cancelled, or controlled failure feedback
```

The export button is disabled while an operation is running. Cancellation
creates no file and changes no product state. A controlled failure can be
retried without restarting the application and never includes a private path or
record body in the message.

## Architecture

```text
FullPersonalDataExportPage
  -> FullPersonalDataExportController
  -> FullPersonalDataExportService
  -> PersonalDataExportModuleRegistry
  -> typed module exporters
  -> account-scoped read repository
  -> portable backup DTOs
  -> PersonalDataBackupEncoder
  -> shared FileExportAdapter
  -> Windows or Android native save dialog
```

The registry is explicit, immutable, and ordered. Each module owns its typed
mapping. Presentation code does not access Drift, build JSON, or write files.
Portable backup DTOs are independent of Drift rows, API DTOs, and Sync Protocol
payloads. A failure in any module closes the whole operation; no partial backup
is offered as a successful file.

Sprint 14F's platform behavior is reused through the shared
`FileExportAdapter`. AI Report export and full personal data export therefore do
not maintain separate Windows or Android file-writing stacks.

## Format Contract

The suggested filename is:

```text
rebirth-personal-data-backup-YYYY-MM-DD.json
```

The local date is used only in the suggested filename. The export timestamp and
all timestamp-valued fields are UTC ISO-8601 strings. Business natural dates
remain `YYYY-MM-DD` strings and keep their local-date meaning.

The top-level format is:

```json
{
 "format_id": "rebirth-personal-data-backup",
 "format_version": "1.0",
 "exported_at": "2026-08-05T01:02:03.000Z",
 "source": {
  "app_version": "1.0.0+1",
  "database_schema_version": 11
 },
 "manifest": {
  "account_scope": "current_authenticated_account",
  "modules": [],
  "record_counts": {},
  "derived_data_excluded": [
   "growth",
   "personal_data_aggregation"
  ],
  "restore_supported": false
 },
 "payload_sha256": "...",
 "data": {}
}
```

`format_id`, `format_version`, module IDs, enum strings, and field names are
portable format contracts. Unknown future fields must be ignored by a future
reader unless that format version explicitly requires them.

## Deterministic Encoding and Integrity

Before hashing, every JSON object in `data` is recursively ordered by key.
Arrays retain their defined domain order. The canonical `data` object is
encoded as compact UTF-8 JSON and hashed with SHA-256. `payload_sha256` is not
included in its own input.

Before the save dialog opens, the service recalculates the digest from the
in-memory DTO and refuses to write if it differs. The complete file is then
encoded as deterministic indented JSON. Given identical data and an identical
`exported_at`, the encoded bytes are identical.

The format preserves the distinction between:

- a missing optional field in a future format;
- an explicitly exported `null`;
- numeric `0`;
- an empty string;
- a non-empty Unicode string.

## Module Manifest

The first format registers these modules in a stable order:

| Module ID | Included personal business facts | Important exclusions |
|---|---|---|
| `profile` | Display name, growth focus, timezone, created/updated timestamps | Local/cloud user IDs, credentials, account binding and sync metadata |
| `plan` | Stable record ID, parent relation, title, description, level, status, dates, completion/archive/delete lifecycle, order, timestamps | User/device IDs, server version, sync state and conflict data |
| `today` | Date, timezone offset, three priority slots and goal relations, completion flags, mood, energy, research/learning minutes, note, lifecycle and timestamps | User ID and transport metadata |
| `journal` | Date, lifecycle, Today relation, dynamic prompt snapshots, responses, and explicit legacy compatibility facts | Runtime Provider prompts, sync payloads and account identity |
| `journal_prompt_configurations` | Configuration key/version, definitions, stable keys, source, text, order, enable state, version and lifecycle timestamps | Sync state, conflict payloads and user ID |
| `health` | Date, Today relation, sleep, weight, water, exercise, physical-state score, note, source and lifecycle timestamps | User ID, source record transport ID and sync metadata |
| `ai_reports` | Stable report ID, title, type, period, lifecycle, current content/version, sensitivity/quality, timestamps and immutable versions in ascending order | Prompt/input/scope/hash, Provider/model, structured output, errors, generation ledger, usage ledger and sync metadata |

Stable business record IDs are included only where a future restore process
needs them to rebuild relationships. They are not account IDs or device IDs and
are not copied from a cloud sync payload. Soft-deleted business facts retain
their `deleted_at` lifecycle value. Sync tombstones are never exported.

A future restore implementation must treat historical deletion state as local
backup history and must not automatically propagate it to the cloud.

## Derived Data

Growth and Personal Data Aggregation are read-only projections over source
facts. They are intentionally absent from `data`; the manifest records their
exclusion. A future compatible product recomputes them from Profile, Plan,
Today, Journal, and Health rather than restoring duplicate evidence.

## Account and Session Boundary

The authenticated local account ID is resolved by the application session and
is never accepted from a Widget or export request. The service checks the
boundary:

1. before any module reads data;
2. before and after every registered module;
3. after the read transaction and before opening the save dialog.

Account switch, logout, or definitive session rejection invalidates the export
providers and controller. If the active account changes during assembly, the
operation stops and the native picker is not opened. Every query is explicitly
scoped to the same local account; relation validation fails closed instead of
silently omitting inconsistent data.

## Strict Exclusions

The backup never contains:

- passwords, password hashes, access/refresh credentials, secure-storage data,
  API keys, Provider secrets, or JWT secrets;
- private Server endpoints, cloud user IDs, auth session IDs, OAuth transaction
  material, reauthentication proofs, device IDs, or registrations;
- AI generation/usage ledgers, raw Provider requests/responses, runtime prompts,
  canonical inputs, input hashes/snapshots, or source scopes;
- server versions, cursors, sync state, pending operations, conflict payloads,
  remote snapshots, or transport tombstones;
- local database paths, selected save paths, logs, diagnostics, or internal
  exception text.

## Non-mutation and Local-only Operation

Snapshot reads run in one Drift read transaction and never update records.
Export does not change bodies, lifecycle, `updatedAt`, immutable version counts,
sync metadata, cursors, conflicts, tombstones, AI consent, usage, or ledgers.

No API request, token refresh, device registration, endpoint probe, AI
generation, or manual/background synchronization is part of this flow. The
Server, PostgreSQL, Alembic, API Version 1, and Sync Protocol 2 are unchanged.
Flutter `schemaVersion` remains 11 and no Drift migration is added.

## Verification and Gate

Automated coverage includes typed module mapping, complete Drift snapshots,
account isolation, null/zero/empty/Unicode behavior, long text, large histories,
multi-version reports, forbidden-field checks, deterministic SHA-256, tamper
rejection, non-mutation, cancellation, storage failure/retry, account changes,
shared platform adapters, responsive UI, keyboard interaction, and architecture
boundaries.

The manual Gate is still **OPEN**. Windows and Android execution is recorded in
[Full Personal Data Export and Backup manual matrix](manual_tests/55_full_personal_data_export_and_backup.md).
All 54 rows start as `NOT EXECUTED`; automated tests do not convert them to
manual PASS.

