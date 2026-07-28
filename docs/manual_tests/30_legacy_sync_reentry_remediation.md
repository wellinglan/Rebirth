# Manual Test: Legacy Sync Re-entry Remediation

> Sprint: 10B.3.1
> Execution date: 2026-07-28
> Status: partially executed; exercised remediation paths passed
> Build: `97cc97fecfcebc98d5e90bba79c0497350fb5c8c`
> API image: `ghcr.io/wellinglan/rebirth-api:97cc97fecfcebc98d5e90bba79c0497350fb5c8c`
> Flutter schema: 7
> API: 1
> Sync Protocol: 2
> Environment: Development + Fake Provider + Tailscale private Alpha

This matrix retests only `PROFILE-LEGACY-REENTRY-CONFLICT-001` and
`LEGACY-OWNERSHIP-STALE-EVIDENCE-001`. It records no User Keys, tokens,
complete Endpoint values, private Profile/Goal content, raw JSON, or database
copies.

## Test Environment

- Windows release client started successfully.
- Android release client used the arm64-v8a APK.
- Android device: OnePlus 15T, `PLZ110_16.0.9.400`.
- The updated API reused the existing PostgreSQL container and volume.
- `/health` reported API `1` and Sync Protocol `2`.
- Windows and Android used the same disposable account A.
- No independent legacy local space or spare installation was available for
  account B rejection testing. Those rows remain `NOT EXECUTED`; automated
  coverage is not reported as manual PASS.

## A. Windows Profile Conflict Recovery

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Restart with the known Profile conflict still displays a pending Profile conflict | PASS | Existing conflict remained visible after restart | - |
| 2 | Settings displays both `保留本地 Profile` and `采用云端 Profile` | PASS | Both recovery actions were visible | - |
| 3 | Generic Plan conflict count is not falsely changed by Profile status | PASS | Plan conflict count stayed unchanged | - |
| 4 | Choosing `采用云端 Profile` opens a confirmation before any network action | PASS | Confirmation appeared before recovery | - |
| 5 | Cancelling the dialog changes neither local nor cloud Profile | PASS | Cancellation preserved both sides | - |
| 6 | Confirming `采用云端 Profile` loads cloud Profile and clears the pending Profile conflict | PASS | Cloud content loaded and Profile conflict cleared | - |
| 7 | Restart retains the adopted cloud Profile and normal manual-sync state | PASS | Adopted content and ready state persisted | - |
| 8 | A second prepared conflict offers `保留本地 Profile` with confirmation | PASS | Keep-local confirmation appeared | - |
| 9 | Confirming `保留本地 Profile` uploads current local content and clears the conflict | PASS | Local content became the cloud version and conflict cleared | - |
| 10 | Android account A can later pull the explicitly retained Profile | PASS | Android received the retained Windows Profile | - |
| 11 | Network failure preserves local Profile, conflict state, and retry actions | PASS | Offline recovery failed safely; retry succeeded after reconnect | - |
| 12 | Repeated taps cannot start concurrent recovery requests | PASS | Busy state prevented concurrent recovery | - |

Windows Profile total: `12 PASS / 0 FAIL / 0 NOT EXECUTED`.

## B. Stale Same-account Goal Evidence

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Windows account A verifies and manually advances an existing Goal | PASS | Windows advanced the existing Goal under account A | - |
| 2 | Android account A retains the older synced metadata for that same Goal UUID | PASS | Android held the legitimate older metadata before verification | - |
| 3 | Android verification returns verified, not rejected | PASS | Ownership verification returned verified | - |
| 4 | Verification does not automatically start Profile or Plan sync | PASS | No automatic synchronization occurred | - |
| 5 | Android Profile and Plan controls unlock only after verified is persisted | PASS | Controls unlocked after verified state was stored | - |
| 6 | Android manual Plan sync receives the newer Goal without duplication | PASS | Newer Goal arrived through explicit sync with no duplicate | - |
| 7 | Goal hierarchy and completion state remain correct | PASS | Hierarchy and completion remained correct | - |
| 8 | Restart retains verified eligibility and synchronized data | PASS | Eligibility and data survived restart | - |

Stale evidence total: `8 PASS / 0 FAIL / 0 NOT EXECUTED`.

## C. Ownership Rejection Boundaries

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Account B presenting account A's Goal UUID is rejected even when its version is old | NOT EXECUTED | No isolated legacy space or spare installation was available | - |
| 2 | Rejection exposes no account A identity or business content | NOT EXECUTED | Depends on the unavailable account B fixture | - |
| 3 | Account B Profile and Plan sync remain disabled and retryable | NOT EXECUTED | Depends on the unavailable account B fixture | - |
| 4 | Stale Profile-only evidence returns unknown rather than verified | NOT EXECUTED | No safe isolated Profile-only legacy fixture was available | - |
| 5 | Exact current-account Profile-only evidence can still verify | NOT EXECUTED | No safe isolated Profile-only legacy fixture was available | - |
| 6 | Network failure persists no false verified decision | NOT EXECUTED | No isolated unverified fixture was available | - |

Ownership boundary total: `0 PASS / 0 FAIL / 6 NOT EXECUTED`.

The corresponding Server and Flutter automated tests pass, but they do not
replace the missing manual account B evidence.

## D. Preservation And UI

| # | Check | Result | Evidence | Defect ID |
|---|---|---|---|---|
| 1 | Ownership verification leaves Profile/Goal business data unchanged | PASS | Before/after content checks found no verification-side mutation | - |
| 2 | Verification leaves cursor, conflict records, versions, and tombstones unchanged | NOT EXECUTED | User-visible checks passed, but every internal field was not inspected manually | - |
| 3 | Today, Journal, Health, Growth, AI pending state, and AI Consent remain unchanged | PASS | Unrelated local modules and consent state remained intact | - |
| 4 | Windows recovery actions are readable and operable | PASS | Both actions and confirmations were exercised | - |
| 5 | Android portrait recovery actions have no horizontal overflow | PASS | Portrait conflict UI displayed without overflow | - |
| 6 | Android maximum font keeps status, confirmation, and actions readable | PASS | Maximum system font remained readable and scrollable | - |
| 7 | Android Back, cancellation, and restart remain safe | PASS | Back/cancel caused no recovery; restart retained correct state | - |
| 8 | No crash, hidden primary action, silent overwrite, or automatic sync occurs | PASS | No such behavior was observed across the exercised flows | - |

Preservation/UI total: `7 PASS / 0 FAIL / 1 NOT EXECUTED`.

## Final Gate

| Area | PASS | FAIL | NOT EXECUTED |
|---|---:|---:|---:|
| Windows Profile recovery | 12 | 0 | 0 |
| Stale same-account evidence | 8 | 0 | 0 |
| Ownership rejection boundaries | 0 | 0 | 6 |
| Preservation and UI | 7 | 0 | 1 |
| **Total** | **27** | **0** | **7** |

Release Gate: `OPEN / PARTIAL ACCEPTANCE`.

Both reported remediation defects passed in the available Windows, Android,
cross-device, restart, and network-failure scenarios. The gate remains open
because account B rejection boundaries and one internal preservation audit
could not be executed safely without an independent test environment.

Do not clear the working Alpha database or overwrite account A evidence merely
to close the matrix. Do not start Sprint 11 synchronization until the seven
remaining rows are executed in an isolated environment or receive an explicit
approved release disposition.
