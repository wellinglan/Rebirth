# Manual Test: Growth System Foundation And Journal State Semantics

> Sprint: 12B
> Status: ACCEPTED (71 PASS / 6 NOT EXECUTED)
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
| 1 | Create a new Journal | PASS | User acceptance, 2026-07-29 |
| 2 | Enter one answer | PASS | User acceptance, 2026-07-29 |
| 3 | Select Save Draft | PASS | User acceptance, 2026-07-29 |
| 4 | Page displays Draft | PASS | User acceptance, 2026-07-29 |
| 5 | Exit and reopen; status remains Draft | PASS | User acceptance, 2026-07-29 |
| 6 | Growth displays Draft for that date | PASS | User acceptance, 2026-07-29 |
| 7 | Personal Data Overview displays the correct stable status | PASS | User acceptance, 2026-07-29 |
| 8 | Manual sync preserves Draft on the other device | PASS | Cross-device acceptance, 2026-07-29 |

## B. Journal Complete

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | A new Journal can be completed directly | PASS | User acceptance, 2026-07-29 |
| 2 | A Draft Journal can be completed | PASS | User acceptance, 2026-07-29 |
| 3 | Complete saves current unsaved edits | PASS | User acceptance, 2026-07-29 |
| 4 | Page displays Completed | PASS | User acceptance, 2026-07-29 |
| 5 | Growth displays Completed | PASS | User acceptance, 2026-07-29 |
| 6 | Restart preserves Completed | PASS | Persistence acceptance, 2026-07-29 |
| 7 | Manual sync preserves Completed on the other device | PASS | Cross-device acceptance, 2026-07-29 |
| 8 | Completing does not start automatic sync | PASS | User acceptance, 2026-07-29 |

## C. Journal Reopen

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Completed Journal displays Reopen/Edit | PASS | User acceptance, 2026-07-29 |
| 2 | Reopen requires confirmation | PASS | User acceptance, 2026-07-29 |
| 3 | Confirming changes status to Draft | PASS | User acceptance, 2026-07-29 |
| 4 | Existing content remains intact | PASS | User acceptance, 2026-07-29 |
| 5 | Growth refresh displays Draft | PASS | User acceptance, 2026-07-29 |
| 6 | Manual sync changes the other device to Draft | PASS | Cross-device acceptance, 2026-07-29 |
| 7 | Cancelling confirmation changes nothing | PASS | User acceptance, 2026-07-29 |

## D. Status Conflict

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Both devices start from the same Completed entry and go offline | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 2 | One device keeps and edits Completed state | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 3 | The other device reopens it as Draft | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 4 | The first device synchronizes successfully | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 5 | The second device receives an explicit conflict | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 6 | The app does not automatically prefer Completed | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 7 | Adopt Remote converges state and content | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 8 | Repeat scenario; Keep Local converges state and content | PASS | Cross-device conflict acceptance, 2026-07-29 |
| 9 | Final status and body stay internally consistent | PASS | Cross-device conflict acceptance, 2026-07-29 |

## E. Growth Source

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Growth reads the local Personal Data aggregation result | PASS | User acceptance, 2026-07-29 |
| 2 | Focus values match saved research and learning minutes | PASS | User acceptance, 2026-07-29 |
| 3 | Recovery values match saved sleep and exercise minutes | PASS | User acceptance, 2026-07-29 |
| 4 | Subjective State matches saved Mood and Energy | PASS | User acceptance, 2026-07-29 |
| 5 | Reflection matches missing, Draft, and Completed dates | PASS | User acceptance, 2026-07-29 |
| 6 | Source labels are understandable | PASS | User acceptance, 2026-07-29 |
| 7 | Observed-day coverage is correct | PASS | User acceptance, 2026-07-29 |
| 8 | Missing-day coverage is correct | PASS | User acceptance, 2026-07-29 |
| 9 | Missing values are not displayed or calculated as zero | PASS | User acceptance, 2026-07-29 |
| 10 | No value judgment or fabricated comparison appears | PASS | User acceptance, 2026-07-29 |

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
No safe product-level fault injection was available during acceptance on
2026-07-29, so all six rows remain `NOT EXECUTED`.

## G. Privacy

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Growth displays no Journal body | PASS | Privacy acceptance, 2026-07-29 |
| 2 | Growth displays no Health note | PASS | Privacy acceptance, 2026-07-29 |
| 3 | Growth displays no complete UUID | PASS | Privacy acceptance, 2026-07-29 |
| 4 | Growth displays no User Key | PASS | Privacy acceptance, 2026-07-29 |
| 5 | Growth displays no token | PASS | Privacy acceptance, 2026-07-29 |
| 6 | Growth displays no Endpoint | PASS | Privacy acceptance, 2026-07-29 |
| 7 | Opening or refreshing Growth triggers no AI request | PASS | Privacy acceptance, 2026-07-29 |
| 8 | Growth Evidence is not uploaded | PASS | Privacy acceptance, 2026-07-29 |
| 9 | Recovery is visibly marked highly sensitive | PASS | Privacy acceptance, 2026-07-29 |
| 10 | No medical or psychological judgment appears | PASS | Privacy acceptance, 2026-07-29 |

## H. Account Boundary

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Account A displays only Account A Growth | PASS | Independent account acceptance, 2026-07-29 |
| 2 | Logout removes Account A Growth from view | PASS | Independent account acceptance, 2026-07-29 |
| 3 | Account B does not display Account A Growth | PASS | Independent account acceptance, 2026-07-29 |
| 4 | Re-login to Account A restores Account A Growth | PASS | Independent account acceptance, 2026-07-29 |
| 5 | Authenticated-offline mode can use Growth | PASS | Independent account acceptance, 2026-07-29 |
| 6 | Binding-required state cannot enter Growth | PASS | Independent account acceptance, 2026-07-29 |

## I. UI And Accessibility

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Windows release opens Journal and Growth | PASS | Windows release acceptance, 2026-07-29 |
| 2 | Android arm64 release opens Journal and Growth | PASS | Android release acceptance, 2026-07-29 |
| 3 | Android portrait remains usable | PASS | Android release acceptance, 2026-07-29 |
| 4 | Narrow Windows layout remains usable | PASS | Windows release acceptance, 2026-07-29 |
| 5 | 320px width has no horizontal overflow | PASS | Narrow-layout acceptance, 2026-07-29 |
| 6 | Maximum font size keeps states and actions readable | PASS | Accessibility acceptance, 2026-07-29 |
| 7 | Complete pages remain scrollable | PASS | Windows and Android acceptance, 2026-07-29 |
| 8 | Charts and coverage labels remain understandable | PASS | Windows and Android acceptance, 2026-07-29 |
| 9 | Status and quality do not rely on color alone | PASS | Windows and Android acceptance, 2026-07-29 |
| 10 | Keyboard navigation reaches primary actions | PASS | Windows keyboard acceptance, 2026-07-29 |
| 11 | Back navigation changes no state silently | PASS | Windows and Android acceptance, 2026-07-29 |
| 12 | No RenderFlex or horizontal overflow occurs | PASS | Windows and Android acceptance, 2026-07-29 |
| 13 | No crash occurs | PASS | Windows and Android acceptance, 2026-07-29 |

## Final Gates

| Gate | Status | Notes |
|---|---|---|
| Growth System Product Gate | CLOSED / ACCEPTED | 71 executable product checks passed; six safe fault-injection rows remain not executed |
| Journal State Semantics Gate | CLOSED / ACCEPTED | Draft, complete, reopen, persistence, sync, and conflict checks passed |
| Account Boundary Isolation Gate | CLOSED / ACCEPTED | Retains Sprint 12A acceptance |

## Totals

| PASS | FAIL | NOT EXECUTED |
|---:|---:|---:|
| 71 | 0 | 6 |
