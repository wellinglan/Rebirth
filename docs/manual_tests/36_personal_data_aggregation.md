# Manual Test: Personal Data Aggregation

> Sprint: 12A
> Status: NOT EXECUTED
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
| 1 | Current account has local Profile, Plan, Today, Journal, and Health data | NOT EXECUTED | |
| 2 | Open Personal Data Overview from Settings | NOT EXECUTED | |
| 3 | All five registered sources are visible | NOT EXECUTED | |
| 4 | Every source renders the expected typed local data | NOT EXECUTED | |
| 5 | No business body is exposed unexpectedly | NOT EXECUTED | |
| 6 | No AI summary, judgment, or suggestion is generated | NOT EXECUTED | |
| 7 | Opening and refreshing the page triggers no manual or automatic sync | NOT EXECUTED | |
| 8 | Airplane mode still allows the overview to open | NOT EXECUTED | |

## B. Date Navigation

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Today's date and data load correctly | NOT EXECUTED | |
| 2 | Previous-day action loads the previous local date | NOT EXECUTED | |
| 3 | Next-day action loads the next local date | NOT EXECUTED | |
| 4 | Today action returns to the current local date | NOT EXECUTED | |
| 5 | Data changes correctly between dates | NOT EXECUTED | |
| 6 | A date with no records shows the empty state | NOT EXECUTED | |
| 7 | Rapid date changes never show a stale previous-date result | NOT EXECUTED | |

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
| 1 | Complete Journal body is absent from the overview | NOT EXECUTED | |
| 2 | Health note is absent from the overview | NOT EXECUTED | |
| 3 | Health is visibly marked as highly sensitive and starts collapsed | NOT EXECUTED | |
| 4 | No token is displayed | NOT EXECUTED | |
| 5 | No User Key is displayed | NOT EXECUTED | |
| 6 | No Endpoint is displayed | NOT EXECUTED | |
| 7 | No complete UUID is displayed | NOT EXECUTED | |
| 8 | No raw JSON is displayed | NOT EXECUTED | |
| 9 | Overview causes no network upload | NOT EXECUTED | |
| 10 | Overview causes no AI request | NOT EXECUTED | |

## E. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A shows only Account A local aggregation | NOT EXECUTED | |
| 2 | Logout removes Account A aggregation from view | NOT EXECUTED | |
| 3 | Account B does not show Account A data | NOT EXECUTED | |
| 4 | Re-login to Account A restores Account A local aggregation | NOT EXECUTED | |
| 5 | Authenticated-offline mode can view local aggregation | NOT EXECUTED | |
| 6 | Binding-required state cannot enter the business aggregation page | NOT EXECUTED | |

When no independent isolation environment is available, affected rows remain
`NOT EXECUTED` and continue to reference the Account Boundary Conditional Gate.

## F. Manual Refresh

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Modify Today, then manually refresh the overview | NOT EXECUTED | |
| 2 | Add Journal, then manually refresh the overview | NOT EXECUTED | |
| 3 | Modify Health, then manually refresh the overview | NOT EXECUTED | |
| 4 | Modify Plan, then manually refresh the overview | NOT EXECUTED | |
| 5 | Refreshed sections show the new local values | NOT EXECUTED | |
| 6 | Refresh does not trigger cloud synchronization | NOT EXECUTED | |

## G. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows release opens Personal Data Overview | NOT EXECUTED | |
| 2 | Android arm64 release opens Personal Data Overview | NOT EXECUTED | |
| 3 | Android portrait remains usable | NOT EXECUTED | |
| 4 | Windows narrow window remains usable | NOT EXECUTED | |
| 5 | 320px width has no horizontal overflow | NOT EXECUTED | |
| 6 | Maximum font size keeps dates, source state, and actions readable | NOT EXECUTED | |
| 7 | The complete page remains scrollable | NOT EXECUTED | |
| 8 | Back navigation is safe and changes no data | NOT EXECUTED | |
| 9 | Quality and sensitivity state do not rely on color alone | NOT EXECUTED | |
| 10 | No crash occurs | NOT EXECUTED | |
| 11 | No RenderFlex or horizontal overflow occurs | NOT EXECUTED | |
| 12 | No primary date or refresh action is hidden | NOT EXECUTED | |

## Final Gates

| Gate | Status | Notes |
|---|---|---|
| Personal Data Aggregation Product Gate | OPEN / NOT EXECUTED | Requires this manual matrix |
| Account Boundary Isolation Gate | CONDITIONAL ACCEPTED | Existing gate; independent environment may be unavailable |

## Totals

| PASS | FAIL | NOT EXECUTED |
|---:|---:|---:|
| 0 | 0 | 54 |
