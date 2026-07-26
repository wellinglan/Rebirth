# Manual Test: Account Boundary And Local Data Isolation

> Sprint: 10B.2-A foundation + 10B.2-B ownership resolution
> Initial status: all rows are `NOT EXECUTED`
> Environment: Development + Fake Provider + Tailscale private Alpha
> Flutter schema: 6

This matrix closes `ACCOUNT-DATA-ISOLATION-001` and
`PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001`. Automated tests do not replace it. Do
not record Development User Keys, tokens, full Endpoint values, full cloud or
device IDs, private Profile text, or private Goal text as evidence.

The explicit legacy claim and fresh-space workflow is executed in
`docs/manual_tests/28_legacy_local_data_resolution.md`. Results from that
matrix must be referenced here without replacing any existing real status.

## Preconditions

1. Deploy the current compatible Alpha API; API `1` and Sync Protocol `2` are
   unchanged by this Sprint.
2. Build and install the matching Windows release and arm64-v8a Android APK.
3. Prepare two disposable Development User Keys, referred to as A and B.
4. Confirm both devices can reach the same private Alpha Endpoint.
5. Back up any important pre-Sprint local database before testing migration.
6. For clean-install rows, use a test installation with no legacy Profile.
7. Record commit SHA, build paths, API image tag, device model, Android
   version, and test date without recording Secrets.

## Build And Environment

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | `/health` reports status ok, API 1, Sync Protocol 2 | NOT EXECUTED | - | - |
| 2 | Windows release matches the Sprint commit and launches | NOT EXECUTED | - | - |
| 3 | Android arm64-v8a release matches the Sprint commit and launches | NOT EXECUTED | - | - |
| 4 | Fresh startup shows Auth Gate instead of a business page | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Login page can configure and persist the private Alpha Endpoint | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Build and environment total: `0 PASS / 0 FAIL / 5 NOT EXECUTED`.

## Windows Account Isolation

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Signed out access to Today, Journal, Plan, Health, Growth, or AI redirects to login | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Login A, create a root Goal and child Goal, then sync | NOT EXECUTED | - | - |
| 3 | Restart while A is signed in and verify A data remains | NOT EXECUTED | - | - |
| 4 | Logout does not delete A data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Login B and verify A Profile and Goals are not visible | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Sync B and verify no A Goal upload, deletion, or conflict occurs | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 7 | Create and sync a distinct B Goal | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Logout B, login A, and verify A data returns without B data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 9 | Sync A and verify its prior server baseline remains valid | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 10 | Switch repeatedly A -> B -> A with no duplicate Profile or Goal | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 11 | Offline restart with a valid A binding enters authenticated-offline mode | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 12 | Invalid or rejected session cannot enter business pages | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Windows total: `0 PASS / 0 FAIL / 12 NOT EXECUTED`.

## Android Account Isolation

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Fresh install shows login and does not create anonymous business data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Configure LAN/Tailscale Endpoint from the login page | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Login A, create and sync a Goal | NOT EXECUTED | - | - |
| 4 | Logout A, login B, and verify A data is absent | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Sync B and verify no A mutation or conflict occurs | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 6 | Create a B Goal, restart, and verify only B data remains active | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 7 | Login A again and verify A data returns without B data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Android Back cannot bypass the Auth Gate | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 9 | Maximum font size keeps login, migration status, and logout controls usable | NOT EXECUTED | - | - |
| 10 | No abnormal exit or horizontal overflow occurs | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Cross-device Isolation

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows A Goal syncs to Android A with correct hierarchy | NOT EXECUTED | - | - |
| 2 | Android A update syncs back to Windows A without duplicates | NOT EXECUTED | - | - |
| 3 | Switch Android to B; A data and conflicts are not visible | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | Android B Goal syncs to Windows B only | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Windows B update syncs back to Android B without A data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Switching both devices back to A restores only A data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 7 | Same cloud user on a different Endpoint cannot reuse the first Endpoint data space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 8 | Account or Endpoint mismatch never advances cursor | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 9 | Account or Endpoint mismatch never creates a new conflict | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 10 | Today, Journal, and Health remain outside cloud sync | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Legacy Migration And Conflict History

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Upgrade a schema 4 database containing Profile and Plan data | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Existing Profile and Goals remain on disk after upgrade | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Existing unbound data shows `bindingRequired` and is not auto-bound | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | `bindingRequired` cannot enter business pages or start sync | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 5 | Existing cursor and AI pending data remain preserved | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Old awaiting conflict remains as non-actionable superseded history | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 7 | Superseded conflict retains snapshots, timestamps, and reason | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 8 | Superseded conflict is not counted as active | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 9 | No server version is cleared and no legacy row is uploaded to a new account | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 10 | No Profile, Goal, conflict, cursor, or AI pending row is hard-deleted | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Migration total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Failure Protection

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Interrupt account activation and verify the previous active state rolls back | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 2 | Force cloud-user mismatch and verify push/pull are refused | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 3 | Force Endpoint mismatch and verify push/pull are refused | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 4 | Guard failure leaves cursor, conflicts, and local sync metadata unchanged | NOT EXECUTED | - | PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001 |
| 5 | Network loss preserves the current bound local data space | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |
| 6 | Restored network permits retry under the same account scope | NOT EXECUTED | - | ACCOUNT-DATA-ISOLATION-001 |

Failure protection total: `0 PASS / 0 FAIL / 6 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Build and environment | 0 | 0 | 5 |
| Windows | 0 | 0 | 12 |
| Android | 0 | 0 | 10 |
| Cross-device | 0 | 0 | 10 |
| Legacy migration | 0 | 0 | 10 |
| Failure protection | 0 | 0 | 6 |
| **Total** | **0** | **0** | **53** |

Release Gate: `OPEN / NOT EXECUTED`.

Do not close `ACCOUNT-DATA-ISOLATION-001` or
`PLAN-SYNC-CLOUD-SCOPE-TOMBSTONE-001` until all required rows pass or every
exception has an approved defect disposition.
