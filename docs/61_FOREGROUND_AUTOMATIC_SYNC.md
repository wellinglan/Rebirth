# Foreground Automatic Sync

> Classification: **Active implementation contract**
> Introduced: **Sprint 19A**
> Starting baseline: `17e9e9faea0f9be6cea268b8c55734e80ecbcc61`
> Implementation commit: `9a78c0dc117dbd0be87d107ea9b3da69d854ec96`
> Acceptance state: **OPEN pending manual matrix 67**

## Purpose

Sprint 19A adds user-authorized automatic reconciliation while Rebirth is in
the foreground. It reuses the six existing Sync Center modules and their
current transport, cursor, OCC, tombstone, conflict, and account-scope rules.
It does not create a second synchronization system.

The synchronized modules remain, in registry order:

1. Profile
2. Plan
3. Today
4. Journal, with Prompt Configuration before entries
5. Health
6. AI Report, including its attached structured Feedback behavior

AI Chat remains local to one account on one device and never emits an automatic
sync mutation signal.

## Authorization

`app_settings.cloud_sync_enabled` is the single persisted automatic-sync
preference. Its final semantics are:

- default `false`;
- scoped to the active local user in the current installation;
- independently selected on each device;
- explicitly confirmed before first enablement;
- independent from AI data consent;
- controls only automatic scheduling, not explicit manual synchronization;
- disabling cancels pending debounce, periodic, and retry work without deleting
  local records, cursors, conflicts, or synchronization metadata;
- an operation that already entered the existing safe synchronization path may
  finish.

No schema migration is required because Sprint 19A reuses the existing column.

## Architecture

```text
successful local controller mutation
  -> LocalSyncMutationBus (module identity only)
  -> ForegroundAutoSyncController
  -> debounce / lifecycle / periodic / bounded retry policy
  -> shared SyncExecutionGate
  -> SyncAllOrchestrator (optional ordered module subset)
  -> existing SyncModuleRunner
  -> existing SyncCoordinator and module adapters
```

The App root forwards authentication and lifecycle state only. It contains no
HTTP, Drift, cursor, conflict, or retry logic. Widgets can change the persisted
preference and display controller state, but cannot invoke Drift or the
`SyncCoordinator` directly.

## Trigger Policy

Automatic work can be queued by:

- explicit enablement: one full reconciliation;
- a usable authenticated session being restored: one full reconciliation;
- returning to `resumed`: one full reconciliation after the cooldown;
- a successful local write: the corresponding dirty module after debounce;
- remaining in the foreground: low-frequency full reconciliation;
- a transient transport failure: bounded retry for affected modules.

Central defaults are:

| Policy | Value |
|---|---:|
| Local mutation debounce | 1800 ms |
| Foreground reconciliation | 60 s |
| Resume cooldown | 20 s |
| Transient retries | 15 s, 60 s, 300 s |

There is no scheduler after the process exits. `inactive`, `hidden`, `paused`,
and `detached` stop creation of new periodic or retry work. No WorkManager,
foreground service, Windows service, tray process, WebSocket, push notification,
or server-sent event is introduced.

## Local Mutation Boundary

Signals carry only a `SyncModuleId`; they contain no user content or record ID.
They are emitted after successful local operations for:

- Profile save;
- Plan create, edit, completion, archive, restore, and delete;
- Today save, field updates, and delete; a combined Health write also marks
  Health dirty;
- Journal draft, completion, reopen, delete, and Prompt Configuration changes;
- Health save, update, and delete;
- AI Report completed/failed terminal persistence, archive, delete, terminal
  recovery, and structured Feedback save/clear.

Repository failures do not emit a signal. Reads, Provider refreshes, filters,
local previews, AI Chat, and remote adapter apply operations do not emit one.
Publishing a signal never waits for network work and therefore cannot turn a
successful local save into a network-dependent save.

## Shared Execution Gate

Manual and automatic batches share one application-level
`SyncExecutionGate`. Only one batch can enter the existing synchronization path
at a time. Pending automatic modules are coalesced in registry order. A local
mutation received during a running batch produces at most one follow-up batch.

An explicit manual request removes matching automatic work that has not begun.
If an automatic operation is already executing, the Sync Center disables manual
actions until that safe operation completes. Existing duplicate manual actions
continue to share their current Future. `syncInProgress` is requeued instead of
being presented as a permanent business failure.

## Account and Session Safety

Every automatic execution requires all of the following:

- business access is available;
- sync eligibility is `ready`;
- ownership verification is `verified`;
- the current session CloudUser matches the account scope;
- the normalized endpoint matches the session;
- the current device is registered;
- automatic sync is enabled for the active local user;
- the App is in the foreground.

Logout, account change, endpoint change, rejected/unknown sessions, binding
review, legacy review, or missing registration stop new scheduling and
invalidate old-scope results. The `SyncCoordinator` also rechecks the same
account scope before push acknowledgement, remote apply, and cursor advance, so
a response from Account A cannot be committed into Account B after a switch.

## Conflict and Failure Policy

Automatic synchronization never resolves a conflict. Existing unresolved
conflicts block only their owning module; other modules may continue. The
existing scoped conflict repository and Conflict Center remain authoritative,
and repeated periodic reconciliation does not choose a winner or clear the
conflict.

Only transient endpoint, push, pull, cursor, and unexpected transport failures
enter bounded retry. Authentication, account-scope, ownership-review, device,
unsupported payload, conflict, and deterministic apply failures do not retry
automatically. Local content is retained in every failure path. Automatic
success does not display a SnackBar; concise session-only status is shown in the
Sync Center.

## Product Surface

The Sync Center contains a compact adaptive switch, a session-only status, a
Conflict Center action when attention is required, and the unchanged manual
Sync All/module actions. The enablement dialog names the six modules, sensitive
Journal/Health/AI Report content, foreground-only behavior, per-account and
per-device scope, explicit conflict handling, AI Chat exclusion, and the
separate AI-consent boundary.

No raw cursor, server version, record UUID, endpoint credential, token, Prompt,
or private body is displayed.

## Version and Deployment Boundary

- Flutter schemaVersion remains `15`.
- API Version remains `1`.
- Sync Protocol remains `2`.
- Server routes, SQLAlchemy models, Alembic head, and Provider ledgers are
  unchanged.
- No new API image or Beijing Server deployment is required.

Automated tests establish source-level behavior. Manual acceptance remains
separate in [matrix 67](manual_tests/67_foreground_automatic_sync.md), and the
Foreground Automatic Sync Safety Gate remains **OPEN** until that matrix and
the required artifact/CI evidence are complete.

## Sprint 19B Evolution

The statements above describe the Sprint 19A implementation checkpoint. Sprint
19B preserves its scheduler, foreground-only boundary, and shared execution
gate, but adds conservative deterministic reconciliation after an OCC conflict.
The newer layer uses a durable common baseline and module field-group policies;
it does not use timestamps or select an ambiguous winner. See
[Deterministic Sync Reconciliation](62_DETERMINISTIC_SYNC_RECONCILIATION.md).

Sprint 19B advances Flutter schemaVersion to 16 for the local hashed-baseline
table. API Version 1, Sync Protocol 2, Server code, and deployment remain
unchanged. Matrix 67 is SUSPENDED at 0 / 0 / 58 and its Gate stays OPEN;
[matrix 68](manual_tests/68_deterministic_conflict_reconciliation.md) separately
owns the new reconciliation acceptance and also begins OPEN.
