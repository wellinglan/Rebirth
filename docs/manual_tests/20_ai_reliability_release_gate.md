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

| # | Scenario | Result | Evidence / Notes |
|---:|---|---|---|
| 1 | Fake success | NOT EXECUTED | |
| 2 | Fake Provider timeout | NOT EXECUTED | |
| 3 | Client network interruption | NOT EXECUTED | |
| 4 | Status GET after network recovery | NOT EXECUTED | |
| 5 | Completed recovery | NOT EXECUTED | |
| 6 | Failed recovery | NOT EXECUTED | |
| 7 | Active processing | NOT EXECUTED | |
| 8 | Stale processing to outcome_unknown | NOT EXECUTED | |
| 9 | Result expired | NOT EXECUTED | |
| 10 | Not-found user confirmation | NOT EXECUTED | |
| 11 | Endpoint mismatch | NOT EXECUTED | |
| 12 | Account mismatch | NOT EXECUTED | |
| 13 | Recovery after Consent revoke | NOT EXECUTED | |
| 14 | Duplicate request invokes Provider once | NOT EXECUTED | |
| 15 | Report soft delete preserves source data | NOT EXECUTED | |
| 16 | Binding recovery after App restart | NOT EXECUTED | |
| 17 | Narrow window has no overflow | NOT EXECUTED | |
| 18 | Final confirmation retention/cost text | NOT EXECUTED | |
| 19 | History states and actions | NOT EXECUTED | |
| 20 | Detail states and recovery action | NOT EXECUTED | |

## Android Physical-Device Matrix

| # | Scenario | Result | Evidence / Notes |
|---:|---|---|---|
| 1 | Login | NOT EXECUTED | |
| 2 | Build Preview | NOT EXECUTED | |
| 3 | Final confirmation | NOT EXECUTED | |
| 4 | Fake success | NOT EXECUTED | |
| 5 | Close and reopen App | NOT EXECUTED | |
| 6 | Pending recovery | NOT EXECUTED | |
| 7 | History | NOT EXECUTED | |
| 8 | Detail | NOT EXECUTED | |
| 9 | Endpoint switch | NOT EXECUTED | |
| 10 | Large font | NOT EXECUTED | |
| 11 | No horizontal overflow | NOT EXECUTED | |
| 12 | No unexpected exit | NOT EXECUTED | |

## Release Decision

Do not label Sprint 8E a complete release PASS while PostgreSQL, multi-worker HTTP, required Windows manual cases, or required Android physical-device cases remain `NOT EXECUTED` or `FAIL`.
