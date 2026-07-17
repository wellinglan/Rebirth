# AI Reliability Release Gate

Record only observed manual behavior. Automated tests and APK compilation do not convert a device step to PASS.

## Environment Record

| Item | Result | Notes |
|---|---|---|
| Windows build/start | PASS | Final debug build started, exposed Dart VM Service, and exited normally on 2026-07-17. |
| Automated single-worker Fake full-stack | PASS | Real Uvicorn + JWT + Dio + Ledger + Fake Provider + Drift test passed; this is not the manual Windows matrix. |
| PostgreSQL integration | PASS | Local PostgreSQL 17.10; Alembic head and 7 PostgreSQL marker tests passed, including four spawned Claim processes. Test database/role were removed afterward. |
| Uvicorn multi-worker HTTP | PASS | 2 workers, 8 duplicate HTTP requests, 1 Ledger row, 1 provider-start event, final completed; port/workers cleaned. |
| Android debug APK build | PASS | `flutter build apk --debug` completed on 2026-07-17; physical-device rows remain NOT EXECUTED. |
| OpenAI real smoke | NOT EXECUTED | Optional paid test; never part of normal CI. |
| CI Server SQLite | NOT EXECUTED | Workflow is present but has not been pushed/executed by GitHub. |
| CI PostgreSQL | NOT EXECUTED | Workflow is present but has not been pushed/executed by GitHub. |
| CI Flutter | NOT EXECUTED | Workflow is present but has not been pushed/executed by GitHub. |
| CI Android build | NOT EXECUTED | Workflow is present but has not been pushed/executed by GitHub. |

## Windows Manual Matrix

| # | Scenario | Result | Evidence | Defect ID |
|---:|---|---|---|---|
| 1 | Fake success | NOT EXECUTED | No interactive Windows session recorded. | - |
| 2 | Fake Provider timeout | NOT EXECUTED | No interactive Windows session recorded. | - |
| 3 | Client network interruption | NOT EXECUTED | No interactive Windows session recorded. | - |
| 4 | Status GET after network recovery | NOT EXECUTED | No interactive Windows session recorded. | - |
| 5 | Completed recovery | NOT EXECUTED | No interactive Windows session recorded. | - |
| 6 | Failed recovery | NOT EXECUTED | No interactive Windows session recorded. | - |
| 7 | Active processing | NOT EXECUTED | No interactive Windows session recorded. | - |
| 8 | Stale processing to outcome_unknown | NOT EXECUTED | No interactive Windows session recorded. | - |
| 9 | Result expired | NOT EXECUTED | No interactive Windows session recorded. | - |
| 10 | Not-found user confirmation | NOT EXECUTED | No interactive Windows session recorded. | - |
| 11 | Endpoint mismatch | NOT EXECUTED | No interactive Windows session recorded. | - |
| 12 | Account mismatch | NOT EXECUTED | No interactive Windows session recorded. | - |
| 13 | Recovery after Consent revoke | NOT EXECUTED | No interactive Windows session recorded. | - |
| 14 | Duplicate request invokes Provider once | NOT EXECUTED | No interactive Windows session recorded. | - |
| 15 | Report soft delete preserves source data | NOT EXECUTED | No interactive Windows session recorded. | - |
| 16 | Binding recovery after App restart | NOT EXECUTED | No interactive Windows session recorded. | - |
| 17 | Narrow window has no overflow | NOT EXECUTED | No interactive Windows session recorded. | - |
| 18 | Final confirmation retention/cost text | NOT EXECUTED | No interactive Windows session recorded. | - |
| 19 | History states and actions | NOT EXECUTED | No interactive Windows session recorded. | - |
| 20 | Detail states and recovery action | NOT EXECUTED | No interactive Windows session recorded. | - |

## Android Physical-Device Matrix

| # | Scenario | Result | Evidence | Defect ID |
|---:|---|---|---|---|
| 1 | Install arm64-v8a release APK | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 2 | Configure runtime Server endpoint | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 3 | Log in with development account | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 4 | Enable AI Consent | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 5 | Build Preview | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 6 | Final confirmation | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 7 | Fake Provider success | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 8 | Force-close and reopen App | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 9 | Pending recovery | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 10 | History and Detail | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 11 | Endpoint mismatch | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 12 | Account mismatch | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 13 | Large font | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 14 | Full-page scrolling | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 15 | Bottom navigation | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 16 | No horizontal overflow | NOT EXECUTED | No Android device connected on 2026-07-18. | - |
| 17 | No unexpected exit | NOT EXECUTED | No Android device connected on 2026-07-18. | - |

## Release Decision

Do not label Sprint 8E a complete release PASS while PostgreSQL, multi-worker HTTP, required Windows manual cases, or required Android physical-device cases remain `NOT EXECUTED` or `FAIL`.
