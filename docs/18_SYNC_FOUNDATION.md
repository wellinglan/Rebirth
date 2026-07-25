# Rebirth Sync Foundation

> Status: Sprint 10B Plan adapter implemented locally; deployment and manual acceptance pending
> Protocol: Sync Protocol v2
> Product scope: manual canonical Profile sync and manual Plan two-way sync

## 1. Existing Contract Audit

Sprint 10A reuses the existing Sprint 6D/6E contract. It does not introduce a
parallel sync service or a new endpoint.

| Concern | Current contract |
|---|---|
| Health | `GET /health`, `api_version=1`, `sync_protocol_version=2` |
| Development login | `POST /auth/dev-login` |
| Device registration | `POST /devices/register` |
| Push | `POST /sync/push` |
| Pull | `POST /sync/pull` |
| Cloud user | The Rebirth user ID resolved from the bearer JWT |
| Device | Server device row registered for JWT user + local installation ID |
| Profile cloud key | `<cloud-user-id>/user_profiles/profile` |
| Local Profile key | Device-local Flutter UUID; it is never replaced by `profile` |
| Record version | Server-assigned global monotonic `server_version` |
| Pull cursor | Client-applied position, separate from record version |

The v2 transport schema allowlists `user_profiles`,
`today_records`, `journal_entries`, `goals`, and `health_records`. Sprint 10A
did not narrow that existing Server contract. Sprint 10B registers
`ProfileSyncAdapter` and `PlanSyncAdapter`. Today, Journal, and Health still
have no client adapter and cannot enter a product sync run.

## 2. Identity Boundaries

### Cloud User

The Server derives the owner from the current JWT. Push and pull requests do
not accept a trusted arbitrary user ID. The same Development User Key resolves
to the same Rebirth cloud user on Windows and Android; different keys remain
isolated.

Flutter remains a single-active-local-profile application. Its active local
Profile UUID is the owner of local business rows. Logging in does not rewrite
that UUID or silently bind a second local profile.

### Device

`app_settings.local_installation_id` is generated during Bootstrap and remains
stable for the installation lifecycle. `/devices/register` idempotently maps
that value to a cloud Device owned by the JWT user. It is not an IMEI, MAC,
Android ID, credential, or user identity.

The development session stores the returned cloud `device_id` in
SharedPreferences. A session is bound to its normalized Endpoint. Changing
Endpoint invalidates the old session/device registration while preserving all
local SQLite business data.

## 3. Canonical Profile

Cloud Profile identity is always:

```text
<cloud-user-id>/user_profiles/profile
```

Windows and Android keep independent local Profile UUIDs. Pull updates the
existing active local row and never creates a second active Profile.

For Sprint 6D legacy UUID-shaped cloud rows, the Server lazily selects the
highest `server_version` undeleted legacy row and copies it to canonical
`profile`. Legacy rows remain stored. Future Profile pulls return only the
canonical row.

## 4. Typed Flutter Domain

The foundation defines:

- `SyncEntityType`;
- `SyncOperation`;
- `SyncEntityPayload`;
- `SyncPushItem`;
- `SyncChange`;
- `SyncPullPage`;
- `SyncCursor`;
- `SyncRunDirection` and `SyncRunPhase`;
- `SyncEntityResult`;
- `SyncFailure` and `SyncFailureReason`;
- `SyncRunResult`;
- existing explicit `SyncConflict`.

Domain values do not depend on Widget, Material, Drift rows, Dio responses,
database paths, tokens, or secrets. Raw JSON maps remain confined to the DTO
boundary and each adapter's encode/decode methods. Unknown entity types are
rejected; they never default to Profile.

`SyncOperation.upsert` maps to `deleted_at == null`.
`SyncOperation.delete` maps to a v2 tombstone with `deleted_at != null`.
There is no separate HTTP `operation` field in Protocol v2.

## 5. Coordinator

`SyncCoordinator` is a user-triggered application service. A run:

1. verifies that every requested entity has a registered adapter;
2. probes the configured Endpoint health contract;
3. reads the Endpoint-bound development session and cloud user;
4. requires an existing registered Device;
5. asks each adapter for pending local records;
6. pushes pending records and applies acknowledgements;
7. reads the Endpoint/user/scope cursor;
8. pulls changes after that cursor;
9. decodes and applies changes through the owning adapter;
10. advances the cursor only after successful local apply;
11. returns phases, per-entity counts, conflicts, and a controlled failure.

Every run has an identity made from its direction and a normalized entity set.
Entity types are deduplicated and sorted by enum declaration order, so caller
order does not affect identity or execution order.

Overlapping calls reuse the exact in-flight Future only when both direction and
normalized entity set match. A different request immediately returns a
structured `syncInProgress` failure. It is not queued, does not start a second
network run, does not call an adapter, and does not read or advance a cursor.
The original run continues normally.

The Coordinator has no Widget dependency, does not show SnackBars, never logs
payloads or credentials, and uses entity-neutral transport failure messages.

Only manual Settings actions invoke the current Profile or Plan flow. There is no
timer, lifecycle hook, startup sync, background task, realtime push, or system
notification.

## 6. Entity Adapter

`SyncEntityAdapter` owns entity-specific behavior:

- collect pending local records;
- build typed push payloads;
- encode/decode the v2 payload boundary;
- apply remote upsert or tombstone semantics;
- acknowledge accepted pushes or conflicts;
- persist local `server_version` and sync metadata;
- apply a remote batch in a local transaction.

An adapter cannot log in, change Endpoint, display UI, or advance a cursor.
Registration is explicit through `SyncEntityAdapterRegistry`.

Sprint 10B registers `ProfileSyncAdapter` and `PlanSyncAdapter`.

## 7. Profile Adapter

The Profile adapter:

- collects the active Profile only when its status is not `synced`;
- always sends canonical record ID `profile`;
- uses a typed `ProfileSyncPayload`;
- preserves explicit nullable Profile fields and rejects missing required
  payload keys;
- updates the existing local UUID in a Drift transaction;
- marks accepted pushes `synced` with server version and sync time;
- treats same/older remote versions as idempotent replays;
- prevents an older version from overwriting a newer local server version;
- always protects `pending` and `conflict` local rows, regardless of
  `updated_at` and `last_synced_at` ordering;
- accepts the first remote Profile over a blank `local_only` row;
- protects a `local_only` row when it contains an explicit display name or
  growth focus;
- marks protected local/remote changes as `conflict`;
- preserves local content on network, parse, or apply failure.

Profile deletion is not currently a product operation. A remote Profile
tombstone is surfaced as a conflict and is not applied as a local delete.

## 8. Push Flow

```text
manual Settings action
-> endpoint/session/device checks
-> Profile Adapter collects local_only/pending/conflict Profile
-> typed Profile payload
-> v2 POST /sync/push
-> accepted: persist synced/serverVersion/lastSyncedAt
-> conflict: preserve content and mark conflict
```

A repeated upload without a new local Profile change sends no second push and
returns a no-pending result.

## 9. Pull Flow And Cursor

The existing cursor storage remains
`SharedPreferences` prefix `rebirth.sync_cursor.v1`. The key contains:

- normalized Endpoint;
- cloud user ID;
- scope (`user_profiles`).

Keeping the same prefix and key shape preserves existing Sprint 6E cursor
values across this refactor.

```text
read endpoint/user/profile cursor
-> v2 POST /sync/pull
-> decode all returned Profile changes
-> order/apply in a Drift transaction
-> only on success write response server_version as cursor
```

An empty successful page can advance the cursor. Network failure, malformed
payload, conflict, or local apply failure leaves it unchanged.

Missing cursor data reads as `0`. A stored non-negative integer is valid. A
negative stored cursor is treated as corruption: the client returns
`cursorFailed`, sends no pull request, does not write a replacement value, and
does not affect any other Endpoint/user/scope key.

SQLite and SharedPreferences cannot share one atomic transaction. The safe
crash window is after the Drift transaction commits but before the cursor is
written. Recovery re-pulls the page; the adapter ignores any
`server_version <= local server_version`, so replay is idempotent. The unsafe
inverse ordering never occurs: the cursor is never written before local apply.

## 10. Server Version And Clock

`server_version` belongs to a server sync record. `updated_at` remains client
business time and never substitutes for the version or cursor.

The Server's single `sync_clock` remains the allocator. It initializes at or above the
largest existing item version and allocates new versions with database-level
atomic `UPDATE ... RETURNING`. It does not use `max()+1`, a Python lock, or a
single-worker assumption.

Sprint 10B makes push concurrency strict. New records require client version
zero; existing updates require an exact server-version baseline. Client
timestamps never let stale data win. Exact payload/time/deletion/origin replay
returns the existing version without allocating a clock value.

Each push request is preflighted as one unit. A real conflict, invalid Plan
payload, invalid projected hierarchy, or orphaning tombstone produces no new
writes and no clock advancement.

## 11. Conflict And Tombstone Boundaries

Protocol v2 transports tombstones through `deleted_at`. Entity adapters decide
whether deletion is supported. Profile currently does not auto-apply delete.

Profile conflict detection remains conservative:

- stale push conflicts are returned by Server;
- a newer remote version never overwrites `pending` or `conflict` local edits,
  even when local timestamps are equal, older, or affected by clock rollback;
- blank `local_only` remains compatible with first-device restore, while
  explicit local Profile content remains protected;
- no field-level merge or overwrite-choice UI exists;
- failure never resets Profile fields to defaults.

Plan conflicts preserve local business fields and mark the affected rows
`conflict`. The Plan page cursor does not advance. Safe “adopt cloud” recovery
is deferred to Sprint 10B.1 because the current schema cannot guarantee
restoration of conflict state after a failed network pull.

## 12. Privacy And Diagnostics

Structured results may include entity type, phase, counts, controlled reason,
and server version. They do not include Profile text, token, full request body,
database URL/path, JWT secret, or Endpoint credentials.

## 13. Current Scope

- Profile sync: implemented, manual.
- Plan sync: implemented locally, manual two-way; cloud deployment pending.
- Today sync: not implemented.
- Journal sync: not implemented.
- Health sync: not implemented.
- Growth raw data sync: not implemented.
- AI Report sync: not implemented.
- AI Consent / Cloud Consent sync: not implemented.
- Background sync: not implemented.

## 14. Sprint 10B Plan Adapter Boundary

Plan uses the local Goal UUID as its cross-device record ID. Its typed payload,
local mutation metadata, parent-first upserts, child-first tombstones,
transactional acknowledgement, projected pull hierarchy, and non-destructive
conflict behavior are documented in `docs/19_PLAN_CROSS_DEVICE_SYNC.md`.

The Plan action calls the existing Coordinator with `twoWay` and only
`SyncEntityType.plan`. Settings keeps separate Profile controls. Plan success
refreshes the current PlanController; failure does not clear its UI state.

## 15. Sprint 10A Automated Evidence

Executed on 2026-07-25:

| Check | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, `728 passed / 2 skipped` |
| Server non-PostgreSQL pytest | PASS, `123 passed / 1 skipped / 8 deselected` |
| PostgreSQL marker | SKIPPED, `8 skipped / 124 deselected`; no isolated test URL was configured |
| Windows release build | PASS |
| Android split release build | PASS, including arm64-v8a |

The two Flutter skips are the existing opt-in Uvicorn Fake full-stack tests.
The Server PostgreSQL marker is not recorded as PASS. No test connected to the
cloud Alpha business database. Windows, Android physical-device, and
cross-device manual acceptance remain `NOT EXECUTED`.

## 16. Sprint 10A.1 Automated Evidence

Executed locally on 2026-07-25:

| Check | Result |
|---|---|
| Dart format on changed Dart files | PASS |
| `flutter analyze` | PASS, no issues |
| Coordinator + Profile + cursor targeted tests | PASS, `46 passed` |
| `flutter test` | PASS, `741 passed / 2 skipped` |
| Windows release build | PASS, `build/windows/x64/runner/Release/rebirth.exe` |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter `schemaVersion` | unchanged at `3` |

The two Flutter skips remain the existing opt-in Uvicorn Fake full-stack tests.
The Android build emitted the existing CupertinoIcons asset warning but
produced all three APKs. Server runtime was not changed, and no cloud deployment
or Alpha business database test was run.

Implementation commit `bf254308cfd64755d1bd32aea8189bd920004a71`
triggered GitHub Quality workflow run `30145133981`. The run completed
successfully, including Server SQLite, Server PostgreSQL Multiprocess And
Multiworker, Flutter Analyze And Test, and Android Debug Build. The PostgreSQL
marker was therefore executed and passed in GitHub CI rather than inferred from
local results. All Windows, Android physical-device, and cross-device manual
rows remain `NOT EXECUTED`.

## 17. Sprint 10B Local Automated Evidence

Executed locally on 2026-07-25:

| Check | Result |
|---|---|
| `flutter pub get` | PASS; 24 newer incompatible versions reported, no dependency change required |
| `flutter analyze` | PASS, no issues |
| Sprint 10B targeted Flutter tests | PASS, `125 passed` |
| `flutter test` | PASS, `775 passed / 2 skipped` |
| Server SQLite/non-PostgreSQL pytest | PASS, `139 passed / 9 skipped` |
| Local PostgreSQL marker selection | SKIPPED, `8 skipped / 140 deselected`; no isolated PostgreSQL URL configured |
| Windows release build | PASS |
| Windows release launch smoke | PASS; process launched and was closed after verification |
| Android split release build | PASS, armv7 + arm64 + x86_64 |
| Flutter `schemaVersion` | unchanged at `3` |
| API / Sync Protocol | unchanged at `1` / `2` |

The two Flutter skips remain the opt-in Uvicorn Fake full-stack tests. The
Server skips include tests requiring opt-in external environments. The Android
build emitted the existing CupertinoIcons asset warning and produced all three
APKs.

No cloud Alpha business database was contacted. The PostgreSQL marker has not
run for this unpushed change set in GitHub CI. GitHub Quality, GHCR publication,
cloud API deployment, Windows manual acceptance, Android physical acceptance,
and cross-device manual acceptance remain `NOT VERIFIED` or `NOT EXECUTED` as
applicable.
