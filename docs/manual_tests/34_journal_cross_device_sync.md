# Manual Test: Journal Cross-device Synchronization

> Sprint: 11B
> Status: PASS - Windows and Android manual acceptance completed
> Manual acceptance date: 2026-07-28
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
| 1 | Create a Journal with at least one answer | PASS | |
| 2 | Manual Journal sync uploads one record | PASS | Retested with transport allowlist fix `5517218`; `journal_entries` reaches the sync API |
| 3 | Repeat sync creates no duplicate | PASS | |
| 4 | Edit long Journal content and sync | PASS | |
| 5 | Delete requires explicit confirmation | PASS | |
| 6 | Delete remains local until manual sync | PASS | |
| 7 | Manual sync uploads the tombstone | PASS | |

## B. Android Round Trip

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Android pulls the Windows Journal | PASS | |
| 2 | Date, status, and all answers are preserved | PASS | |
| 3 | No duplicate active Journal exists for the date | PASS | |
| 4 | Android edits and manually syncs | PASS | |
| 5 | Windows pulls the Android edit | PASS | |
| 6 | Android pulls the Windows tombstone and hides the entry | PASS | |
| 7 | Restart preserves the synchronized result | PASS | |

## C. Conflict Recovery

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit the same synchronized Journal offline | PASS | |
| 2 | First upload succeeds and second reports a conflict | PASS | |
| 3 | Hydration does not overwrite local content | PASS | |
| 4 | Journal summaries contain no Plan/Today wording | PASS | |
| 5 | Keep Local requires confirmation | PASS | |
| 6 | Keep Local makes both devices converge after sync | PASS | |
| 7 | A recreated conflict supports Adopt Remote | PASS | |
| 8 | Adopt Remote makes both devices converge | PASS | |
| 9 | Delete-versus-edit conflict remains explicit | PASS | |
| 10 | Requested recovery survives app restart and remains retryable | PASS | |

## D. Failure, Cursor, And Isolation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline manual sync fails without losing local Journal | PASS | |
| 2 | Reconnect and explicit retry succeeds | PASS | |
| 3 | Repeated taps do not start parallel runs | PASS | |
| 4 | Failed pull does not skip the remote Journal on retry | PASS | |
| 5 | Profile, Plan, and Today cursors/results remain unchanged | PASS | |
| 6 | Different account cannot pull this account's Journal | PASS | |
| 7 | Health, Growth, and AI data remain local-only | PASS | |

## E. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Settings shows Journal status and latest sync time | PASS | |
| 2 | Shared conflict entry opens Journal conflict details | PASS | |
| 3 | Long answers remain readable and scrollable | PASS | |
| 4 | Android portrait and landscape have no overflow | PASS | |
| 5 | Maximum font keeps summaries and actions operable | PASS | |
| 6 | Windows narrow and wide layouts remain usable | PASS | |
| 7 | Back and cancel make no data change | PASS | |
| 8 | No raw JSON, full UUID, token, or Endpoint is exposed | PASS | |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows create/edit/delete | 7 | 0 | 0 |
| Android round trip | 7 | 0 | 0 |
| Conflict recovery | 10 | 0 | 0 |
| Failure/cursor/isolation | 7 | 0 | 0 |
| UI/accessibility | 8 | 0 | 0 |
| **Total** | **39** | **0** | **0** |

Journal Sync Product Gate: `PASS / CLOSED`.
