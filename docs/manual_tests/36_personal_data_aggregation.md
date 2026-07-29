# Manual Test: Personal Data Aggregation

> Sprint: 12A
> Status: ACCEPTED (49 PASS / 5 NOT EXECUTED)
> Baseline: `5fc17a1664570b072aa81a144cc84c0136f56414`
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

Record only `PASS`, `FAIL`, or `NOT EXECUTED`. Automated evidence does not
count as manual PASS. Do not record a User Key, token, complete Endpoint,
Journal body, Health note/metric, raw payload, database copy, or private UUID.

## Preconditions

- Install the exact Windows release and arm64-v8a Android release.
- Use a local account with representative Profile, Plan, Today, Journal, and
  Health records.
- Do not enable network solely for this matrix.
- Keep Provider Failure checks `NOT EXECUTED` if no safe product operation can
  create them.
- Keep independent-account isolation checks `NOT EXECUTED` when no independent
  test environment exists.

## A. Basic Aggregation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Current account has local Profile, Plan, Today, Journal, and Health data | PASS | User acceptance, 2026-07-29 |
| 2 | Open Personal Data Overview from Settings | PASS | User acceptance, 2026-07-29 |
| 3 | All five registered sources are visible | PASS | User acceptance, 2026-07-29 |
| 4 | Every source renders the expected typed local data | PASS | User acceptance, 2026-07-29 |
| 5 | No business body is exposed unexpectedly | PASS | User acceptance, 2026-07-29 |
| 6 | No AI summary, judgment, or suggestion is generated | PASS | User acceptance, 2026-07-29 |
| 7 | Opening and refreshing the page triggers no manual or automatic sync | PASS | User acceptance, 2026-07-29 |
| 8 | Airplane mode still allows the overview to open | PASS | User acceptance, 2026-07-29 |

## B. Date Navigation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Today's date and data load correctly | PASS | User acceptance, 2026-07-29 |
| 2 | Previous-day action loads the previous local date | PASS | User acceptance, 2026-07-29 |
| 3 | Next-day action loads the next local date | PASS | User acceptance, 2026-07-29 |
| 4 | Today action returns to the current local date | PASS | User acceptance, 2026-07-29 |
| 5 | Data changes correctly between dates | PASS | User acceptance, 2026-07-29 |
| 6 | A date with no records shows the empty state | PASS | User acceptance, 2026-07-29 |
| 7 | Rapid date changes never show a stale previous-date result | PASS | User acceptance, 2026-07-29 |

## C. Provider Failure

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | One unavailable source produces a partial result | NOT EXECUTED | |
| 2 | Other available sources remain visible | NOT EXECUTED | |
| 3 | Manual retry remains available | NOT EXECUTED | |
| 4 | UI shows no technical stack trace | NOT EXECUTED | |
| 5 | UI shows no sensitive exception content | NOT EXECUTED | |

These rows remain `NOT EXECUTED` when a real provider cannot be made to fail
safely. Automated fault-injection evidence does not become manual PASS.

## D. Privacy

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Complete Journal body is absent from the overview | PASS | User acceptance, 2026-07-29 |
| 2 | Health note is absent from the overview | PASS | User acceptance, 2026-07-29 |
| 3 | Health is visibly marked as highly sensitive and starts collapsed | PASS | User acceptance, 2026-07-29 |
| 4 | No token is displayed | PASS | User acceptance, 2026-07-29 |
| 5 | No User Key is displayed | PASS | User acceptance, 2026-07-29 |
| 6 | No Endpoint is displayed | PASS | User acceptance, 2026-07-29 |
| 7 | No complete UUID is displayed | PASS | User acceptance, 2026-07-29 |
| 8 | No raw JSON is displayed | PASS | User acceptance, 2026-07-29 |
| 9 | Overview causes no network upload | PASS | User acceptance, 2026-07-29 |
| 10 | Overview causes no AI request | PASS | User acceptance, 2026-07-29 |

## E. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A shows only Account A local aggregation | PASS | Independent account environment, 2026-07-29 |
| 2 | Logout removes Account A aggregation from view | PASS | Independent account environment, 2026-07-29 |
| 3 | Account B does not show Account A data | PASS | Independent account environment, 2026-07-29 |
| 4 | Re-login to Account A restores Account A local aggregation | PASS | Independent account environment, 2026-07-29 |
| 5 | Authenticated-offline mode can view local aggregation | PASS | Independent account environment, 2026-07-29 |
| 6 | Binding-required state cannot enter the business aggregation page | PASS | Independent account environment, 2026-07-29 |

When no independent isolation environment is available, affected rows remain
`NOT EXECUTED` and continue to reference the Account Boundary Conditional Gate.

## F. Manual Refresh

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Modify Today, then manually refresh the overview | PASS | User acceptance, 2026-07-29 |
| 2 | Add Journal, then manually refresh the overview | PASS | User acceptance, 2026-07-29 |
| 3 | Modify Health, then manually refresh the overview | PASS | User acceptance, 2026-07-29 |
| 4 | Modify Plan, then manually refresh the overview | PASS | User acceptance, 2026-07-29 |
| 5 | Refreshed sections show the new local values | PASS | User acceptance, 2026-07-29 |
| 6 | Refresh does not trigger cloud synchronization | PASS | User acceptance, 2026-07-29 |

## G. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows release opens Personal Data Overview | PASS | Windows release acceptance, 2026-07-29 |
| 2 | Android arm64 release opens Personal Data Overview | PASS | Android release acceptance, 2026-07-29 |
| 3 | Android portrait remains usable | PASS | Android release acceptance, 2026-07-29 |
| 4 | Windows narrow window remains usable | PASS | Windows release acceptance, 2026-07-29 |
| 5 | 320px width has no horizontal overflow | PASS | Narrow-layout acceptance, 2026-07-29 |
| 6 | Maximum font size keeps dates, source state, and actions readable | PASS | Accessibility acceptance, 2026-07-29 |
| 7 | The complete page remains scrollable | PASS | Windows and Android acceptance, 2026-07-29 |
| 8 | Back navigation is safe and changes no data | PASS | Windows and Android acceptance, 2026-07-29 |
| 9 | Quality and sensitivity state do not rely on color alone | PASS | Windows and Android acceptance, 2026-07-29 |
| 10 | No crash occurs | PASS | Windows and Android acceptance, 2026-07-29 |
| 11 | No RenderFlex or horizontal overflow occurs | PASS | Windows and Android acceptance, 2026-07-29 |
| 12 | No primary date or refresh action is hidden | PASS | Windows and Android acceptance, 2026-07-29 |

## Final Gates

| Gate | Status | Notes |
|---|---|---|
| Personal Data Aggregation Product Gate | CLOSED / ACCEPTED | 49 executable product checks passed; five safe fault-injection rows remain not executed |
| Account Boundary Isolation Gate | CLOSED / ACCEPTED | All six checks passed in an independent account environment |

## Totals

| PASS | FAIL | NOT EXECUTED |
|---:|---:|---:|
| 49 | 0 | 5 |
