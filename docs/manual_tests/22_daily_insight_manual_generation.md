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
| 1 | AI Coach entry uses click-time local date | NOT EXECUTED | Pending interactive run | - |
| 2 | Today entry passes displayed date | NOT EXECUTED | Pending interactive run | - |
| 3 | Journal entry passes displayed date | NOT EXECUTED | Pending interactive run | - |
| 4 | Consent disabled gate | NOT EXECUTED | Pending interactive run | - |
| 5 | All scopes default off; only Today/Health/Journal shown | NOT EXECUTED | Pending interactive run | - |
| 6 | Journal cancel leaves scope off | NOT EXECUTED | Pending interactive run | - |
| 7 | Journal confirm is one request only | NOT EXECUTED | Pending interactive run | - |
| 8 | Today-only Preview | NOT EXECUTED | Pending interactive run | - |
| 9 | Health-only Preview | NOT EXECUTED | Pending interactive run | - |
| 10 | Journal-only Preview | NOT EXECUTED | Pending interactive run | - |
| 11 | Selected missing scope remains visible | NOT EXECUTED | Pending interactive run | - |
| 12 | All missing blocks capabilities/generation | NOT EXECUTED | Pending interactive run | - |
| 13 | Explicit zero remains zero | NOT EXECUTED | Pending interactive run | - |
| 14 | Reusable completed report opens without POST | NOT EXECUTED | Pending interactive run | - |
| 15 | Source change blocks stale Preview | NOT EXECUTED | Pending interactive run | - |
| 16 | Final cancel creates no pending/Binding/POST | NOT EXECUTED | Pending interactive run | - |
| 17 | Fake success completes and opens Detail | NOT EXECUTED | Pending interactive run | - |
| 18 | Fake timeout is controlled and not retried | NOT EXECUTED | Pending interactive run | - |
| 19 | Network interruption preserves pending/Binding | NOT EXECUTED | Pending interactive run | - |
| 20 | Restart/status GET recovers without POST | NOT EXECUTED | Pending interactive run | - |
| 21 | Mixed History shows Daily and Weekly | NOT EXECUTED | Pending interactive run | - |
| 22 | Daily Detail source links open the exact historical Today and Journal date; missing records show a message | NOT EXECUTED | Pending Windows interactive run with the Sprint 9B.1 build | `DAILY-DETAIL-SOURCE-NAV-001` |
| 23 | Soft delete removes only local AIReport | NOT EXECUTED | Pending interactive run | - |
| 24 | Narrow window scrolls with no overflow | NOT EXECUTED | Pending interactive run | - |
| 25 | Large text remains readable | NOT EXECUTED | Pending interactive run | - |

## Android Physical Matrix

Install the newly built APK and record evidence from the physical device.

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | New APK installed | NOT EXECUTED | Physical device required | - |
| 2 | AI Coach entry | NOT EXECUTED | Physical device required | - |
| 3 | Today entry | NOT EXECUTED | Physical device required | - |
| 4 | Journal entry and unsaved warning | NOT EXECUTED | Physical device required | - |
| 5 | Local Preview | NOT EXECUTED | Physical device required | - |
| 6 | Journal dialog | NOT EXECUTED | Physical device required | - |
| 7 | Final confirmation | NOT EXECUTED | Physical device required | - |
| 8 | Fake success | NOT EXECUTED | Physical device required | - |
| 9 | Force-close then status recovery | NOT EXECUTED | Physical device required | - |
| 10 | Mixed History/Detail | NOT EXECUTED | Physical device required | - |
| 11 | Exact historical Today/Journal source navigation and missing-record message | NOT EXECUTED | Physical device required with the Sprint 9B.1 arm64-v8a release APK | `DAILY-DETAIL-SOURCE-NAV-001` |
| 12 | Large text | NOT EXECUTED | Physical device required | - |
| 13 | Complete scrolling with no overflow | NOT EXECUTED | Physical device required | - |
| 14 | No abnormal exit | NOT EXECUTED | Physical device required | - |

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
| Windows Matrix | NOT EXECUTED | `0 PASS / 0 FAIL / 25 NOT EXECUTED`; automated tests and App startup do not replace interaction. |
| Android Matrix | NOT EXECUTED | `0 PASS / 0 FAIL / 14 NOT EXECUTED`; APK build does not replace physical-device installation. |
| Phone model | NOT EXECUTED | Record during physical-device execution. |
| Android version | NOT EXECUTED | Record during physical-device execution. |
| APK ABI | PASS (build only) | Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (21.2 MB) for the physical-device matrix. |
| Server endpoint | NOT EXECUTED | Record the reachable Fake Provider endpoint used by both clients. |
| Fake success | NOT EXECUTED | Use `REBIRTH_AI_PROVIDER=fake` and `REBIRTH_AI_FAKE_SCENARIO=success`. |
| Fake timeout | NOT EXECUTED | Switch only the scenario to `timeout` for the timeout case. |
| OpenAI real smoke | NOT EXECUTED | Optional and excluded from this acceptance matrix. |

## Sprint 9B.1 Defects

| Defect ID | Status | Verification |
|---|---|---|
| `DAILY-DETAIL-SOURCE-NAV-001` | FIXED, PENDING MANUAL RETEST | Exact-date routes, validation, repository-backed lookup, missing state, one-time Dialog, Daily button destination, and Weekly absence are covered automatically. Close only after Windows item 22 and Android item 11 pass. |

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
