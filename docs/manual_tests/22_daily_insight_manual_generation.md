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
| 13 | Complete scrolling with no overflow | PASS | User-reported Android physical-device retest on 2026-07-23 passed with the rebuilt Sprint 9B.2 arm64-v8a release APK. | `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` |
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
| Android Matrix | PASS | `14 PASS / 0 FAIL / 0 NOT EXECUTED`; user-reported Sprint 9B.2 physical-device retest passed on 2026-07-23. |
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
| `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` | CLOSED | Sprint 9B.2 replaced the permanently expanded filters with a responsive collapsible panel. Windows Plan smoke and Android items 12–14 passed user-reported manual retest on 2026-07-23. |

## Sprint 9B.1 Manual Acceptance Result

- Execution date: 2026-07-23.
- Windows: `25 PASS / 0 FAIL / 0 NOT EXECUTED`.
- Android physical device: `14 PASS / 0 FAIL / 0 NOT EXECUTED`.
- AI Provider: development Fake Provider only.
- Real OpenAI Provider: `NOT EXECUTED`.
- Functional retest: `PASS`; the remaining documentation gate is limited to recording the phone model and Android version.
- Scope note: this update records manual evidence only; no Flutter, Server, database, or schema code was changed.

## Sprint 9B.2 Plan Filter Layout Hotfix

Sprint 9B.2 addresses only `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001`.
The permanently expanded Plan filter bar has been replaced by a responsive
filter panel opened from the Plan header. Closing the panel preserves the
filter values held by the existing Plan Controller. The panel:

- is collapsed by default;
- opens and closes from the Plan header filter action;
- closes when the user taps outside it or presses the system back action;
- keeps filter changes visible immediately without closing the panel;
- places the full-row “Show archived” control below the other filters;
- scrolls when its contents exceed the available height;
- uses available width and text scaling rather than platform detection;
- keeps the Plan list mounted behind the temporary panel;
- allows Plan card actions to wrap at narrow widths and large text scales.

Automated widget coverage includes default collapse, toggle close, outside
close, retained filter state, full-row archived selection, system back,
320/360px layouts with `TextScaler 2.0`, and 720/1200px Windows layouts.
Automated coverage does not replace physical-device or Windows interactive
acceptance.

### Sprint 9B.2 Automated and Build Evidence

| Check | Result | Evidence |
|---|---|---|
| Plan page widget tests | PASS | `flutter test test/features/plan/presentation/plan_page_test.dart`: `25 passed`. |
| Complete Plan test suite | PASS | `flutter test test/features/plan`: `111 passed`. |
| Flutter analyze | PASS | `flutter analyze`: no issues found. |
| Complete Flutter test suite | PASS | `flutter test`: `672 passed / 2 skipped`; both skips are opt-in Uvicorn Fake full-stack tests. |
| Windows release build | PASS | `flutter build windows --release`; output `build/windows/x64/runner/Release/rebirth.exe`. This is not the Windows Plan smoke. |
| Android split release build | PASS | `flutter build apk --release --split-per-abi`; arm64-v8a, armeabi-v7a, and x86_64 APKs built. This is not physical-device acceptance. |

### Required Sprint 9B.2 Retest

| Check | Status | Required evidence |
|---|---|---|
| Android item 12: maximum text remains readable | PASS | User-reported physical-device retest on 2026-07-23 with the rebuilt arm64-v8a release APK. |
| Android item 13: Plan filters and complete scrolling | PASS | User confirmed collapsed default, panel scrolling, list access, no overflow, retained filters, and full-row “Show archived”. |
| Android item 14: no abnormal exit | PASS | User confirmed filter open/close, Android back, navigation, and restart completed without abnormal exit. |
| Windows Plan smoke | PASS | User confirmed wide and narrow windows, mouse open/close, outside click, list access, and retained filters. |
| Phone model | NOT RECORDED | Record the physical-device model. |
| Android version | NOT RECORDED | Record the Android OS version. |
| APK ABI | PASS | User-reported retest used the rebuilt `app-arm64-v8a-release.apk` candidate. |

Sprint 9B.2 functional retest result:

- Android item 13 is `PASS`.
- Android Matrix is `14 PASS / 0 FAIL / 0 NOT EXECUTED`.
- `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001` is `CLOSED`.
- Windows Plan smoke and Android items 12–14 are `PASS`.
- Phone model and Android version remain `NOT RECORDED`.
- The final documentation gate remains `BLOCKED` only until those two device fields are recorded; Sprint 9C must not start before that evidence is complete.

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
