# Cloud Account And Local Data Isolation

> Discovery date: 2026-07-26
> Source: Sprint 10B / 10B.1 manual acceptance
> Defect: `PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001`
> Status: `CONFIRMED RELEASE BLOCKER`
> Implementation status: not started; architecture decision required

## Executive Summary

Rebirth currently keeps business rows under one active local `UserProfile`,
while the authenticated cloud user can change independently. Plan
`sync_status`, `server_version`, and `last_synced_at` are stored directly on
the local Goal and are not bound to the normalized Endpoint and cloud user that
produced them.

This allows a Goal synchronized under cloud account A to retain account A's
server version after the app signs in as account B. A later mutation can then
submit that version to account B. Strict server OCC correctly rejects the
request, but account B has no remote row to hydrate. The client persists an
`awaiting_remote_snapshot` conflict that cannot advance to an actionable state.

The local data itself should remain safe for offline use. The defect is that
data and sync metadata from one account remain active and sync-eligible under a
different account.

## Verified Environment

- Environment: Development + Fake Provider + Tailscale private Alpha.
- API image:
  `ghcr.io/wellinglan/rebirth-api:713f46a71ab5aa46be45ae62051a366859ab9a39`.
- API container: healthy.
- Health contract: status `ok`, service `rebirth-api`, API `1`, Sync Protocol
  `2`, environment `development`.
- Windows release: launched.
- Android release: matching arm64-v8a APK installed.
- Android device: OnePlus 15T (`一加15T`).
- Android software version: `PLZ110_16.0.9.400`.

No token, full cloud user ID, full device ID, private Goal text, public IP
address, or Secret is recorded in this document.

## Reproduction

1. Sign in with Development User Key A.
2. Create or retain a local Goal.
3. Successfully synchronize that Goal under account A, giving it a nonzero
   `server_version`.
4. Sign out and sign in with a new Development User Key B on the same
   installation.
5. Register the installation for account B.
6. Delete the old local Goal.
7. Run manual Plan sync.
8. Open Settings, the conflict inbox, and the conflict details.
9. Invoke `重新获取云端版本` once while online.

## Observed Result

- Ordinary Windows/Android root-child synchronization succeeded without
  duplicate Goals.
- Deleting the old Goal produced one active conflict.
- The local side showed a preserved tombstone.
- The conflict entered `awaiting_remote_snapshot`.
- The cloud summary had no title, status, dates, or update time.
- No adopt-remote or keep-local action was available.
- Retry displayed `冲突操作已完成`.
- After retry, the active count remained one and the state remained
  `awaiting_remote_snapshot`.
- Settings and Plan navigation remained stable.
- The Goal was confirmed to have synchronized previously under User Key A.

## Expected Result

- Signing in as account B must not make account A's business rows or sync
  metadata active under account B.
- Account B must not upload, delete, conflict on, or hydrate account A's Goal.
- Signing back in as account A should restore account A's local data space and
  allow the tombstone to synchronize with account A's correct server baseline.
- Local data must not be silently deleted on logout or account change.
- A retry action must not report completion when the target conflict remains
  awaiting and unchanged.

## Current Identity Model

### Local ownership

All business tables already reference `user_profiles.id`:

- `goals`
- `today_records`
- `journal_entries`
- `health_records`
- `ai_reports`
- `app_settings`
- `sync_conflicts`

`BootstrapDao` maintains exactly one active local profile and creates one when
none exists. The local profile UUID is intentionally distinct from the cloud
user ID.

### Cloud session

The authenticated session owns:

- normalized Server Endpoint;
- cloud user ID;
- access and refresh tokens;
- current device registration.

Endpoint changes clear the incompatible session and device registration but
intentionally preserve Flutter SQLite.

### Already scoped correctly

The pull cursor is keyed by:

```text
normalized Endpoint + cloud user ID + sync scope
```

Persistent conflict queries are keyed by:

```text
local user + normalized Endpoint + cloud user ID + entity + record ID
```

### Missing boundary

Goal sync metadata remains on the Goal row:

```text
sync_status
server_version
last_synced_at
origin_device_id
```

The Goal row knows only its local `user_id`. It does not know which Endpoint
and cloud user own its current `server_version`.

## Confirmed Technical Cause

`PlanSyncAdapter.collectPending()` selects local `local_only` and `pending`
Goals and sends:

```text
client_version = goal.serverVersion ?? 0
```

The Server isolates `sync_items` by the authenticated cloud user. When account
B has no matching row:

- `client_version == 0` is accepted as a new record;
- nonzero `client_version` is rejected as `stale_client`.

The old tombstone carried account A's nonzero version into account B's request.
The Server therefore returned a valid OCC conflict with remote version zero.
Account B had no corresponding pull change, so hydration could never supply a
remote payload or tombstone.

The conflict store correctly isolated the newly created conflict under account
B, but it received already-contaminated local sync metadata. Conflict scoping
alone cannot repair ownership before a push.

## Impact

### Data isolation

A new cloud account can see local business data left active by an earlier
account. Even though the Server rejected this specific write, the client
attempted to use old account sync metadata in the new account scope.

### Availability

The malformed conflict remains permanently active and can block later Plan
sync and release acceptance.

### User trust

The UI reports that the operation completed even though no resolution progress
occurred.

### Future sync modules

Today, Journal, and Health are not currently synchronized, but they share the
same local `user_id` ownership model. Starting their sync before resolving this
boundary would repeat the risk.

## Product Invariant

The required invariant is:

> One cloud identity scope owns one local data space. Local data may remain on
> disk after logout, but it must never become visible or sync-eligible under a
> different Endpoint or cloud user without an explicit user-approved transfer.

Cloud identity scope means:

```text
normalized Endpoint + cloud user ID
```

## Candidate Designs

### Option A: Bind a local UserProfile to one cloud identity

Introduce a durable mapping similar to:

```text
cloud_account_bindings
  id
  local_user_id
  endpoint_key
  cloud_user_id
  created_at
  last_used_at
```

Candidate constraints:

```text
UNIQUE(endpoint_key, cloud_user_id)
UNIQUE(local_user_id)
```

On login, activate the local profile bound to that cloud identity. If no
binding exists, create a new local data space or explicitly bind an unbound
local profile.

Advantages:

- reuses existing `user_id` foreign keys across every business table;
- isolates all local modules, not only Plan;
- keeps Goal sync metadata valid because one local profile has one cloud owner;
- makes logout/re-login restore the correct local space;
- provides a foundation before more entity types begin syncing.

Risks and decisions:

- first-login handling for existing unbound local data requires explicit UX;
- active-profile switching and Bootstrap behavior must be transactional;
- device installation identity must remain a device concern, not accidentally
  become a cloud-account identifier;
- migration cannot guess which historical cloud account owns existing data.

### Option B: Move per-record sync metadata into an account-scoped table

Store `sync_status`, `server_version`, and `last_synced_at` by:

```text
local user + Endpoint + cloud user + entity + record ID
```

Advantages:

- models sync metadata at its exact scope;
- potentially allows one local record to have multiple cloud bindings.

Risks:

- business rows remain visible across account changes;
- the same private record could be copied to another account unless every
  adapter enforces an additional ownership decision;
- larger adapter and Repository changes;
- duplicate metadata paths while current tables retain common sync columns.

This option solves version contamination but does not by itself meet the
product invariant that accounts have isolated local data spaces.

### Option C: Reset server metadata when the cloud user changes

Reset old Goals to `local_only`, clear `server_version`, then upload them as new
records under the new account.

This is rejected as a default because it silently copies account A's local data
into account B.

### Option D: Delete local data on logout or account change

This is rejected because it breaks local-first/offline guarantees and can cause
irreversible data loss.

## Recommended Direction For Evaluation

Option A is the current recommendation: bind each local `UserProfile` data
space to exactly one normalized Endpoint and cloud user. Preserve old profiles
on disk and switch the active profile when the authenticated identity changes.

Option B may still be evaluated if future requirements explicitly permit one
local data space to synchronize independently with multiple cloud accounts,
but that is not the current product requirement.

## First-Login Decision

When the current local profile is unbound and the user signs in, the app must
not silently decide ownership. Candidate UX:

1. `创建此账号的新数据空间` — safest default.
2. `将当前本地数据绑定到此账号` — explicit confirmation, with a clear summary
   of what will become sync-eligible.
3. Cancel and continue offline.

When the current local profile is already bound to a different cloud identity,
the app must switch to an existing matching profile or create a new one. It
must not offer an implicit rebind.

## Existing Data And Conflict Recovery

Migration or post-login reconciliation must not guess historical ownership.
For the confirmed malformed conflict:

- do not hard-delete the conflict history;
- after a valid account binding is established, mark an active conflict whose
  local profile binding does not match its conflict scope as `superseded`;
- keep the old Goal/tombstone in its original local profile;
- when account A is restored, synchronize using account A's correct cursor and
  server baseline;
- do not reset the version and upload the old record to account B.

The exact migration and reconciliation policy requires review before changing
the Flutter schema.

## UI Correction

Conflict actions need postcondition-aware results:

- `Pull completed` is not equivalent to `conflict hydrated`;
- the controller must reload the target conflict after hydration;
- success is shown only when the remote snapshot becomes actionable or the
  conflict resolves;
- an unchanged awaiting conflict should show a controlled explanation such as
  `当前账号下未找到对应的云端记录`;
- no raw Endpoint, cloud user ID, UUID, JSON, or Secret should be displayed.

## Proposed Next-Sprint Scope

The next Sprint should be a release-blocker correction, not Sprint 10C product
expansion. A candidate name is:

```text
Sprint 10B.2 — Cloud Account Local Data Binding
```

Potentially allowed:

- account-to-local-profile binding domain and persistence;
- active local-profile switching;
- explicit first-login bind/create choice;
- safe reconciliation of malformed conflicts;
- postcondition-aware hydration messages;
- migration and isolation tests;
- Windows and Android acceptance updates.

Keep out of scope:

- new Server API;
- API version or Sync Protocol changes;
- PostgreSQL/Alembic changes unless evaluation proves them necessary;
- Today, Journal, Health, Growth, or AI Report sync;
- automatic cross-account data transfer;
- hard deletion of old local data;
- background or realtime sync.

## Required Acceptance

At minimum, the correction must prove:

1. Account A local data is not visible while account B is active.
2. Account B cannot push, delete, or conflict on account A records.
3. Re-login to A restores A's local data and valid sync baselines.
4. Endpoint changes are isolated even when cloud user IDs happen to match.
5. Existing unbound data requires an explicit bind/create decision.
6. Logout does not erase the current local data space.
7. A malformed cross-scope conflict is safely superseded, not hard-deleted.
8. Ordinary Profile and Plan two-way sync still works.
9. Cursor, conflict, device, and session isolation do not regress.
10. Windows and Android restart preserve the selected data space.
11. No private data is silently copied to a new account.
12. Retry UI does not claim completion without a verified postcondition.

## Questions For Architecture Review

1. Is one local profile allowed to bind to more than one cloud identity?
2. Should a first login default to a new data space or require an explicit
   choice before proceeding?
3. What should signed-out mode display when multiple local profiles exist?
4. Is device installation ID global to the installation or local-profile
   scoped?
5. Should switching Endpoint automatically switch local data spaces?
6. How should existing unbound profiles be assigned during migration?
7. Should malformed cross-scope conflicts be marked `superseded` immediately
   after binding, or only after user confirmation?
8. Does the correction require Flutter `schemaVersion 4 -> 5`, or can a safer
   model reuse existing durable storage without weakening constraints?

## Release Decision

- Sprint 10B API deployment: PASS.
- Ordinary Plan cross-device baseline: partially PASS.
- Cloud-user isolation: FAIL.
- Persistent conflict recovery Release Gate: OPEN and blocked.
- Sprint 10C: do not start until this blocker is corrected and affected manual
  rows are rerun.
