# AI Reliability Release Gate

Record only observed manual behavior. Automated tests and APK compilation do not convert a device step to PASS.

## Environment Record

| Item | Result | Notes |
|---|---|---|
| Windows release build/start | PASS | `flutter build windows --release` and `flutter run -d windows --release` completed on 2026-07-18; the App launched and exited normally. This is not the manual Windows matrix. |
| Automated single-worker Fake full-stack | PASS | Real Uvicorn + JWT + Dio + PostgreSQL Ledger + Fake Provider + local Drift report lifecycle passed on 2026-07-18; this is not the manual Windows matrix. |
| PostgreSQL integration | PASS | Isolated PostgreSQL 17.10; Alembic head and 7 PostgreSQL marker tests passed, including four spawned Claim processes. The temporary cluster was stopped and removed. |
| Uvicorn multi-worker HTTP | PASS | 2 workers, 8 duplicate HTTP requests, 1 Ledger row, 1 provider-start event, final completed; temporary ports/workers were cleaned. |
| Android release APK build | PASS | `flutter build apk --release --split-per-abi` produced arm64-v8a, armeabi-v7a, and x86_64 APKs. Physical-device rows remain NOT EXECUTED. |
| OpenAI real smoke | NOT EXECUTED | Neither the Windows nor Android manual run used a real AI Provider; both used the development Fake Provider. Optional paid smoke remains unexecuted. |
| CI Server SQLite | PASS | Quality Run `29620976480`, Job `88015814557`, completed in 21 seconds. |
| CI PostgreSQL | PASS | Quality Run `29620976480`, Job `88015814524`; Alembic, postgres marker, and 2-worker script all ran successfully. |
| CI Flutter | PASS | Quality Run `29620976480`, Job `88015814552`; pub get, analyze, and test all ran successfully. |
| CI Android build | PASS | Quality Run `29620976480`, Job `88015814568`; debug APK build completed in 4 minutes 37 seconds. |
| Windows general manual regression | PASS | User-reported Windows run on 2026-07-20 passed all manual checks using the development Fake Provider. |
| Android physical-device general regression | FAIL | User-reported Android run passed all other exercised checks using the development Fake Provider, but portrait Plan date inputs are severely compressed. See `PLAN-ANDROID-DATE-LAYOUT-001` in `05_plan_hierarchy_date_ux.md`. |

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
| 1 | Install arm64-v8a release APK | NOT EXECUTED | Android physical-device testing was reported, but the installed build type was not specified as the arm64-v8a release APK. | - |
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
| 16 | No horizontal overflow | FAIL | Plan start/target date controls are compressed in portrait and the four-digit year wraps vertically. | `PLAN-ANDROID-DATE-LAYOUT-001` |
| 17 | No unexpected exit | PASS | User-reported Android physical-device execution on 2026-07-20. | - |

## Release Decision

Automated CI, local PostgreSQL/Fake full-stack verification, and release builds pass. The user-reported Windows matrix is `20 PASS / 0 FAIL / 0 NOT EXECUTED`. The Android physical-device matrix is `15 PASS / 1 FAIL / 1 NOT EXECUTED`: release APK installation remains unverified because the reported device build type was not specified, and the Plan portrait date layout failed. Real OpenAI Provider smoke remains `NOT EXECUTED` on both platforms and is not represented as a PASS by Fake Provider results.

The 2026-07-20 general manual regression found `PLAN-ANDROID-DATE-LAYOUT-001`: in Android portrait, the Plan start/target date controls are compressed, the four-digit year wraps vertically, and the clear action competes for the same horizontal space. All other reported Windows and Android manual checks passed using the development Fake Provider.

The automated gate itself found no product defect. The initial parallel Flutter build collision and one transient occupied verification port were execution-environment incidents; sequential reruns passed and required no product-code change. The Android Plan layout defect remains a release blocker until fixed and reverified on a physical device.
