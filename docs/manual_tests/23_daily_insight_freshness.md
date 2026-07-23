# Manual Test: Daily Insight Freshness

## Preparation

1. Use the current Windows release build and the rebuilt Android `arm64-v8a` release APK.
2. Connect both clients to the configured Tailscale private Alpha endpoint.
3. Use Development login, explicit AI data consent, and the Fake Provider only.
4. Prepare Daily reports with Today-only, Health-only, Journal-only, mixed scopes, selected-missing data, explicit zero, and null fields.
5. Do not use a real OpenAI key. Record evidence and defect IDs for failures.

## Windows Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Unchanged completed Daily report shows Current | NOT EXECUTED | - | - |
| 2 | Selected Today change makes the report Stale | NOT EXECUTED | - | - |
| 3 | Selected Health change makes the report Stale | NOT EXECUTED | - | - |
| 4 | Selected Journal change makes the report Stale | NOT EXECUTED | - | - |
| 5 | An unselected scope change does not affect freshness | NOT EXECUTED | - | - |
| 6 | Adding data to a selected-missing scope makes the report Stale | NOT EXECUTED | - | - |
| 7 | Stale opens latest Preview with the original date and scopes | NOT EXECUTED | - | - |
| 8 | Cancelling final confirmation creates no pending, Binding, or POST | NOT EXECUTED | - | - |
| 9 | Confirmed regeneration creates a new Current report | NOT EXECUTED | - | - |
| 10 | The old Stale report remains in History | NOT EXECUTED | - | - |
| 11 | Weekly Detail has no Daily freshness status | NOT EXECUTED | - | - |
| 12 | Narrow window scrolls with no overflow | NOT EXECUTED | - | - |
| 13 | Large text remains readable with no overflow | NOT EXECUTED | - | - |

Windows total: `0 PASS / 0 FAIL / 13 NOT EXECUTED`.

## Android Physical Matrix

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Unchanged completed Daily report shows Current | NOT EXECUTED | - | - |
| 2 | A selected source change makes the report Stale | NOT EXECUTED | - | - |
| 3 | Stale opens latest Preview with original date and scopes | NOT EXECUTED | - | - |
| 4 | Cancelling final confirmation creates no POST | NOT EXECUTED | - | - |
| 5 | Confirmed regeneration creates a new Current report | NOT EXECUTED | - | - |
| 6 | The old Stale report remains in History | NOT EXECUTED | - | - |
| 7 | Weekly Detail has no Daily freshness status | NOT EXECUTED | - | - |
| 8 | Maximum system text remains readable | NOT EXECUTED | - | - |
| 9 | Detail and Preview have no overflow and can fully scroll | NOT EXECUTED | - | - |
| 10 | The app has no abnormal exit | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 10 NOT EXECUTED`.

## Acceptance Status

- Sprint 9C manual acceptance: `NOT EXECUTED`.
- Windows freshness matrix: `NOT EXECUTED`.
- Android physical freshness matrix: `NOT EXECUTED`.
- Automatic tests must not be recorded as manual PASS.
- Phone model and Android version remain separate non-blocking metadata gaps until supplied.
