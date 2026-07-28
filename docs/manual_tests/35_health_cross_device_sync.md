# Manual Test: Health Cross-device Synchronization

> Sprint: 11C
> Status: NOT EXECUTED
> Baseline: `d6ac3166f90638582495864da77cf8076a799fd6`
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

Record only `PASS`, `FAIL`, or `NOT EXECUTED`. Automated evidence does not
count as manual PASS. Do not record a User Key, token, complete private
Endpoint, Health metric, Health note, raw payload, database copy, or private
UUID.

## Preconditions

- Install the exact Windows release and arm64-v8a Android release APK.
- Deploy the exact Sprint API image without rebuilding PostgreSQL or deleting
  its volume.
- Confirm `/health` reports API 1 and Sync Protocol 2.
- Use one disposable verified account on both registered devices.
- Confirm Profile, Plan, Today, Journal, and Health manual sync actions are
  available.

## A. Basic Cross-device Sync

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows creates a Health record | NOT EXECUTED | |
| 2 | Windows manual Health sync uploads one record | NOT EXECUTED | |
| 3 | Repeated sync creates no duplicate | NOT EXECUTED | |
| 4 | Android pulls the Windows Health record | NOT EXECUTED | |
| 5 | Android shows the same date and stored fields | NOT EXECUTED | |
| 6 | Android edits the record and manually syncs | NOT EXECUTED | |
| 7 | Windows pulls the Android edit | NOT EXECUTED | |
| 8 | Restart preserves the synchronized result | NOT EXECUTED | |

## B. Delete And Tombstone

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Health deletion requires explicit confirmation | NOT EXECUTED | |
| 2 | Delete remains local until manual sync | NOT EXECUTED | |
| 3 | Manual sync uploads a tombstone | NOT EXECUTED | |
| 4 | The other device pulls and hides the deleted record | NOT EXECUTED | |
| 5 | Repeated tombstone sync is idempotent | NOT EXECUTED | |
| 6 | A new Health record on another date still syncs | NOT EXECUTED | |

## C. Conflict Recovery

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit the same synchronized Health offline | NOT EXECUTED | |
| 2 | First upload succeeds and second reports a conflict | NOT EXECUTED | |
| 3 | Hydration does not overwrite local Health | NOT EXECUTED | |
| 4 | Conflict summaries hide metrics and notes | NOT EXECUTED | |
| 5 | Keep Local requires confirmation | NOT EXECUTED | |
| 6 | Keep Local makes both devices converge | NOT EXECUTED | |
| 7 | A recreated conflict supports Adopt Remote | NOT EXECUTED | |
| 8 | Adopt Remote makes both devices converge | NOT EXECUTED | |
| 9 | Delete-versus-edit remains explicit | NOT EXECUTED | |
| 10 | Requested recovery survives restart and is retryable | NOT EXECUTED | |

## D. Today Independence

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Delete the same-day Today record | NOT EXECUTED | |
| 2 | The Health record remains available | NOT EXECUTED | |
| 3 | Health continues to synchronize without Today | NOT EXECUTED | |
| 4 | Health conflict resolution does not change Today | NOT EXECUTED | |
| 5 | Today synchronization does not upload Health | NOT EXECUTED | |

## E. Failure, Cursor, And Account Isolation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline sync fails without losing local Health | NOT EXECUTED | |
| 2 | Reconnect and explicit retry succeeds | NOT EXECUTED | |
| 3 | Repeated taps do not start parallel runs | NOT EXECUTED | |
| 4 | Failed pull does not skip the remote record on retry | NOT EXECUTED | |
| 5 | Other entity cursors and results remain unchanged | NOT EXECUTED | |
| 6 | A different account cannot pull this account's Health | NOT EXECUTED | |
| 7 | Endpoint mismatch stops before sync work | NOT EXECUTED | |

## F. UI, Accessibility, And Privacy

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Settings shows Health state and latest sync time | NOT EXECUTED | |
| 2 | Shared conflict entry opens Health conflict details | NOT EXECUTED | |
| 3 | Android portrait and landscape have no overflow | NOT EXECUTED | |
| 4 | Android maximum font keeps actions operable | NOT EXECUTED | |
| 5 | Windows narrow and wide layouts remain usable | NOT EXECUTED | |
| 6 | Back and cancel make no data change | NOT EXECUTED | |
| 7 | No metric, note, raw JSON, full UUID, token, or Endpoint leaks | NOT EXECUTED | |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Basic cross-device sync | 0 | 0 | 8 |
| Delete/tombstone | 0 | 0 | 6 |
| Conflict recovery | 0 | 0 | 10 |
| Today independence | 0 | 0 | 5 |
| Failure/cursor/isolation | 0 | 0 | 7 |
| UI/accessibility/privacy | 0 | 0 | 7 |
| **Total** | **0** | **0** | **43** |

Health Sync Product Gate: `OPEN / NOT EXECUTED`.
