# Manual Test: Legacy Cloud Ownership Verification

> Sprint: 10B.3
> Initial status: all rows are `NOT EXECUTED`
> Flutter schema: 7
> API: 1
> Sync Protocol: 2
> Environment: Development + Fake Provider + Tailscale private Alpha

This matrix verifies explicit metadata ownership proof and manual sync
re-entry. Never record Development User Keys, tokens, complete Endpoint or
identity values, private Profile/Goal content, health data, AI content, raw
JSON, or database copies as evidence.

## Preconditions

1. Deploy the Sprint 10B.3 API image without rebuilding PostgreSQL or deleting
   its volume.
2. Install Windows and Android release clients built from the same commit.
3. Confirm `/health` reports API `1` and Sync Protocol `2`.
4. Prepare disposable accounts A and B and a backed-up legacy-claimed space
   with known Profile/Plan cloud history.
5. Record only build SHA, image tag, platform/version, test date, redacted
   Endpoint class, result, and defect ID.

## A. Windows Verified Re-entry

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Legacy claim opens local data with `legacy_review_required` | NOT EXECUTED | - | - |
| 2 | Settings shows waiting verification and disabled Profile/Plan sync | NOT EXECUTED | - | - |
| 3 | `验证云同步资格` is visible and repeated taps are blocked | NOT EXECUTED | - | - |
| 4 | Verification against account A's original Server returns verified | NOT EXECUTED | - | - |
| 5 | Settings reports sync available without starting an automatic sync | NOT EXECUTED | - | - |
| 6 | Existing cursor, conflict count, tombstones, and local data are unchanged immediately after verification | NOT EXECUTED | - | - |
| 7 | Manual Profile sync succeeds only after explicit user action | NOT EXECUTED | - | - |
| 8 | Manual Plan sync succeeds only after explicit user action | NOT EXECUTED | - | - |
| 9 | Restart restores verified eligibility and the same local space | NOT EXECUTED | - | - |

Windows verified total: `0 PASS / 0 FAIL / 9 NOT EXECUTED`.

## B. Windows Unknown And Rejected

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | A legacy space with no verifiable remote row returns unknown | NOT EXECUTED | - | - |
| 2 | Unknown keeps Profile and Plan sync disabled | NOT EXECUTED | - | - |
| 3 | Unknown preserves all local data and allows retry | NOT EXECUTED | - | - |
| 4 | Account B cannot verify exact metadata owned by account A | NOT EXECUTED | - | - |
| 5 | Rejected state is displayed without exposing A's identity or content | NOT EXECUTED | - | - |
| 6 | Rejected keeps Profile and Plan sync disabled | NOT EXECUTED | - | - |
| 7 | Network failure writes no verified/failed decision and allows retry | NOT EXECUTED | - | - |
| 8 | Session change during verification rejects the result | NOT EXECUTED | - | - |

Windows blocked outcomes total: `0 PASS / 0 FAIL / 8 NOT EXECUTED`.

## C. Android

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Legacy waiting state and verification button render without overflow | NOT EXECUTED | - | - |
| 2 | Verification succeeds for known account-owned history | NOT EXECUTED | - | - |
| 3 | Profile and Plan controls unlock without automatic sync | NOT EXECUTED | - | - |
| 4 | Unknown/rejected results remain blocked and retryable | NOT EXECUTED | - | - |
| 5 | Maximum font size keeps status, button, and result readable | NOT EXECUTED | - | - |
| 6 | Android Back and app restart preserve the correct state | NOT EXECUTED | - | - |
| 7 | No crash, horizontal overflow, or hidden primary action | NOT EXECUTED | - | - |

Android total: `0 PASS / 0 FAIL / 7 NOT EXECUTED`.

## D. Cross-device And Endpoint Isolation

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows verifies A, then Android A can use its independently bound ready cache | NOT EXECUTED | - | - |
| 2 | Manual Plan sync still preserves hierarchy across both devices | NOT EXECUTED | - | - |
| 3 | Account B cannot verify or access A's historical space | NOT EXECUTED | - | - |
| 4 | Changing to an Endpoint without matching evidence returns unknown | NOT EXECUTED | - | - |
| 5 | Endpoint change never reassigns cursor or conflict history | NOT EXECUTED | - | - |
| 6 | Today, Journal, Health, Growth, and AI remain outside sync | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 0 FAIL / 6 NOT EXECUTED`.

## E. Data Protection

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Verification does not modify Profile/Goal business fields | NOT EXECUTED | - | - |
| 2 | Verification does not reset `serverVersion`, `lastSyncedAt`, or `syncStatus` | NOT EXECUTED | - | - |
| 3 | Verification does not clear or advance the cursor | NOT EXECUTED | - | - |
| 4 | Verification does not delete, resolve, or recreate conflicts | NOT EXECUTED | - | - |
| 5 | Verification does not modify tombstones | NOT EXECUTED | - | - |
| 6 | AI pending state and AI Consent remain unchanged | NOT EXECUTED | - | - |
| 7 | Failure or cancellation leaves eligibility quarantined | NOT EXECUTED | - | - |

Data protection total: `0 PASS / 0 FAIL / 7 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows verified re-entry | 0 | 0 | 9 |
| Windows blocked outcomes | 0 | 0 | 8 |
| Android | 0 | 0 | 7 |
| Cross-device | 0 | 0 | 6 |
| Data protection | 0 | 0 | 7 |
| **Total** | **0** | **0** | **37** |

Release Gate: `OPEN / NOT EXECUTED`.

Do not declare legacy cloud ownership accepted or start Sprint 11
Today/Journal/Health sync until every required row passes or each failure has
an approved defect disposition.
