# Manual Test: Journal Cross-device Synchronization

> Sprint: 11B
> Status: FAIL - transport allowlist fix pending manual retest
> Baseline: `3be1632b75a42928d20eb54b804a729c02742936`
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

Record only `PASS`, `FAIL`, or `NOT EXECUTED`. Automated evidence does not
count as manual PASS. Do not record a User Key, token, complete private
Endpoint, Journal answer text, raw payload, database copy, or private UUID.

## Preconditions

- Install the exact Windows release and arm64-v8a Android release APK.
- Deploy the exact Sprint API image without rebuilding PostgreSQL or deleting
  its volume.
- Confirm `/health` reports API 1 and Sync Protocol 2.
- Use one disposable verified account on both registered devices.
- Confirm Profile, Plan, Today, and Journal manual sync actions are available.

## A. Windows Create, Edit, Delete

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Create a Journal with at least one answer | NOT EXECUTED | |
| 2 | Manual Journal sync uploads one record | FAIL | Pre-fix client rejected `journal_entries` before the request; allowlist fix pending retest |
| 3 | Repeat sync creates no duplicate | NOT EXECUTED | |
| 4 | Edit long Journal content and sync | NOT EXECUTED | |
| 5 | Delete requires explicit confirmation | NOT EXECUTED | |
| 6 | Delete remains local until manual sync | NOT EXECUTED | |
| 7 | Manual sync uploads the tombstone | NOT EXECUTED | |

## B. Android Round Trip

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Android pulls the Windows Journal | NOT EXECUTED | |
| 2 | Date, status, and all answers are preserved | NOT EXECUTED | |
| 3 | No duplicate active Journal exists for the date | NOT EXECUTED | |
| 4 | Android edits and manually syncs | NOT EXECUTED | |
| 5 | Windows pulls the Android edit | NOT EXECUTED | |
| 6 | Android pulls the Windows tombstone and hides the entry | NOT EXECUTED | |
| 7 | Restart preserves the synchronized result | NOT EXECUTED | |

## C. Conflict Recovery

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit the same synchronized Journal offline | NOT EXECUTED | |
| 2 | First upload succeeds and second reports a conflict | NOT EXECUTED | |
| 3 | Hydration does not overwrite local content | NOT EXECUTED | |
| 4 | Journal summaries contain no Plan/Today wording | NOT EXECUTED | |
| 5 | Keep Local requires confirmation | NOT EXECUTED | |
| 6 | Keep Local makes both devices converge after sync | NOT EXECUTED | |
| 7 | A recreated conflict supports Adopt Remote | NOT EXECUTED | |
| 8 | Adopt Remote makes both devices converge | NOT EXECUTED | |
| 9 | Delete-versus-edit conflict remains explicit | NOT EXECUTED | |
| 10 | Requested recovery survives app restart and remains retryable | NOT EXECUTED | |

## D. Failure, Cursor, And Isolation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline manual sync fails without losing local Journal | NOT EXECUTED | |
| 2 | Reconnect and explicit retry succeeds | NOT EXECUTED | |
| 3 | Repeated taps do not start parallel runs | NOT EXECUTED | |
| 4 | Failed pull does not skip the remote Journal on retry | NOT EXECUTED | |
| 5 | Profile, Plan, and Today cursors/results remain unchanged | NOT EXECUTED | |
| 6 | Different account cannot pull this account's Journal | NOT EXECUTED | |
| 7 | Health, Growth, and AI data remain local-only | NOT EXECUTED | |

## E. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Settings shows Journal status and latest sync time | NOT EXECUTED | |
| 2 | Shared conflict entry opens Journal conflict details | NOT EXECUTED | |
| 3 | Long answers remain readable and scrollable | NOT EXECUTED | |
| 4 | Android portrait and landscape have no overflow | NOT EXECUTED | |
| 5 | Maximum font keeps summaries and actions operable | NOT EXECUTED | |
| 6 | Windows narrow and wide layouts remain usable | NOT EXECUTED | |
| 7 | Back and cancel make no data change | NOT EXECUTED | |
| 8 | No raw JSON, full UUID, token, or Endpoint is exposed | NOT EXECUTED | |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows create/edit/delete | 0 | 1 | 6 |
| Android round trip | 0 | 0 | 7 |
| Conflict recovery | 0 | 0 | 10 |
| Failure/cursor/isolation | 0 | 0 | 7 |
| UI/accessibility | 0 | 0 | 8 |
| **Total** | **0** | **1** | **38** |

Journal Sync Product Gate: `OPEN / MANUAL ACCEPTANCE REQUIRED`.
