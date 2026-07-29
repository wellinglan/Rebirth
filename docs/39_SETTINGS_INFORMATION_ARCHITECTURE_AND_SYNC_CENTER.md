# Settings Information Architecture and Sync Center

## Status

- Sprint: 12D
- Baseline: `a303dcbb11de05133844a380513bd1a3dd8e355e`
- Flutter schemaVersion: 9
- API Version: 1
- Sync Protocol: 2
- Server, PostgreSQL, and Alembic: unchanged
- Synchronization: manual only
- Product gates: open pending manual acceptance

## Problem

The former Settings page mixed ordinary account and privacy tasks with
Development User Key login, Server Endpoint editing, backend diagnostics,
device identifiers, directional Profile push/pull actions, and unfinished
placeholders. Existing manual sync was implemented per feature, but users had
no single view of its state or results.

Sprint 12D reorganizes this existing capability. It does not add automatic
sync, a new sync entity, production authentication, AI, or a Server contract.

## Pre-implementation Audit

| Area | Finding |
|---|---|
| Profile normal sync | Public Settings exposed separate push and pull actions |
| Profile conflict handler | Profile was not fully connected to the generic conflict UI |
| Plan, Today, Journal, Health | Existing controllers already refresh their business views after successful runs |
| Journal order | Existing controller requests prompt configuration before Journal entry |
| Coordinator concurrency | Global single-flight; the same request shares a Future and a different request receives `syncInProgress` |
| Entity ordering | Coordinator normalizes entities by enum index; product module order therefore needed a separate explicit registry |
| Counters | Entity results already provide pushed, pulled, deleted, ignored, and conflict counts |
| Failure count | Only failed internal entity count is reliable; record-level failure count does not exist |
| Last sync time | No reliable module-complete timestamp exists across all records |
| Restart state | Cursor, conflict, pending status, serverVersion, and record metadata persist; running/progress/result UI is transient |
| Conflict filter | The existing list had no user-module filter |
| Journal grouping | Prompt configuration and Journal entry are separate entities but one user module |
| Development gating | `enableDevLogin` is the existing authorized switch |
| Placeholder controls | WeChat login and sync settings were non-functional placeholders |
| Device readiness | Device registration remains a manual sync prerequisite |

## Settings Information Architecture

Top-level Settings now contains:

1. Account
2. Data & Sync
3. Personal Data & Privacy
4. Journal
5. Advanced Settings, only when `enableDevLogin` is true
6. About Rebirth

The top level is a summary and navigation surface. It does not render five
module controls, Endpoint details, device IDs, Development User Key, Profile
push/pull actions, or unfinished WeChat/sync-setting buttons.

## Account

The Account page presents user-facing account mode, login state, cloud
availability, current-device readiness, sync eligibility, logout, and the
local-data retention statement.

Because production authentication is not implemented, it explicitly states
that the Alpha build uses a development cloud account. A link to Developer
Options appears only when development login is enabled. Tokens, internal user
IDs, complete device IDs, Endpoint, JWT state, and database paths are never
shown.

## Developer Options

Developer Options contains the existing development-only operations:

- Development User Key login
- Endpoint edit and restore
- explicit backend health check
- device preparation
- ownership-verification diagnostics
- short device identifier when useful
- configuration source and Alpha status

Opening the page does not probe the network, register a device, log in,
verify ownership, or synchronize. Endpoint-switch logout and local-data
retention semantics are unchanged. No token or saved full User Key is shown.

## Sync Module Model

`SyncModuleId` is a stable product identifier and is not a Server entity:

| Stable ID | Display order | Entity types |
|---|---:|---|
| `module.profile` | 10 | Profile |
| `module.plan` | 20 | Plan |
| `module.today` | 30 | Today |
| `module.journal` | 40 | Journal Prompt Configuration, Journal Entry |
| `module.health` | 50 | Health |

The immutable `SyncModuleRegistry` explicitly registers these five modules.
Future enum values do not enter Sync All automatically. Growth and AI Report
are not registered. Presentation maps module IDs to icons; domain and
application types do not depend on Flutter.

`SyncModuleRunner` reuses the current module controllers and
`SyncCoordinator`. It does not call HTTP, read tokens, or duplicate push,
pull, OCC, cursor, transaction, or conflict algorithms. Successful runs
invalidate relevant local aggregation views in addition to each module's
existing business-page refresh.

## Sync Center

The Sync Center exposes one manual operation per user module and one Sync All
operation. Journal remains one card described as question configuration and
Journal records. Health carries an explicit sensitive-data notice.

Each card displays:

- user-facing state
- current-session result
- pushed count
- pulled count
- deleted count
- conflict count
- failed internal entity count
- independent sync action
- filtered conflict entry when needed

It does not expose raw phases, wire names, payloads, record UUIDs, cursor,
serverVersion, origin device, Token, Endpoint, Journal text, or Health data.

## Deterministic Sync All

`SyncAllOrchestrator` executes sequentially:

1. Profile
2. Plan
3. Today
4. Journal
5. Health

Journal internally remains:

1. Journal Prompt Configuration
2. Journal Entry

This order is independent of `SyncEntityType.index`. Only one module runs at
a time and the existing Coordinator remains the lower-level single-flight
authority.

The Sync Center adds application-scoped single-flight:

- repeated Sync All returns the active Future;
- repeated sync of the same module returns the active Future;
- a different action is rejected while one action is active;
- all other sync buttons are disabled while running;
- leaving and reopening the page observes the same controller state;
- no unsafe cancel or background queue exists.

## Result and Continuation Semantics

`SyncModuleExecutionResult` aggregates only the descriptor's internal entity
results. Counts are sums of existing entity counters. `failedEntityCount`
means failed internal entities, never failed records.

States are:

- idle
- queued
- running
- no changes
- succeeded
- conflict
- partial
- failed
- skipped

A global prerequisite failure such as Endpoint unavailable, authentication
required, account scope mismatch, ownership review, or device not ready stops
the orchestration once and marks later modules skipped. A module-specific
failure or conflict preserves prior results and continues to later modules.
Conflict is a user-decision state and is never resolved automatically.

## Profile Unified Sync

Normal Profile sync is now one two-way `syncProfile()` operation containing
only the Profile entity. The old push/pull methods remain available to
existing internal recovery tests, but ordinary UI no longer exposes
directional controls.

Profile is registered in the generic conflict pipeline with typed payload
codec, hydration, Keep Local, Adopt Remote, and requested-operation retry.
Conflict summaries hide private Profile fields and record identifiers. The
Profile payload, table, account scope, and Server contract are unchanged.

## Conflict Center

The existing conflict surface is presented as **Pending Issues** and supports
these user filters:

- All
- Profile
- Plan
- Today
- Journal
- Health

The Journal filter includes both prompt configuration and entry entities.
Filtering is local presentation state: it neither changes conflict rows nor
starts synchronization. Resolution invalidates conflict counts and the Sync
Center summary.

## Restart and Canonical State

Running, queued, progress, and current-session results are transient. A
provider rebuild or App restart begins idle and does not claim that an
interrupted operation is still running.

Existing canonical metadata remains authoritative:

- pending/local-only record state
- active conflict rows
- cursors
- acknowledged serverVersion
- record lastSyncedAt where available

There is no new sync-history table. Because no trustworthy module-complete
timestamp exists, the UI does not fabricate a “last full sync” time from one
record or the client clock. It labels results as belonging to this session.

## Account and Privacy Boundaries

All conflict reads use the current trusted `SyncConflictScope`. Account-scoped
provider invalidation includes Journal and Sync Center state. Logout clears
transient state but does not delete local data. Binding-required,
session-rejected, ownership-review, and device-readiness checks continue
through the existing Auth Gate and Coordinator.

Authenticated-offline users may inspect local state; a requested cloud run
fails explicitly without deleting local data. Developer Options cannot bypass
account ownership or device requirements.

## Responsive and Accessibility

Settings, Account, Developer Options, Sync Center, and conflict surfaces use
scrollable layouts, wrapping actions, readable status text, semantic labels,
and a live region for Sync All progress. Automated widget coverage includes
320, 360, 412, 720, 840, and 1200 pixel widths plus text scale 2.0.

Manual Windows keyboard and Android release behavior remains a product gate.

## Explicit Non-goals

- no automatic or background sync
- no retry scheduler
- no Growth or AI sync
- no new sync entity
- no production authentication or WeChat login
- no database migration
- no Server, PostgreSQL, or Alembic change
- no Beijing Alpha deployment

Production authentication remains planned for Sprint 13A.

## Gates

- Settings Information Architecture Product Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Unified Sync Center Product Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Profile Unified Sync UX Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`
- Account Boundary Isolation Gate: `CLOSED / ACCEPTED`

See `manual_tests/39_settings_information_architecture_and_sync_center.md`.
