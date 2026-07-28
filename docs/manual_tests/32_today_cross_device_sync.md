# Manual Test: Today Cross-device Synchronization

> Sprint: 11A
> Execution date: not executed
> Status: `NOT EXECUTED`
> Build: pending Sprint commit
> API image: pending Sprint commit
> Flutter schema: 7
> API: 1
> Sync Protocol: 2
> Environment: Development + Fake Provider + Tailscale private Alpha

Record only PASS, FAIL, or NOT EXECUTED. Do not record User Keys, tokens,
complete private endpoint values, Today note text, database copies, or raw
request JSON.

## Preconditions

- Install the Windows release build and arm64-v8a Android release APK.
- Deploy the exact Sprint API image while preserving the existing PostgreSQL
  container and volume.
- Confirm `/health` reports API `1` and Sync Protocol `2`.
- Register both devices under the same disposable account A.
- Keep a separate disposable account B for isolation checks.
- Start with no unresolved Today conflict for the test date.
- If a priority links to a Goal, manually synchronize Plan before Today.

## A. Windows To Android

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows creates Today with priorities, scores, minutes, and a note | NOT EXECUTED | - |
| 2 | Research minutes are left empty and learning minutes are explicitly `0` | NOT EXECUTED | - |
| 3 | Windows manually starts Today sync from Settings | NOT EXECUTED | - |
| 4 | The Today button disables while syncing and rejects repeated taps | NOT EXECUTED | - |
| 5 | Success reports honest upload, pull, delete, and conflict counts | NOT EXECUTED | - |
| 6 | Android manually pulls Today and shows the same date and record content | NOT EXECUTED | - |
| 7 | Android preserves empty research minutes as null and learning as `0` | NOT EXECUTED | - |
| 8 | Repeated Android sync creates no duplicate Today for the date | NOT EXECUTED | - |
| 9 | Windows and Android retain one shared Today record identity | NOT EXECUTED | - |

## B. Android To Windows

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Android changes a priority, completion state, score, duration, and note | NOT EXECUTED | - |
| 2 | Android manually uploads the changed Today | NOT EXECUTED | - |
| 3 | Windows manually pulls and displays the Android changes | NOT EXECUTED | - |
| 4 | A second two-way sync reports no duplicate upload or record | NOT EXECUTED | - |
| 5 | Restarting both apps retains the synchronized Today | NOT EXECUTED | - |
| 6 | A Goal-linked priority remains linked after Plan then Today sync | NOT EXECUTED | - |

## C. Health Isolation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows adds same-day Health values before Today sync | NOT EXECUTED | - |
| 2 | Android receives Today but not Windows Health values | NOT EXECUTED | - |
| 3 | Android adds different local Health values and syncs Today | NOT EXECUTED | - |
| 4 | Windows Today updates while Windows Health remains unchanged | NOT EXECUTED | - |
| 5 | Android Health remains unchanged after another Today pull | NOT EXECUTED | - |
| 6 | Journal, Growth, AI report state, and AI consent remain unchanged | NOT EXECUTED | - |

## D. Conflict And Delete Safety

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit the same synced Today before either pulls | NOT EXECUTED | - |
| 2 | The first device uploads successfully | NOT EXECUTED | - |
| 3 | The stale device receives a visible Today conflict | NOT EXECUTED | - |
| 4 | Stale local content is retained without automatic merge or overwrite | NOT EXECUTED | - |
| 5 | Conflict details show Today date and both available snapshots | NOT EXECUTED | - |
| 6 | The UI does not offer an unsafe silent resolution action | NOT EXECUTED | - |
| 7 | A remote tombstone removes the Today view only after successful pull | NOT EXECUTED | - |
| 8 | Same-day Health survives a remote Today tombstone | NOT EXECUTED | - |
| 9 | Independent same-date creation is rejected without deleting either local draft | NOT EXECUTED | - |

## E. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A Today is visible on registered account A devices | NOT EXECUTED | - |
| 2 | After logout, Today sync state resets and no automatic sync starts | NOT EXECUTED | - |
| 3 | Account B cannot see or pull account A Today | NOT EXECUTED | - |
| 4 | Account B cannot upload into account A cloud scope | NOT EXECUTED | - |
| 5 | Endpoint or cloud-user binding mismatch blocks before network work | NOT EXECUTED | - |
| 6 | `legacy_review_required` disables Today sync | NOT EXECUTED | - |
| 7 | Verified `ready` state enables Today sync without starting it automatically | NOT EXECUTED | - |
| 8 | Account switching changes neither Profile nor Plan cursor through Today sync | NOT EXECUTED | - |

## F. Failure, Retry, And Cursor

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline Today sync reports failure and keeps local form content | NOT EXECUTED | - |
| 2 | Reconnecting and retrying succeeds without duplicate records | NOT EXECUTED | - |
| 3 | App restart after failure preserves local content and retryability | NOT EXECUTED | - |
| 4 | Invalid or missing Goal reference does not partially apply a pull | NOT EXECUTED | - |
| 5 | Failed remote apply does not hide later cloud changes | NOT EXECUTED | - |
| 6 | A successful retry receives the same unapplied cloud page | NOT EXECUTED | - |
| 7 | Today sync does not change Profile or Plan sync status | NOT EXECUTED | - |

## G. UI Regression

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows Settings shows readable idle, syncing, success, conflict, and failed states | NOT EXECUTED | - |
| 2 | Android portrait Settings has no horizontal overflow | NOT EXECUTED | - |
| 3 | Android maximum font remains readable and scrollable | NOT EXECUTED | - |
| 4 | Back navigation during idle or after failure remains safe | NOT EXECUTED | - |
| 5 | Today form still saves locally without Widget database access | NOT EXECUTED | - |
| 6 | No startup, background, scheduled, or automatic sync is observed | NOT EXECUTED | - |
| 7 | No crash, hidden primary action, or silent data loss occurs | NOT EXECUTED | - |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows to Android | 0 | 0 | 9 |
| Android to Windows | 0 | 0 | 6 |
| Health isolation | 0 | 0 | 6 |
| Conflict and delete safety | 0 | 0 | 9 |
| Account boundary | 0 | 0 | 8 |
| Failure, retry, and cursor | 0 | 0 | 7 |
| UI regression | 0 | 0 | 7 |
| **Total** | **0** | **0** | **52** |

Release Gate: `OPEN / NOT EXECUTED`.

Do not mark this gate accepted from automated tests alone. A FAIL in account
isolation, conflict preservation, Health isolation, duplicate prevention, or
cursor retry is release-blocking.
