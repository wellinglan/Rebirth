# Manual Test: Today Cross-device Synchronization

> Sprint: 11A
> Execution date: 2026-07-28
> Status: partially executed; all exercised paths passed
> Build: `159974f04ae2bc8edda28252e667a0faad013e2f`
> API image: `ghcr.io/wellinglan/rebirth-api:159974f04ae2bc8edda28252e667a0faad013e2f`
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

The tester confirmed that the updated API was healthy, the PostgreSQL
container was preserved, Windows and Android used the release clients, and
every exercised scenario below behaved as expected. Rows that require an
unsupported deletion action, internal cursor inspection, a legacy quarantine
fixture, or a second endpoint remain `NOT EXECUTED`; automated PASS is not
reported as manual PASS.

## A. Windows To Android

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows creates Today with priorities, scores, minutes, and a note | PASS | Windows saved the prepared Today |
| 2 | Research minutes are left empty and learning minutes are explicitly `0` | PASS | Null and zero remained distinct |
| 3 | Windows manually starts Today sync from Settings | PASS | Manual sync completed |
| 4 | The Today button disables while syncing and rejects repeated taps | PASS | Busy state prevented duplicate execution |
| 5 | Success reports honest upload, pull, delete, and conflict counts | PASS | Result counts were displayed |
| 6 | Android manually pulls Today and shows the same date and record content | PASS | Android received the Windows Today |
| 7 | Android preserves empty research minutes as null and learning as `0` | PASS | Android preserved both values |
| 8 | Repeated Android sync creates no duplicate Today for the date | PASS | No duplicate appeared |
| 9 | Windows and Android retain one shared Today record identity | PASS | Cross-device updates targeted one record |

## B. Android To Windows

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Android changes a priority, completion state, score, duration, and note | PASS | Android saved the prepared changes |
| 2 | Android manually uploads the changed Today | PASS | Manual upload completed |
| 3 | Windows manually pulls and displays the Android changes | PASS | Windows received Android changes |
| 4 | A second two-way sync reports no duplicate upload or record | PASS | No duplicate appeared |
| 5 | Restarting both apps retains the synchronized Today | PASS | Both clients retained data |
| 6 | A Goal-linked priority remains linked after Plan then Today sync | PASS | Plan-first linked priority remained valid |

## C. Health Isolation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows adds same-day Health values before Today sync | PASS | Windows Health was prepared locally |
| 2 | Android receives Today but not Windows Health values | PASS | Windows Health did not cross devices |
| 3 | Android adds different local Health values and syncs Today | PASS | Android Health remained local |
| 4 | Windows Today updates while Windows Health remains unchanged | PASS | Windows Health was preserved |
| 5 | Android Health remains unchanged after another Today pull | PASS | Android Health was preserved |
| 6 | Journal, Growth, AI report state, and AI consent remain unchanged | PASS | No unrelated state changed |

## D. Conflict And Delete Safety

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices edit the same synced Today before either pulls | PASS | Competing local edits were prepared |
| 2 | The first device uploads successfully | PASS | First upload completed |
| 3 | The stale device receives a visible Today conflict | PASS | Conflict was shown |
| 4 | Stale local content is retained without automatic merge or overwrite | PASS | Stale local content remained |
| 5 | Conflict details show Today date and both available snapshots | PASS | Both summaries were readable |
| 6 | The UI does not offer an unsafe silent resolution action | PASS | No destructive action was offered |
| 7 | A remote tombstone removes the Today view only after successful pull | NOT EXECUTED | - |
| 8 | Same-day Health survives a remote Today tombstone | NOT EXECUTED | - |
| 9 | Independent same-date creation is rejected without deleting either local draft | NOT EXECUTED | - |

## E. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A Today is visible on registered account A devices | PASS | Account A devices shared Today |
| 2 | After logout, Today sync state resets and no automatic sync starts | PASS | Logout reset state without syncing |
| 3 | Account B cannot see or pull account A Today | PASS | Account A Today stayed isolated |
| 4 | Account B cannot upload into account A cloud scope | PASS | Account scopes remained separate |
| 5 | Endpoint or cloud-user binding mismatch blocks before network work | NOT EXECUTED | - |
| 6 | `legacy_review_required` disables Today sync | NOT EXECUTED | - |
| 7 | Verified `ready` state enables Today sync without starting it automatically | PASS | Ready state exposed only manual sync |
| 8 | Account switching changes neither Profile nor Plan cursor through Today sync | PASS | Profile and Plan visible state was unchanged |

## F. Failure, Retry, And Cursor

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Offline Today sync reports failure and keeps local form content | PASS | Offline failure preserved input |
| 2 | Reconnecting and retrying succeeds without duplicate records | PASS | Retry succeeded once |
| 3 | App restart after failure preserves local content and retryability | PASS | Restart retained local state |
| 4 | Invalid or missing Goal reference does not partially apply a pull | NOT EXECUTED | - |
| 5 | Failed remote apply does not hide later cloud changes | NOT EXECUTED | - |
| 6 | A successful retry receives the same unapplied cloud page | NOT EXECUTED | - |
| 7 | Today sync does not change Profile or Plan sync status | PASS | Other sync states stayed unchanged |

## G. UI Regression

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows Settings shows readable idle, syncing, success, conflict, and failed states | PASS | States remained readable |
| 2 | Android portrait Settings has no horizontal overflow | PASS | No overflow observed |
| 3 | Android maximum font remains readable and scrollable | PASS | Maximum font remained operable |
| 4 | Back navigation during idle or after failure remains safe | PASS | Back navigation was safe |
| 5 | Today form still saves locally without Widget database access | PASS | Local save remained functional |
| 6 | No startup, background, scheduled, or automatic sync is observed | PASS | Only manual sync occurred |
| 7 | No crash, hidden primary action, or silent data loss occurs | PASS | No blocking UI or data loss observed |

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows to Android | 9 | 0 | 0 |
| Android to Windows | 6 | 0 | 0 |
| Health isolation | 6 | 0 | 0 |
| Conflict and delete safety | 6 | 0 | 3 |
| Account boundary | 6 | 0 | 2 |
| Failure, retry, and cursor | 4 | 0 | 3 |
| UI regression | 7 | 0 | 0 |
| **Total** | **44** | **0** | **8** |

Release Gate: `OPEN / PARTIAL ACCEPTANCE`.

All exercised Windows, Android, cross-device, account isolation, retry, and UI
paths passed. The remaining eight rows require unsupported Today deletion,
independent same-date creation not exercised in this run, a second endpoint,
a legacy quarantine fixture, or internal apply/cursor inspection. Automated
coverage for those paths remains green but is not counted as manual PASS.

## Sprint 11A.1 Follow-up

This document remains the historical Sprint 11A result:
`44 PASS / 0 FAIL / 8 NOT EXECUTED`. Do not rewrite those rows.

Explicit deletion, tombstone recovery, adopt remote, keep local, and same-date
different-UUID convergence are evaluated in
`docs/manual_tests/33_today_conflict_recovery.md`. Internal cursor, rollback,
guard, and replay results remain automated evidence, not manual PASS here.
