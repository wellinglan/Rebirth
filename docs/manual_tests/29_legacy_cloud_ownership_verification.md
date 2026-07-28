# Manual Test: Legacy Cloud Ownership Verification

> Sprint: 10B.3
> Execution date: 2026-07-28
> Status: executed in part; release blockers recorded below
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
| 1 | Legacy claim opens local data with `legacy_review_required` | PASS | Waiting state displayed | - |
| 2 | Settings shows waiting verification and disabled Profile/Plan sync | PASS | Controls disabled before verification | - |
| 3 | `验证云同步资格` is visible and repeated taps are blocked | PASS | Repeated action blocked | - |
| 4 | Verification against account A's original Server returns verified | PASS | Result: verified | - |
| 5 | Settings reports sync available without starting an automatic sync | PASS | No automatic request observed | - |
| 6 | Existing cursor, conflict count, tombstones, and local data are unchanged immediately after verification | PASS | Cursor, conflict count, and local data unchanged; tombstone-specific check remains pending below | - |
| 7 | Manual Profile sync succeeds only after explicit user action | FAIL | Upload conflicts; pull reports no update; retry conflicts again while active conflict count remains zero | PROFILE-LEGACY-REENTRY-CONFLICT-001 |
| 8 | Manual Plan sync succeeds only after explicit user action | PASS | Uploaded 2, pulled 0, deleted 0, conflicts 0 | - |
| 9 | Restart restores verified eligibility and the same local space | PASS | State and data retained | - |

Windows verified total: `8 PASS / 1 FAIL / 0 NOT EXECUTED`.

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
| 1 | Legacy waiting state and verification button render without overflow | PASS | Android release client | - |
| 2 | Verification succeeds for known account-owned history | FAIL | Same account held legitimate older Goal metadata after Windows advanced the remote version; Server returned rejected | LEGACY-OWNERSHIP-STALE-EVIDENCE-001 |
| 3 | Profile and Plan controls unlock without automatic sync | FAIL | Controls correctly stayed disabled after rejection | LEGACY-OWNERSHIP-STALE-EVIDENCE-001 |
| 4 | Unknown/rejected results remain blocked and retryable | PASS | Retry remains available; Profile/Plan stay disabled | - |
| 5 | Maximum font size keeps status, button, and result readable | PASS | No overflow observed | - |
| 6 | Android Back and app restart preserve the correct state | PASS | Failed state retained | - |
| 7 | No crash, horizontal overflow, or hidden primary action | PASS | Navigation remained usable | - |

Android total: `5 PASS / 2 FAIL / 0 NOT EXECUTED`.

## D. Cross-device And Endpoint Isolation

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows verifies A, then Android A can use its independently bound ready cache | FAIL | Android A was rejected after Windows A advanced the same Goal | LEGACY-OWNERSHIP-STALE-EVIDENCE-001 |
| 2 | Manual Plan sync still preserves hierarchy across both devices | NOT EXECUTED | - | - |
| 3 | Account B cannot verify or access A's historical space | NOT EXECUTED | - | - |
| 4 | Changing to an Endpoint without matching evidence returns unknown | NOT EXECUTED | - | - |
| 5 | Endpoint change never reassigns cursor or conflict history | NOT EXECUTED | - | - |
| 6 | Today, Journal, Health, Growth, and AI remain outside sync | NOT EXECUTED | - | - |

Cross-device total: `0 PASS / 1 FAIL / 5 NOT EXECUTED`.

## E. Data Protection

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Verification does not modify Profile/Goal business fields | PASS | Local content unchanged | - |
| 2 | Verification does not reset `serverVersion`, `lastSyncedAt`, or `syncStatus` | NOT EXECUTED | - | - |
| 3 | Verification does not clear or advance the cursor | PASS | Cursor unchanged | - |
| 4 | Verification does not delete, resolve, or recreate conflicts | PASS | Conflict state unchanged | - |
| 5 | Verification does not modify tombstones | NOT EXECUTED | - | - |
| 6 | AI pending state and AI Consent remain unchanged | PASS | AI Consent unchanged | - |
| 7 | Failure or cancellation leaves eligibility quarantined | PASS | Rejected Android state remained blocked after restart | - |

Data protection total: `5 PASS / 0 FAIL / 2 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows verified re-entry | 8 | 1 | 0 |
| Windows blocked outcomes | 0 | 0 | 8 |
| Android | 5 | 2 | 0 |
| Cross-device | 0 | 1 | 5 |
| Data protection | 5 | 0 | 2 |
| **Total** | **18** | **4** | **15** |

Release Gate: `BLOCKED`.

Blocking defects:

- `PROFILE-LEGACY-REENTRY-CONFLICT-001`;
- `LEGACY-OWNERSHIP-STALE-EVIDENCE-001`.

Sprint 10B.3.1 remediation and its clean retest matrix are documented in
`docs/24_LEGACY_SYNC_REENTRY_REMEDIATION.md` and
`docs/manual_tests/30_legacy_sync_reentry_remediation.md`.

Do not declare legacy cloud ownership accepted or start Sprint 11
Today/Journal/Health sync until every required row passes or each failure has
an approved defect disposition.
