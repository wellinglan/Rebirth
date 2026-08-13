# AI Coach Feedback and Quality Signal Manual Acceptance

> Sprint: **16B**
> Gate: **AI Coach Feedback & Quality Signal Gate**
> Current status: **OPEN / SUSPENDED AFTER DEPLOYMENT CHECKS**
> Starting HEAD: `260356faf79deac1c72b8dd6f97f938185a4e6e3`
> Implementation artifact: **reviewed implementation commit `6b0f880`; Alpha deployment pending**

## Evidence Rules

- Every row starts as `NOT EXECUTED`; automation never pre-fills manual PASS.
- Use dedicated accounts and reports without sensitive real-world content.
- Do not record tokens, credentials, private endpoints, account IDs, report
  bodies, source bodies, or Prompt text in this file.
- Cross-device rows require the same authenticated account and explicit manual
  AI Report sync. Opening a page must never count as synchronization.
- Fault scenarios without a safe product-level injection remain
  `NOT EXECUTED` and cite automated evidence; do not add debug controls merely
  to turn them into manual PASS.

## A. Local Feedback Product Flow

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Open a completed Daily Insight on Windows and choose `有帮助` | Save succeeds and the choice remains visible | NOT EXECUTED | - |
| A2 | Leave detail and reopen the same version | The saved choice is restored without generation or sync | NOT EXECUTED | - |
| A3 | Choose `没帮助` without a reason | Save remains disabled and no row is changed | NOT EXECUTED | - |
| A4 | Choose `没帮助` with two fixed reasons and save | Both reasons remain selected in canonical order | NOT EXECUTED | - |
| A5 | Change negative feedback to `有帮助` | The negative reasons are cleared | NOT EXECUTED | - |
| A6 | Change `有帮助` back to a valid negative selection | One aggregate is updated; no duplicate feedback appears | NOT EXECUTED | - |
| A7 | Clear feedback | The version returns to an unreviewed state and local content is preserved | NOT EXECUTED | - |

## B. Android, Offline, and Cross-device Convergence

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| B1 | On Android, rate a completed Weekly Report | The structured feedback saves locally | NOT EXECUTED | - |
| B2 | Disconnect the network, modify feedback, and save | Local UI updates; report and feedback are not lost | NOT EXECUTED | - |
| B3 | Reopen the app while still offline | The local pending selection remains; no automatic upload starts | NOT EXECUTED | - |
| B4 | Restore the network and explicitly sync AI Report | Report sync runs first, then pending feedback converges | NOT EXECUTED | - |
| B5 | Pull on the other device | Windows-to-Android feedback appears on the exact version | NOT EXECUTED | - |
| B6 | Modify on Android, explicitly sync, then pull on Windows | Android-to-Windows modification converges without a duplicate row | NOT EXECUTED | - |
| B7 | Create a controlled two-device feedback conflict | The UI offers Adopt Remote and Keep Local; resolution clears the conflict | NOT EXECUTED | - |

## C. Version, Lifecycle, Deletion, and Account Boundary

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Rate two completed versions of one report differently | Each immutable version retains independent feedback | NOT EXECUTED | - |
| C2 | Archive a completed report and open its detail/history | Existing completed versions remain readable and rateable | NOT EXECUTED | - |
| C3 | Inspect failed, pending, generating, outcome-unknown, or bodyless state | No feedback control is offered | NOT EXECUTED | Use available natural states only |
| C4 | Delete a report that has synced feedback, then explicitly sync | Report and feedback tombstones converge; deleted detail is not rateable | NOT EXECUTED | - |
| C5 | Sign out Account A and sign in Account B | B cannot see, edit, export, pull, or resolve A feedback | NOT EXECUTED | - |

## D. Export and Privacy

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Export all personal data after creating feedback | Manifest includes optional `ai_report_feedback` and correct records | NOT EXECUTED | - |
| D2 | Inspect exported feedback objects | Business selection/timestamps exist; sync/conflict/server metadata does not | NOT EXECUTED | Do not paste sensitive export content here |
| D3 | Inspect ordinary feedback UI | There is no free-text field or `其他，请说明` | NOT EXECUTED | - |
| D4 | Inspect detail, history, error, and conflict states | No Prompt version, input hash, Provider/model, IDs, or server version appears | NOT EXECUTED | - |
| D5 | Save feedback and generate nothing | No generation, Prompt activation, quota use, or report version is created | NOT EXECUTED | - |

## E. Responsive and Accessibility

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Render report detail at 320 px | Controls wrap without horizontal overflow and remain reachable | NOT EXECUTED | - |
| E2 | Test Android maximum font size | Labels, reasons, Save, Clear, and conflict actions remain readable | NOT EXECUTED | - |
| E3 | Test Windows wide layout | Feedback stays compact inside canonical detail | NOT EXECUTED | - |
| E4 | Use Tab, Shift+Tab, Enter, and Space on Windows | Segments, chips, Save, Clear, and conflict actions are operable | NOT EXECUTED | - |
| E5 | Use Android Back from detail and history | Navigation returns naturally and does not discard a saved choice | NOT EXECUTED | - |
| E6 | Inspect screen-reader labels | Helpful choices and fixed reasons have readable semantics | NOT EXECUTED | - |

## F. Alpha Operations

| ID | Check | Expected result | Status | Evidence / note |
|---|---|---|---|---|
| F1 | Record exact Alpha API image and migration before testing | Image identifies the reviewed commit and Alembic is `20260812_0008` | PASS | User reported deployment batch PASS on 2026-08-12; reviewed full-SHA image and migration were checked |
| F2 | Verify `/health` after deployment | API is healthy with API Version 1 and Sync Protocol 2 | PASS | User reported API healthy, Version 1, and Sync Protocol 2 |
| F3 | Run `feedback-audit --days 30` on controlled data | Only aggregate counts/rates appear; no IDs, body, Prompt text, token, or secret | NOT EXECUTED | - |
| F4 | Distinguish image publication from deployment | GHCR result and live Alpha identity are recorded separately | PASS | User separately verified GHCR digest and live Alpha image identity |

## G. Automated-only Fault Evidence

| ID | Scenario | Status | Automated evidence |
|---|---|---|---|
| G1 | Concurrent OCC update has exactly one winner | NOT EXECUTED | PostgreSQL multiprocessing feedback OCC marker |
| G2 | Local database write failure preserves product state | NOT EXECUTED | Repository/controller failure tests |
| G3 | Feedback API timeout after successful report sync | NOT EXECUTED | AI Report sync partial-result tests |
| G4 | Account switch during pending feedback operation | NOT EXECUTED | Account invalidation and repository account-scope tests |
| G5 | Migration downgrade/re-upgrade and multi-worker behavior | NOT EXECUTED | Drift migration, Alembic, PostgreSQL, and CI markers |

## Current Totals

- PASS: `3`
- FAIL: `0`
- NOT EXECUTED: `36`

Current result: **3 PASS / 0 FAIL / 36 NOT EXECUTED**.

The Gate remains **OPEN / SUSPENDED**. Local save, modification, clear, cross-device
convergence, export, Windows/Android product behavior, and Alpha deployment
product behavior remain required manual evidence and cannot be closed by
automation alone. Completed deployment identity evidence remains valid.
