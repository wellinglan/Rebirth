# AI Coach MVP Product Experience Manual Acceptance

> Sprint: **16A**
> Gate: **AI Coach MVP Product Experience Gate**
> Current status: **CLOSED WITH ACCEPTED LIMITATIONS**
> Starting HEAD: `72eb4ac2b5161aeefad3f101ad08ea6eac05e10b`

## Evidence Rules

- Every row starts as `NOT EXECUTED`.
- Automated PASS does not become manual PASS.
- Real Provider rows require the user's explicit approval of Provider, Model,
  expected fee, and execution time immediately before the call.
- Use dedicated test records without secrets or sensitive real-world content.
- Do not record API keys, tokens, account IDs, source bodies, full report
  bodies, or private endpoints in this file.
- Fake Provider output cannot satisfy a real Provider row.

## A. Entry and Navigation

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| A1 | Windows clearly exposes `AI 教练` as a first-level destination | PASS | User-reported manual acceptance on 2026-08-10 |
| A2 | Android clearly exposes `AI 教练` in the primary navigation | PASS | User-reported physical-device acceptance on 2026-08-10 |
| A3 | `/ai-coach` consistently opens the canonical task home | PASS | User-reported manual acceptance on 2026-08-10 |
| A4 | Settings keeps AI consent/privacy but no longer acts as the main Coach or report-library entry | PASS | User-reported manual acceptance on 2026-08-10 |
| A5 | A legacy `/ai-coach/reports/:id` link safely reaches canonical report detail | PASS | User-reported manual acceptance on 2026-08-10 |

## B. Consent Round Trip

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| B1 | An unconsented user sees natural guidance and cannot generate | PASS | User-reported manual acceptance on 2026-08-10 |
| B2 | `设置 AI 授权` opens canonical consent and Back returns to AI Coach | PASS | User-reported manual acceptance on 2026-08-10 |
| B3 | Grant, revoke, and re-grant update the Coach immediately without automatic generation | PASS | User-reported manual acceptance on 2026-08-10 |

## C. Daily and Weekly Real Provider Flow

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| C1 | Daily flow selects only intended data and displays `本次使用的数据` | PASS | User-reported manual acceptance on 2026-08-10 |
| C2 | User explicitly confirms real Provider, Model, possible fee, and Daily execution | PASS | User confirmed the real-Provider Daily execution on 2026-08-10; no credentials or content recorded |
| C3 | One real Daily Insight completes and opens canonical report detail | PASS | User-reported real-Provider Daily result on 2026-08-10 |
| C4 | Weekly flow shows the correct seven-day range and intended data | PASS | User-reported manual acceptance on 2026-08-10 |
| C5 | User explicitly confirms real Provider, Model, possible fee, and Weekly execution | PASS | User confirmed the real-Provider Weekly execution on 2026-08-10; no credentials or content recorded |
| C6 | One real Weekly Report completes and opens canonical report detail | PASS | User-reported real-Provider Weekly result on 2026-08-10 |

## D. Reuse and Reports

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| D1 | Identical completed input offers the existing report and creates no duplicate call/report/version | PASS | User-reported manual acceptance on 2026-08-10 |
| D2 | Recent reports are concise and `查看全部` opens the canonical library | PASS | User-reported manual acceptance on 2026-08-10 |
| D3 | Leaving and re-entering AI Coach keeps completed reports accessible | PASS | User-reported manual acceptance on 2026-08-10 |
| D4 | Opening, viewing, or leaving AI Coach does not auto-generate or auto-sync | PASS | User-reported observation on 2026-08-10; automated call-count evidence also exists |

## E. Responsive and Accessibility

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| E1 | 320 px layout has no overflow and all primary actions remain reachable | PASS | User-reported manual visual acceptance on 2026-08-10 |
| E2 | 360 and 412 px layouts remain readable and navigable | PASS | User-reported manual visual acceptance on 2026-08-10 |
| E3 | Android maximum font size keeps navigation, cards, confirmation, and Back usable | PASS | User-reported physical-device acceptance on 2026-08-10 |
| E4 | Windows wide layout uses space reasonably and keeps first-level navigation clear | PASS | User-reported Windows acceptance on 2026-08-10 |
| E5 | Windows Tab, Shift+Tab, Enter, Space, and Escape behave correctly | PASS | User-reported keyboard acceptance on 2026-08-10 |
| E6 | Android Back returns from detail, flow, consent, and library naturally | PASS | User-reported physical-device acceptance on 2026-08-10 |
| E7 | Ordinary home and generation flow do not require understanding Prompt Version, Input Hash, Request Binding, or Gateway | PASS | User-reported language/product acceptance on 2026-08-10 |

## F. Privacy, Account, and Controlled Failure

| ID | Check | Status | Evidence / note |
|---|---|---|---|
| F1 | Switching from Account A to B shows no A report, quota, preview, or pending state | PASS | User-reported two-account acceptance on 2026-08-10 |
| F2 | Home/recent rows expose no body, token, endpoint, account ID, or internal report ID | PASS | User-reported privacy inspection on 2026-08-10 |
| F3 | A normal network loss is described without raw Provider/error codes and does not auto-retry | PASS | User-reported safe network-interruption acceptance on 2026-08-10 |
| F4 | Reached quota disables generation, preserves reports, and shows a natural reset time when known | PASS | User-reported quota-state acceptance on 2026-08-10 |

## G. Automated-only Fault Evidence

These rows remain manual `NOT EXECUTED`; their safety properties are covered by
named automated tests. No product fault-injection control should be added only
to change these statuses. On 2026-08-10 the user explicitly accepted the named
automated evidence in place of dangerous manual runtime injection.

| ID | Scenario | Status | Automated evidence |
|---|---|---|---|
| G1 | Concurrent duplicate submission | NOT EXECUTED | Coordinator single-flight tests |
| G2 | Request-ID idempotency | NOT EXECUTED | generation coordinator and Server idempotency regression |
| G3 | Request-binding write failure | NOT EXECUTED | binding failure coordinator tests |
| G4 | `outcome_unknown` injection | NOT EXECUTED | coordinator and controlled presentation tests |
| G5 | Provider timeout injection | NOT EXECUTED | generation-section and Server Provider tests |
| G6 | Account-switch timing injection | NOT EXECUTED | account-scoped invalidation and coordinator scope tests |
| G7 | SessionRejected injection | NOT EXECUTED | Auth Gate and export/report boundary tests |
| G8 | Quota concurrency and ledger consistency | NOT EXECUTED | Server PostgreSQL/multi-worker and usage-ledger tests |

## Current Totals

- PASS: `29`
- FAIL: `0`
- NOT EXECUTED: `8`

The Gate is **CLOSED WITH ACCEPTED LIMITATIONS**. All applicable product,
platform, consent, real-Provider Daily/Weekly, reuse, responsive, account, and
privacy rows passed. G1-G8 remain honestly `NOT EXECUTED`; their named
automated evidence was reviewed and explicitly accepted instead of adding
dangerous product fault-injection controls.
