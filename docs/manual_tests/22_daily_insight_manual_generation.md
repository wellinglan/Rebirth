# Manual Test: Daily Insight Manual Generation

## Preparation

1. Start the development Server with a clean test database, `REBIRTH_AI_PROVIDER=fake`, and `REBIRTH_AI_FAKE_SCENARIO=success`.
2. Start the current Windows or Android build against that Server, sign in, and explicitly enable AI data consent.
3. Save representative Today, Health, and Journal records for one local date. Include an explicit zero and at least one null field. Also retain a historical Daily report whose date differs from today for exact-date navigation.
4. Never use a real OpenAI key for this matrix.

## Windows Matrix

Record each item as `PASS`, `FAIL`, or `NOT EXECUTED`, with evidence and a defect ID when failed.

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | AI Coach entry uses click-time local date | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 2 | Today entry passes displayed date | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 3 | Journal entry passes displayed date | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 4 | Consent disabled gate | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 5 | All scopes default off; only Today/Health/Journal shown | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 6 | Journal cancel leaves scope off | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 7 | Journal confirm is one request only | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 8 | Today-only Preview | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 9 | Health-only Preview | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 10 | Journal-only Preview | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 11 | Selected missing scope remains visible | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 12 | All missing blocks capabilities/generation | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 13 | Explicit zero remains zero | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 14 | Reusable completed report opens without POST | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 15 | Source change blocks stale Preview | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 16 | Final cancel creates no pending/Binding/POST | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 17 | Fake success completes and opens Detail | PASS | User-reported Windows interactive acceptance on 2026-07-23; Fake Provider only. | - |
| 18 | Fake timeout is controlled and not retried | PASS | User-reported Windows interactive acceptance on 2026-07-23; Fake Provider only. | - |
| 19 | Network interruption preserves pending/Binding | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 20 | Restart/status GET recovers without POST | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 21 | Mixed History shows Daily and Weekly | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 22 | Daily Detail source links open the exact historical Today and Journal date; missing records show a message | PASS | User-reported Windows interactive acceptance on 2026-07-23. | `DAILY-DETAIL-SOURCE-NAV-001` |
| 23 | Soft delete removes only local AIReport | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 24 | Narrow window scrolls with no overflow | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |
| 25 | Large text remains readable | PASS | User-reported Windows interactive acceptance on 2026-07-23. | - |

## Android Physical Matrix

Install the newly built APK and record evidence from the physical device.

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | New APK installed | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 2 | AI Coach entry | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 3 | Today entry | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 4 | Journal entry and unsaved warning | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 5 | Local Preview | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 6 | Journal dialog | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 7 | Final confirmation | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 8 | Fake success | PASS | User-reported Android physical-device acceptance on 2026-07-23; Fake Provider only. | - |
| 9 | Force-close then status recovery | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 10 | Mixed History/Detail | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |
| 11 | Exact historical Today/Journal source navigation and missing-record message | PASS | User-reported Android physical-device acceptance on 2026-07-23. | `DAILY-DETAIL-SOURCE-NAV-001` |
| 12 | Large text | PASS | User-reported Android physical-device acceptance on 2026-07-23; text remains readable. | - |
| 13 | Complete scrolling with no overflow | FAIL | At maximum Android font size, the Plan filter area occupies about half of the page and leaves insufficient space for the actual plan list. | `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` |
| 14 | No abnormal exit | PASS | User-reported Android physical-device acceptance on 2026-07-23. | - |

## Sprint 9B.1 Environment Record

| Item | Result | Evidence |
|---|---|---|
| Baseline | PASS | `9dfb16087f6fbc7481da99337c7ea7cf50312e0c` |
| Flutter analyze | PASS | No issues found. |
| Flutter tests | PASS | `661 passed / 2 skipped`; the skips are opt-in full-stack cases. |
| Server SQLite | PASS | `120 passed / 1 skipped / 8 deselected`. |
| Local PostgreSQL marker | NOT EXECUTED | `8 skipped / 121 deselected`; no local PostgreSQL test URL was configured. GitHub CI must execute the marker. |
| Windows debug start | PASS | Debug executable built, Dart VM Service became available, and the App exited normally. This is not the manual matrix. |
| Windows release build | PASS | `build/windows/x64/runner/Release/rebirth.exe`. |
| Android debug build | PASS | `build/app/outputs/flutter-apk/app-debug.apk`. |
| Android split release build | PASS | armeabi-v7a, arm64-v8a, and x86_64 APKs built successfully. |
| Windows Matrix | PASS | `25 PASS / 0 FAIL / 0 NOT EXECUTED`; user-reported interactive execution on 2026-07-23. |
| Android Matrix | FAIL | `13 PASS / 1 FAIL / 0 NOT EXECUTED`; item 13 failed on a physical device at maximum font size. |
| Phone model | NOT RECORDED | Physical-device execution completed, but the model was not supplied in the acceptance report. |
| Android version | NOT RECORDED | Physical-device execution completed, but the OS version was not supplied in the acceptance report. |
| APK ABI | PASS | User-reported physical-device execution of the Sprint 9B.1 Android candidate; the matrix requires the arm64-v8a release APK. |
| Server endpoint | PASS | Both clients completed the reported Fake Provider scenarios through their configured development endpoint. |
| Fake success | PASS | User-reported Windows and Android execution with the development Fake Provider. |
| Fake timeout | PASS | User-reported Windows execution of the controlled timeout case. |
| OpenAI real smoke | NOT EXECUTED | Optional and excluded from this acceptance matrix. |

## Sprint 9B.1 Defects

| Defect ID | Status | Verification |
|---|---|---|
| `DAILY-DETAIL-SOURCE-NAV-001` | CLOSED | Windows item 22 and Android item 11 passed interactive acceptance on 2026-07-23. |
| `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` | OPEN, RELEASE GATE BLOCKER | At maximum Android font size, the expanded Plan filter controls occupy about half of the viewport and leave insufficient space for plan items. Requested UX: place a filter icon in the free area to the right of the Plan title; tapping it expands the filter panel, tapping outside collapses it, and “Show archived” appears below the other filter controls. Layout must remain readable, scrollable, and usable at maximum font size. No implementation change was made while recording this result. |

## Sprint 9B.1 Manual Acceptance Result

- Execution date: 2026-07-23.
- Windows: `25 PASS / 0 FAIL / 0 NOT EXECUTED`.
- Android physical device: `13 PASS / 1 FAIL / 0 NOT EXECUTED`.
- AI Provider: development Fake Provider only.
- Real OpenAI Provider: `NOT EXECUTED`.
- Release Gate: `FAIL / BLOCKED` until `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` is fixed and Android item 13 passes physical-device retest.
- Scope note: this update records manual evidence only; no Flutter, Server, database, or schema code was changed.

## Automated Evidence

Run:

```powershell
flutter analyze
flutter test

cd server
.\.venv\Scripts\python.exe -m pytest -m "not postgres"
.\.venv\Scripts\python.exe -m pytest -m postgres
```

The Flutter suite covers context equality/state isolation, invalid dates, scope boundaries, Journal confirmation behavior, Daily-only Preview dispatch, selected missing/all-missing behavior, reusable reports, source-change integrity, typed capabilities, Daily/Weekly endpoint dispatch, Binding-before-POST lifecycle, recovery, mixed History/Detail, soft delete, and responsive layouts. Automated evidence does not replace the two interactive matrices above.
