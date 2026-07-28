# Manual Test: Legacy Sync Re-entry Remediation

> Sprint: 10B.3.1
> Initial status: all rows are `NOT EXECUTED`
> Flutter schema: 7
> API: 1
> Sync Protocol: 2
> Environment: Development + Fake Provider + Tailscale private Alpha

This matrix retests only `PROFILE-LEGACY-REENTRY-CONFLICT-001` and
`LEGACY-OWNERSHIP-STALE-EVIDENCE-001`. Do not record User Keys, tokens,
complete Endpoint values, private Profile/Goal content, raw JSON, or database
copies.

## Preconditions

1. Deploy the Sprint 10B.3.1 API image while retaining the existing
   PostgreSQL container and volume.
2. Install Windows and Android release clients from the same Sprint commit.
3. Confirm `/health` reports API `1` and Sync Protocol `2`.
4. Use the original disposable account A and its existing legacy local spaces.
5. Keep a separate disposable account B for rejection checks.
6. Record only build SHA, image tag, platform/version, date, result, and defect
   ID.

## A. Windows Profile Conflict Recovery

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Restart with the known Profile conflict still displays a pending Profile conflict | NOT EXECUTED | - | - |
| 2 | Settings displays both `保留本地 Profile` and `采用云端 Profile` | NOT EXECUTED | - | - |
| 3 | Generic Plan conflict count is not falsely changed by Profile status | NOT EXECUTED | - | - |
| 4 | Choosing `采用云端 Profile` opens a confirmation before any network action | NOT EXECUTED | - | - |
| 5 | Cancelling the dialog changes neither local nor cloud Profile | NOT EXECUTED | - | - |
| 6 | Confirming `采用云端 Profile` loads cloud Profile and clears the pending Profile conflict | NOT EXECUTED | - | - |
| 7 | Restart retains the adopted cloud Profile and normal manual-sync state | NOT EXECUTED | - | - |
| 8 | A second prepared conflict offers `保留本地 Profile` with confirmation | NOT EXECUTED | - | - |
| 9 | Confirming `保留本地 Profile` uploads current local content and clears the conflict | NOT EXECUTED | - | - |
| 10 | Android account A can later pull the explicitly retained Profile | NOT EXECUTED | - | - |
| 11 | Network failure preserves local Profile, conflict state, and retry actions | NOT EXECUTED | - | - |
| 12 | Repeated taps cannot start concurrent recovery requests | NOT EXECUTED | - | - |

Windows Profile total: `0 PASS / 0 FAIL / 12 NOT EXECUTED`.

## B. Stale Same-account Goal Evidence

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows account A verifies and manually advances an existing Goal | NOT EXECUTED | - | - |
| 2 | Android account A retains the older synced metadata for that same Goal UUID | NOT EXECUTED | - | - |
| 3 | Android verification returns verified, not rejected | NOT EXECUTED | - | - |
| 4 | Verification does not automatically start Profile or Plan sync | NOT EXECUTED | - | - |
| 5 | Android Profile and Plan controls unlock only after verified is persisted | NOT EXECUTED | - | - |
| 6 | Android manual Plan sync receives the newer Goal without duplication | NOT EXECUTED | - | - |
| 7 | Goal hierarchy and completion state remain correct | NOT EXECUTED | - | - |
| 8 | Restart retains verified eligibility and synchronized data | NOT EXECUTED | - | - |

Stale evidence total: `0 PASS / 0 FAIL / 8 NOT EXECUTED`.

## C. Ownership Rejection Boundaries

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Account B presenting account A's Goal UUID is rejected even when its version is old | NOT EXECUTED | - | - |
| 2 | Rejection exposes no account A identity or business content | NOT EXECUTED | - | - |
| 3 | Account B Profile and Plan sync remain disabled and retryable | NOT EXECUTED | - | - |
| 4 | Stale Profile-only evidence returns unknown rather than verified | NOT EXECUTED | - | - |
| 5 | Exact current-account Profile-only evidence can still verify | NOT EXECUTED | - | - |
| 6 | Network failure persists no false verified decision | NOT EXECUTED | - | - |

Ownership boundary total: `0 PASS / 0 FAIL / 6 NOT EXECUTED`.

## D. Preservation And UI

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Ownership verification leaves Profile/Goal business data unchanged | NOT EXECUTED | - | - |
| 2 | Verification leaves cursor, conflict records, versions, and tombstones unchanged | NOT EXECUTED | - | - |
| 3 | Today, Journal, Health, Growth, AI pending state, and AI Consent remain unchanged | NOT EXECUTED | - | - |
| 4 | Windows recovery actions are readable and operable | NOT EXECUTED | - | - |
| 5 | Android portrait recovery actions have no horizontal overflow | NOT EXECUTED | - | - |
| 6 | Android maximum font keeps status, confirmation, and actions readable | NOT EXECUTED | - | - |
| 7 | Android Back, cancellation, and restart remain safe | NOT EXECUTED | - | - |
| 8 | No crash, hidden primary action, silent overwrite, or automatic sync occurs | NOT EXECUTED | - | - |

Preservation/UI total: `0 PASS / 0 FAIL / 8 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows Profile recovery | 0 | 0 | 12 |
| Stale same-account evidence | 0 | 0 | 8 |
| Ownership rejection boundaries | 0 | 0 | 6 |
| Preservation and UI | 0 | 0 | 8 |
| **Total** | **0** | **0** | **34** |

Release Gate: `OPEN / NOT EXECUTED`.

Do not close Sprint 10B.3.1 or start Sprint 11 synchronization until every
required row passes or each failure has an approved disposition.
