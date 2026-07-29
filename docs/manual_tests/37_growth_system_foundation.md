# Manual Test: Growth System Foundation And Journal State Semantics

> Sprint: 12B
> Status: NOT EXECUTED
> Baseline: `5b832d492b00be5508e080f134ad79cf94300411`
> Flutter schema: 8
> API: 1
> Sync Protocol: 2

Record only `PASS`, `FAIL`, or `NOT EXECUTED`. Automated evidence does not
count as manual PASS. Do not record Journal body, Health note/metric, User Key,
token, complete Endpoint, raw payload, database copy, or private UUID.

## Preconditions

- Install the exact Windows release and arm64-v8a Android release.
- Use two devices and the same account only for explicit cross-device rows.
- Use an independent second account for account-boundary rows.
- Disable automatic sync; all sync actions must remain manual.
- Keep failure-injection rows `NOT EXECUTED` if no safe product action can
  create the condition.

## A. Journal Draft

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Create a new Journal | NOT EXECUTED | |
| 2 | Enter one answer | NOT EXECUTED | |
| 3 | Select Save Draft | NOT EXECUTED | |
| 4 | Page displays Draft | NOT EXECUTED | |
| 5 | Exit and reopen; status remains Draft | NOT EXECUTED | |
| 6 | Growth displays Draft for that date | NOT EXECUTED | |
| 7 | Personal Data Overview displays the correct stable status | NOT EXECUTED | |
| 8 | Manual sync preserves Draft on the other device | NOT EXECUTED | |

## B. Journal Complete

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | A new Journal can be completed directly | NOT EXECUTED | |
| 2 | A Draft Journal can be completed | NOT EXECUTED | |
| 3 | Complete saves current unsaved edits | NOT EXECUTED | |
| 4 | Page displays Completed | NOT EXECUTED | |
| 5 | Growth displays Completed | NOT EXECUTED | |
| 6 | Restart preserves Completed | NOT EXECUTED | |
| 7 | Manual sync preserves Completed on the other device | NOT EXECUTED | |
| 8 | Completing does not start automatic sync | NOT EXECUTED | |

## C. Journal Reopen

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Completed Journal displays Reopen/Edit | NOT EXECUTED | |
| 2 | Reopen requires confirmation | NOT EXECUTED | |
| 3 | Confirming changes status to Draft | NOT EXECUTED | |
| 4 | Existing content remains intact | NOT EXECUTED | |
| 5 | Growth refresh displays Draft | NOT EXECUTED | |
| 6 | Manual sync changes the other device to Draft | NOT EXECUTED | |
| 7 | Cancelling confirmation changes nothing | NOT EXECUTED | |

## D. Status Conflict

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices start from the same Completed entry and go offline | NOT EXECUTED | |
| 2 | One device keeps and edits Completed state | NOT EXECUTED | |
| 3 | The other device reopens it as Draft | NOT EXECUTED | |
| 4 | The first device synchronizes successfully | NOT EXECUTED | |
| 5 | The second device receives an explicit conflict | NOT EXECUTED | |
| 6 | The app does not automatically prefer Completed | NOT EXECUTED | |
| 7 | Adopt Remote converges state and content | NOT EXECUTED | |
| 8 | Repeat scenario; Keep Local converges state and content | NOT EXECUTED | |
| 9 | Final status and body stay internally consistent | NOT EXECUTED | |

## E. Growth Source

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Growth reads the local Personal Data aggregation result | NOT EXECUTED | |
| 2 | Focus values match saved research and learning minutes | NOT EXECUTED | |
| 3 | Recovery values match saved sleep and exercise minutes | NOT EXECUTED | |
| 4 | Subjective State matches saved Mood and Energy | NOT EXECUTED | |
| 5 | Reflection matches missing, Draft, and Completed dates | NOT EXECUTED | |
| 6 | Source labels are understandable | NOT EXECUTED | |
| 7 | Observed-day coverage is correct | NOT EXECUTED | |
| 8 | Missing-day coverage is correct | NOT EXECUTED | |
| 9 | Missing values are not displayed or calculated as zero | NOT EXECUTED | |
| 10 | No value judgment or fabricated comparison appears | NOT EXECUTED | |

## F. Partial Availability

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | One unavailable source marks only its dimension partial/unavailable | NOT EXECUTED | |
| 2 | Other dimensions remain visible | NOT EXECUTED | |
| 3 | The page does not become a full-screen failure | NOT EXECUTED | |
| 4 | Manual refresh remains retryable | NOT EXECUTED | |
| 5 | No technical stack trace appears | NOT EXECUTED | |
| 6 | No sensitive exception content appears | NOT EXECUTED | |

Keep these rows `NOT EXECUTED` when a real provider or contributor cannot be
made to fail safely. Automated fault injection is not manual acceptance.

## G. Privacy

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Growth displays no Journal body | NOT EXECUTED | |
| 2 | Growth displays no Health note | NOT EXECUTED | |
| 3 | Growth displays no complete UUID | NOT EXECUTED | |
| 4 | Growth displays no User Key | NOT EXECUTED | |
| 5 | Growth displays no token | NOT EXECUTED | |
| 6 | Growth displays no Endpoint | NOT EXECUTED | |
| 7 | Opening or refreshing Growth triggers no AI request | NOT EXECUTED | |
| 8 | Growth Evidence is not uploaded | NOT EXECUTED | |
| 9 | Recovery is visibly marked highly sensitive | NOT EXECUTED | |
| 10 | No medical or psychological judgment appears | NOT EXECUTED | |

## H. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A displays only Account A Growth | NOT EXECUTED | |
| 2 | Logout removes Account A Growth from view | NOT EXECUTED | |
| 3 | Account B does not display Account A Growth | NOT EXECUTED | |
| 4 | Re-login to Account A restores Account A Growth | NOT EXECUTED | |
| 5 | Authenticated-offline mode can use Growth | NOT EXECUTED | |
| 6 | Binding-required state cannot enter Growth | NOT EXECUTED | |

## I. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows release opens Journal and Growth | NOT EXECUTED | |
| 2 | Android arm64 release opens Journal and Growth | NOT EXECUTED | |
| 3 | Android portrait remains usable | NOT EXECUTED | |
| 4 | Narrow Windows layout remains usable | NOT EXECUTED | |
| 5 | 320px width has no horizontal overflow | NOT EXECUTED | |
| 6 | Maximum font size keeps states and actions readable | NOT EXECUTED | |
| 7 | Complete pages remain scrollable | NOT EXECUTED | |
| 8 | Charts and coverage labels remain understandable | NOT EXECUTED | |
| 9 | Status and quality do not rely on color alone | NOT EXECUTED | |
| 10 | Keyboard navigation reaches primary actions | NOT EXECUTED | |
| 11 | Back navigation changes no state silently | NOT EXECUTED | |
| 12 | No RenderFlex or horizontal overflow occurs | NOT EXECUTED | |
| 13 | No crash occurs | NOT EXECUTED | |

## Final Gates

| Gate | Status | Notes |
|---|---|---|
| Growth System Product Gate | OPEN / MANUAL ACCEPTANCE REQUIRED | All rows start NOT EXECUTED |
| Journal State Semantics Gate | OPEN / MANUAL ACCEPTANCE REQUIRED | All rows start NOT EXECUTED |
| Account Boundary Isolation Gate | CLOSED / ACCEPTED | Retains Sprint 12A acceptance |

## Totals

| PASS | FAIL | NOT EXECUTED |
|---:|---:|---:|
| 0 | 0 | 77 |
