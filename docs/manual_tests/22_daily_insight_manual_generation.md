# Manual Test: Daily Insight Manual Generation

## Preparation

1. Start the development Server with a clean test database, `REBIRTH_AI_PROVIDER=fake`, and `REBIRTH_AI_FAKE_SCENARIO=success`.
2. Start the current Windows or Android build against that Server, sign in, and explicitly enable AI data consent.
3. Save representative Today, Health, and Journal records for one local date. Include an explicit zero and at least one null field.
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
| 22 | Daily Detail uses one date and source links | NOT EXECUTED | Pending interactive run | - |
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
| 11 | Large text | NOT EXECUTED | Physical device required | - |
| 12 | Complete scrolling | NOT EXECUTED | Physical device required | - |
| 13 | No overflow | NOT EXECUTED | Physical device required | - |
| 14 | No abnormal exit | NOT EXECUTED | Physical device required | - |

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
