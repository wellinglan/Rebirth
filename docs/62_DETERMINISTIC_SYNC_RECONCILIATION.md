# Deterministic Sync Reconciliation

> Sprint: **19B - Deterministic Conflict Reconciliation & Sync Resilience**
> Baseline: `c8c417c79c6d5b6e5cb270a005a127fe47d09505`
> Classification: **Active implementation contract**
> Safety Gate: **OPEN pending matrix 68**

## Purpose

Sprint 19B adds a conservative three-way reconciliation layer to the existing
Sync Protocol 2 client. It does not replace `SyncCoordinator`, cursors, OCC,
tombstones, the Conflict Center, or the shared manual/automatic
`SyncExecutionGate`.

The layer answers one narrow question: can the client prove that convergence is
unambiguous? If it cannot, local data is retained and the conflict remains a
manual decision. There is no last-write-wins policy and no decision based on
`updatedAt`, device time, request arrival order, or device identity.

## Architecture

```text
manual or foreground automatic synchronization
  -> SyncExecutionGate
  -> existing module adapter and SyncCoordinator
  -> OCC conflict / current remote snapshot
  -> ConflictReconciliationService
       + durable SyncRecordBaseline
       + module SyncMergePolicy
       + current local and remote snapshots
  -> safe automatic action OR existing Conflict Center
```

The implementation covers Profile, Plan, Today, Journal Entry, Journal Prompt
Configuration, Health, AI Report, and AI Report Feedback. Growth is derived and
is not a sync entity. AI Report Version is part of the report aggregate. AI Chat
remains local-device only and has no adapter, cursor, baseline, or reconciliation
path.

## Durable Common Baseline

Flutter schemaVersion 16 adds the local technical table
`sync_record_baselines`:

| Column | Purpose |
|---|---|
| `local_user_id` | Account scope and cascading local ownership |
| `entity_type` | Existing wire entity type, or the attached feedback type |
| `record_id` | Stable record identity within the account and entity type |
| `base_exists` | Whether the last acknowledged common record existed |
| `base_server_version` | Last acknowledged Server OCC version |
| `base_tombstone` | Whether the acknowledged common state was deleted |
| `group_hashes_json` | Canonical field-group names and SHA-256 hashes only |
| `captured_at` | Local diagnostic capture time |

The primary key is account + entity type + record ID. Baselines are local,
account-scoped, non-syncing, non-exported, and omitted from logs and UI. They do
not copy Profile, Journal, Health, AI Report, Prompt, or feedback content. Stable
canonical JSON is hashed per policy group with SHA-256.

A baseline is updated only after a successful push acknowledgement or a remote
apply, in the same local transaction as the corresponding sync metadata. A
stale acknowledgement cannot mark a newer local edit as synchronized. Database
reopen preserves baselines; account deletion cascades only that account's rows.

Conflict snapshots are not reused as common baselines because they describe a
disagreement, not a previously acknowledged common state.

## Decision Model

`ConflictReconciliationService` produces exactly one of five outcomes:

| Outcome | Meaning |
|---|---|
| `noChange` | Local and remote already represent the same canonical state; refresh metadata/baseline only. |
| `adoptRemote` | The local side still equals the common baseline and only the remote side changed. |
| `retryLocal` | The remote side still equals the common baseline and only the local side changed; retry once against the current remote version. |
| `mergeAndRetry` | Both sides changed disjoint field groups, or changed a group to the same value; apply the deterministic merged payload locally and retry once. |
| `manualConflict` | The evidence is absent or ambiguous; retain local data and use the Conflict Center. |

Core rules:

- local equals remote: converge automatically and refresh the baseline;
- local equals base: adopt the changed remote state;
- remote equals base: retry the changed local state using current
  `serverVersion`;
- disjoint changed groups: merge and retry;
- the same group changed to the same value: converge;
- the same group changed to different values: manual conflict;
- both deleted: converge;
- delete versus unchanged: adopt the deletion;
- delete versus modification, or archive versus delete: manual conflict;
- no trusted baseline: only exact local/remote equality can converge.

If the retry meets a second OCC race, the client fetches and recalculates once.
A further race becomes a manual conflict. There is no retry loop.

## Field Group Policies

### Profile

Independent profile, growth preference, and timezone groups may merge when
their changes do not overlap. Server-derived timestamps are not used to choose
a winner.

### Plan

Title and description are independent. Hierarchy, date rules, lifecycle, and
stable identity are conservative atomic groups. Delete versus modification is
manual.

### Today

Each priority text, completion flag, and linked goal form one group. Mood score
and description are separate groups, as are Energy score and description.
Each duration and its description form one group. Daily note and lifecycle are
conservative groups. Canonical hashing preserves null and explicit zero and the
1-10 scale metadata.

### Health

Each metric and its matching description form one group. Hidden fields remain
part of the canonical payload. Null, explicit zero, and 1-10 Physical State
semantics remain distinct.

### Journal

Entry status is a lifecycle group. Prompt snapshot answers and free-form body
data are conservative atomic groups and are never text-merged. Delete versus
body modification is manual. Prompt Configuration order and enabled state are
one conservative structure; concurrent edits remain manual.

### AI Report and Feedback

An AI Report is one conservative aggregate. Current body and immutable versions
are never field-merged or rewritten. A one-sided archive can converge, while
archive versus delete is manual. Structured feedback uses its own atomic group
and existing dedicated authenticated transport; reason-code sets are
canonicalized before hashing.

## Resilience and Scope Safety

- Duplicate mutation signals are coalesced by the foreground scheduler.
- Manual and automatic work share one single-flight execution gate.
- Existing request IDs, Server idempotency, OCC, and cursor behavior remain in
  force; no second transport is introduced.
- A lost response cannot acknowledge a newer local edit. The next reconciliation
  uses current local/remote state and the last durable baseline.
- Remote apply, merged local apply, and baseline writes do not emit mutation
  signals.
- One module's manual conflict does not stop unrelated modules.
- Partial module results retain already completed work and report remaining
  attention honestly.
- Before critical local writes, the active account, authenticated session,
  endpoint, ownership eligibility, and device registration are revalidated.
- Logout, account switch, endpoint switch, session rejection, binding review,
  or device invalidation makes old asynchronous results ineligible to apply.
- Background/inactive App states do not start new work. Process termination has
  no worker and makes no synchronization claim.

## Product Surface and Privacy

Sync Center may show only aggregate session outcomes:

- `已自动协调 N 条`
- `仍有 N 条需要处理`

The introductory consent text explains that provably one-sided or disjoint
changes may reconcile automatically, while genuine conflicts still require a
choice. The Conflict Center continues to contain only manual conflicts and
retains the existing Keep Local and Adopt Remote actions.

Neither surface nor normal logs expose bodies, Prompt text, token/secret data,
credentials, raw UUIDs, cursors, `serverVersion`, baseline hashes, or raw
reconciliation reasons.

## Version and Deployment Boundary

- Flutter schemaVersion: **16** (additive local technical table only).
- API Version: **1**, unchanged.
- Sync Protocol: **2**, unchanged.
- FastAPI, SQLAlchemy, Alembic, AI Provider, and AI ledgers: unchanged.
- No API image should be published for this Flutter-only change.
- Beijing Server redeployment is not required.

## Evidence and Release Gates

Automated tests cover the decision truth table, module policies, migration,
transactions, duplicate/stale responses, bounded OCC retry, scope invalidation,
UI summaries, and privacy boundaries. They do not become manual PASS.

[Matrix 68](manual_tests/68_deterministic_conflict_reconciliation.md) starts at
`0 PASS / 0 FAIL / 68 NOT EXECUTED`. The **Deterministic Conflict
Reconciliation Safety Gate remains OPEN** until applicable Windows/Android
cross-device rows and artifact/CI identity are recorded. Matrix 67 is explicitly
suspended without changing its rows, so the **Foreground Automatic Sync Safety
Gate also remains OPEN**.

This Sprint does not claim that all conflicts are automatically resolvable,
that synchronization continues after App termination, that real-time push
exists, or that AI Chat synchronizes across devices.
