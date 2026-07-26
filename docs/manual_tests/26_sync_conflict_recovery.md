# Manual Test: Persistent Sync Conflict Recovery

> Sprint: 10B.1
> Initial status: all rows are `NOT EXECUTED`
> Environment: Development + Fake Provider + Tailscale private Alpha
> Phone model: OnePlus 15T (`一加15T`)
> Android software version: `PLZ110_16.0.9.400`

Automated tests do not replace this matrix. Do not record tokens, secrets,
public IP addresses, full Endpoint values, full cloud user IDs, full device
IDs, or private Goal text as evidence.

## Preconditions

1. Confirm Sprint 10B API is deployed to Beijing Alpha.
2. Confirm `/health` reports `status=ok`, API `1`, Sync Protocol `2`, and
   `environment=development`.
3. Use the matching Windows release and arm64-v8a Android release.
4. Sign in with the same Development User Key and register both devices.
5. Keep a second Development User Key and a second test Endpoint scope for
   isolation checks.
6. Record actual device model and Android version before execution.

## Execution Context

Recorded on 2026-07-26:

- Sprint 10B API deployment: verified.
- Alpha API container: `healthy`.
- API image:
  `ghcr.io/wellinglan/rebirth-api:713f46a71ab5aa46be45ae62051a366859ab9a39`.
- `/health`: `status=ok`, service `rebirth-api`, API `1`, Sync Protocol `2`,
  environment `development`.
- Windows release: launched successfully.
- Matching arm64-v8a release APK: installed.
- Windows and Android: signed in with the same Development User Key and
  registered as separate devices.

## Windows

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Produce a same-Goal Plan conflict | NOT EXECUTED | - | - |
| 2 | Settings shows the correct active conflict count | PASS | Settings showed one active conflict after the stale tombstone push | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 3 | Open conflict list and matching details | PASS | Conflict details opened for the deleted local Goal | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 4 | Local and server summaries are readable without raw JSON or long IDs | PASS | Details showed readable local deletion and pending remote summary | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 5 | Cancel adopt-server and verify no data changes | NOT EXECUTED | - | - |
| 6 | Cancel keep-local and verify no data changes | NOT EXECUTED | - | - |
| 7 | Restart the app and verify the conflict remains | NOT EXECUTED | - | - |
| 8 | Narrow window has no horizontal overflow | NOT EXECUTED | - | - |
| 9 | Tab focuses actions; Enter and Space activate them | NOT EXECUTED | - | - |
| 10 | Profile manual sync still works | NOT EXECUTED | - | - |

Windows total: `3 PASS / 0 FAIL / 7 NOT EXECUTED`.

## Android Physical Device

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Install the matching arm64-v8a release APK | PASS | Matching arm64-v8a release installed on OnePlus 15T | - |
| 2 | Produce a same-Goal conflict and verify the count | NOT EXECUTED | - | - |
| 3 | Open list and details; Android Back returns normally | NOT EXECUTED | - | - |
| 4 | Maximum font size remains scrollable without overflow | NOT EXECUTED | - | - |
| 5 | Restart preserves the active conflict | NOT EXECUTED | - | - |
| 6 | Adopt server current version succeeds | NOT EXECUTED | - | - |
| 7 | Keep current local version succeeds | NOT EXECUTED | - | - |
| 8 | Offline failure preserves local content and requested state | NOT EXECUTED | - | - |
| 9 | Restored network allows a manual retry | NOT EXECUTED | - | - |
| 10 | No abnormal exit occurs | NOT EXECUTED | - | - |

Android total: `1 PASS / 0 FAIL / 9 NOT EXECUTED`.

## Cross-device Recovery

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows and Android edit the same synced Goal | NOT EXECUTED | - | - |
| 2 | Later-syncing device reports conflict and keeps local content | NOT EXECUTED | - | - |
| 3 | Conflict pull does not advance the Plan cursor | NOT EXECUTED | - | - |
| 4 | Adopt server converges both devices | NOT EXECUTED | - | - |
| 5 | Keep local converges both devices | NOT EXECUTED | - | - |
| 6 | Network failure can be retried without losing intent | NOT EXECUTED | - | - |
| 7 | App restart can continue a requested resolution | NOT EXECUTED | - | - |
| 8 | Remote tombstone can be adopted | NOT EXECUTED | - | - |
| 9 | Local tombstone can be kept and uploaded | NOT EXECUTED | - | - |
| 10 | Parent/child recovery creates no orphan | NOT EXECUTED | - | - |
| 11 | Parent/child recovery creates no cycle | NOT EXECUTED | - | - |
| 12 | Archive and restore metadata remain intact | NOT EXECUTED | - | - |
| 13 | Different Development User Key cannot see the conflict | FAIL | New cloud user received a conflict derived from Goal sync metadata bound to the earlier User Key | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 14 | Different Endpoint cannot see the conflict | NOT EXECUTED | - | - |
| 15 | Today, Journal, and Health remain unsynchronized | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 1 FAIL / 14 NOT EXECUTED`.

## Recovery State Checks

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Push stale first shows that server details must be fetched | PASS | Deleted local Goal entered `awaiting_remote_snapshot` with retry action | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 2 | Manual retry hydrates the remote upsert summary | NOT EXECUTED | - | - |
| 3 | Manual retry hydrates a remote tombstone without fake title | NOT EXECUTED | - | - |
| 4 | Editing locally after conflict shows the local-changed notice | NOT EXECUTED | - | - |
| 5 | Keep-local uses that latest local edit | NOT EXECUTED | - | - |
| 6 | Resolved conflict disappears from the active count | NOT EXECUTED | - | - |
| 7 | A later higher-version conflict creates a new active item | NOT EXECUTED | - | - |
| 8 | Logout hides conflict rows without deleting them | NOT EXECUTED | - | - |
| 9 | Re-login to the same scope restores the rows | NOT EXECUTED | - | - |

Recovery-state total: `1 PASS / 0 FAIL / 8 NOT EXECUTED`.

## Observed Defects

### PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001

- Status: `CONFIRMED RELEASE BLOCKER`.
- Observed on: Windows, 2026-07-26.
- Trigger: delete a local Goal that predates registration of the current
  Development cloud user, then run Plan sync.
- Actual result: one conflict was persisted with a local tombstone and
  `awaiting_remote_snapshot`; the cloud summary had no current version.
- Safety result: local deletion was preserved and the ordinary root/child
  cross-device round trip remained successful.
- Confirmed boundary: the Goal had synchronized under an earlier Development
  User Key. Its nonzero `serverVersion` survived the cloud-user change, while
  the newly registered cloud user had no matching remote record.
- Retry result: the UI reported that the conflict operation completed, but the
  count remained one, the state remained `awaiting_remote_snapshot`, the remote
  summary stayed empty, and no adopt/keep action became available.
- Stability result: the local tombstone remained intact and Settings/Plan
  navigation continued normally.
- Release impact: the Release Gate remains `OPEN`.

## Acceptance Status

- Sprint 10B Alpha API deployment: `PASS`.
- Windows: `IN PROGRESS (3 PASS / 0 FAIL / 7 NOT EXECUTED)`.
- Android physical device: `IN PROGRESS (1 PASS / 0 FAIL / 9 NOT EXECUTED)`.
- Cross-device recovery: `IN PROGRESS (0 PASS / 1 FAIL / 14 NOT EXECUTED)`.
- Recovery-state checks: `IN PROGRESS (1 PASS / 0 FAIL / 8 NOT EXECUTED)`.
- Release Gate: `OPEN`, blocked by
  `PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001`.
