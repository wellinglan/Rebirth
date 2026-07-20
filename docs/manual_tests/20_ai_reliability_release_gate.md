# AI Reliability Release Gate

Record only observed manual behavior. Automated tests and APK compilation do not convert a device step to PASS.

## Environment Record

| Item | Result | Notes |
|---|---|---|
| Windows release build/start | PASS | `flutter build windows --release` and `flutter run -d windows --release` completed on 2026-07-18; the App launched and exited normally. This is not the manual Windows matrix. |
| Automated single-worker Fake full-stack | PASS | Real Uvicorn + JWT + Dio + PostgreSQL Ledger + Fake Provider + local Drift report lifecycle passed on 2026-07-18; this is not the manual Windows matrix. |
| PostgreSQL integration | PASS | Isolated PostgreSQL 17.10; Alembic head and 7 PostgreSQL marker tests passed, including four spawned Claim processes. The temporary cluster was stopped and removed. |
| Uvicorn multi-worker HTTP | PASS | 2 workers, 8 duplicate HTTP requests, 1 Ledger row, 1 provider-start event, final completed; temporary ports/workers were cleaned. |
| Android release APK build | PASS | Sprint 8F.1 source `f7989ce` rebuilt arm64-v8a, armeabi-v7a, and x86_64 release APKs on 2026-07-20. |
| OpenAI real smoke | NOT EXECUTED | Neither the Windows nor Android manual run used a real AI Provider; both used the development Fake Provider. Optional paid smoke remains unexecuted. |
| CI Server SQLite | PASS | Sprint 8F.1 Quality Run `29720778717`, Job `88283224592`, completed successfully. |
| CI PostgreSQL | PASS | Sprint 8F.1 Quality Run `29720778717`, Job `88283224708`; multiprocessing and multi-worker verification completed successfully. |
| CI Flutter | PASS | Sprint 8F.1 Quality Run `29720778717`, Job `88283224606`; analyze and test completed successfully. |
| CI Android build | PASS | Sprint 8F.1 Quality Run `29720778717`, Job `88283224589`; Android debug build completed successfully. |
| Windows general manual regression | PASS | User-reported Windows run on 2026-07-20 passed all manual checks using the development Fake Provider. |
| Android physical-device general regression | PASS | User confirmed the rebuilt Sprint 8F.1 arm64-v8a release APK and Plan date-layout retest passed on 2026-07-20. |
| Sprint 8F.1 automated blocker fix | PASS | Date layout tests pass at 320/360/412/720/1200px and text scales 1.0/1.3/1.5/2.0; date policy tests, analyze, full Flutter tests, and release builds pass. |

## Windows Manual Matrix

| # | Scenario | Result | Evidence | Defect ID |
|---:|---|---|---|---|
| 1 | Fake success | PASS | User-reported Windows manual execution on 2026-07-20; Fake Provider only. | - |
| 2 | Fake Provider timeout | PASS | User-reported Windows manual execution on 2026-07-20; Fake Provider only. | - |
| 3 | Client network interruption | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 4 | Status GET after network recovery | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 5 | Completed recovery | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 6 | Failed recovery | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 7 | Active processing | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 8 | Stale processing to outcome_unknown | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 9 | Result expired | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 10 | Not-found user confirmation | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 11 | Endpoint mismatch | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 12 | Account mismatch | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 13 | Recovery after Consent revoke | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 14 | Duplicate request invokes Provider once | PASS | User-reported Windows manual execution on 2026-07-20; Fake Provider only. | - |
| 15 | Report soft delete preserves source data | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 16 | Binding recovery after App restart | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 17 | Narrow window has no overflow | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 18 | Final confirmation retention/cost text | PASS | User-reported Windows manual execution on 2026-07-20; Fake Provider only. | - |
| 19 | History states and actions | PASS | User-reported Windows manual execution on 2026-07-20. | - |
| 20 | Detail states and recovery action | PASS | User-reported Windows manual execution on 2026-07-20. | - |

## Android Physical-Device Matrix

| # | Scenario | Result | Evidence | Defect ID |
|---:|---|---|---|---|
| 1 | Install arm64-v8a release APK | PASS | User confirmed installation and physical-device execution of the rebuilt Sprint 8F.1 candidate. | - |
| 2 | Configure runtime Server endpoint | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 3 | Log in with development account | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 4 | Enable AI Consent | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 5 | Build Preview | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 6 | Final confirmation | PASS | User-reported Android physical-device execution on 2026-07-20; Fake Provider only. | - |
| 7 | Fake Provider success | PASS | User-reported Android physical-device execution on 2026-07-20; no real Provider used. | - |
| 8 | Force-close and reopen App | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 9 | Pending recovery | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 10 | History and Detail | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 11 | Endpoint mismatch | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 12 | Account mismatch | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 13 | Large font | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 14 | Full-page scrolling | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 15 | Bottom navigation | PASS | User-reported Android physical-device execution on 2026-07-20. | - |
| 16 | No horizontal overflow | PASS | User confirmed Plan start/target dates, four-digit year, clear action, large text, scrolling, save, and restart persistence pass on the physical device. | `PLAN-ANDROID-DATE-LAYOUT-001` closed |
| 17 | No unexpected exit | PASS | User-reported Android physical-device execution on 2026-07-20. | - |

## Release Decision

Local PostgreSQL/Fake full-stack verification, Sprint 8F.1 Flutter validation, and release builds pass. The user-reported Windows matrix is `20 PASS / 0 FAIL / 0 NOT EXECUTED`; the Android physical-device matrix is `17 PASS / 0 FAIL / 0 NOT EXECUTED`. Real OpenAI Provider smoke remains `NOT EXECUTED` on both platforms and is optional; Fake Provider results do not represent it as a PASS.

The earlier 2026-07-20 manual run found `PLAN-ANDROID-DATE-LAYOUT-001`: in Android portrait, the Plan start/target date controls were compressed, the four-digit year wrapped vertically, and the clear action competed for the same horizontal space. Sprint 8F.1 moves the clear action outside the date field width allocation and stacks year above month/day below the responsive breakpoint. Automated and Android physical-device verification now pass, so the defect is closed.

GitHub Quality Workflow Run `29720778717` passed all four required jobs for pushed Sprint 8F.1 commit `b13cb5b9eb1adaffde42f31536cdde52c58f742b`. The Alpha Release Gate is PASS, and the `v0.7.0-alpha` tag may be created from the final verified commit.
