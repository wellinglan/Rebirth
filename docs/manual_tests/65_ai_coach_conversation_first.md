# Sprint 18B Conversation-first AI Coach Manual Acceptance

> Sprint: **18B**
> Candidate source baseline: `be16fdd4caa2d2af980dfddb902da5bb299fea2d`
> Matrix status: **ACCEPTED WITH AUTOMATED SUBSTITUTIONS**
> Result: **46 PASS / 0 FAIL / 8 NOT EXECUTED**
> Gate: **CLOSED WITH ACCEPTED AUTOMATED SUBSTITUTIONS**

Automated evidence never becomes manual PASS. Unsafe fault and multi-worker
rows may remain `NOT EXECUTED` only with the named automated substitute.

## Preconditions

- Quality and Publish Alpha Images pass for the final full-SHA Candidate.
- Beijing Alpha pulls the exact image and records its digest.
- Alembic reaches `20260822_0009`; only API is recreated. PostgreSQL and its
  volume remain running.
- `/health` returns HTTP 200, API Version `1`, and Sync Protocol `2`.
- `config-check` safely shows Chat 50000, Report 50000, global 250000, and
  request maximum 20000.
- Rebuild Windows Release and the `arm64-v8a` Android Release APK against the
  Candidate endpoint. Use two disposable Alpha accounts.

## A. Candidate, Migration, And Compatibility

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| A1 | Record full-SHA image and digest. | Both match final 18B publication. | PASS | User-confirmed deployed Alpha Candidate identity. |
| A2 | Run normal Alembic upgrade. | Head is `20260822_0009`; no data loss. | PASS | User-confirmed deployment migration result. |
| A3 | Recreate only API and inspect services. | API healthy; PostgreSQL was not recreated. | PASS | User-confirmed API-only recreation. |
| A4 | Call `/health`. | HTTP 200, API 1, Sync Protocol 2. | PASS | User-confirmed Alpha health check. |
| A5 | Run `config-check`. | Four token controls appear; no secret or database URL. | PASS | User-confirmed server-only configuration check. |
| A6 | Call authenticated Usage V1 and V2. | V1 still responds; V2 separates Chat/Report Token budgets. | PASS | User-confirmed compatibility and budget isolation check. |

## B. Conversation-first Entry And Navigation

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| B1 | Open first-level AI Coach. | Conversation opens directly, not old overview. | PASS | User-confirmed Windows and Android flow. |
| B2 | Open `/ai-coach/chat`. | Same conversation opens without loop. | PASS | User-confirmed compatibility route. |
| B3 | Inspect AppBar. | History, new thread, report library, consent are compact and reachable. | PASS | User-confirmed cross-platform layout. |
| B4 | Inspect above composer. | Reference, Daily, and Weekly actions are visible. | PASS | User-confirmed action reachability. |
| B5 | Wait without interaction. | No AI, report, sync, or usage change. | PASS | User-confirmed idle behavior. |
| B6 | Open history and return. | Draft and conversation remain. | PASS | User-confirmed local state preservation. |
| B7 | Open report library/consent and return. | No message or generation is created. | PASS | User-confirmed non-generating navigation. |

## C. Token Budget And Account Isolation

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Inspect fresh Chat budget. | UI uses Token, not remaining request count, and shows local reset time. | PASS | User-confirmed Token UI. |
| C2 | Send one ordinary message. | Used Token increases once after success. | PASS | User-confirmed successful generation accounting. |
| C3 | Send with explicit context. | Input context contributes to usage; only selected scopes are sent. | PASS | User-confirmed explicit-context behavior. |
| C4 | Rapidly activate Send. | One Provider call and one charge. | PASS | User-confirmed; widget and Server idempotency tests are supporting evidence. |
| C5 | Reopen/recover a completed request. | Result reuses the same request without another charge. | PASS | User-confirmed completed-result recovery. |
| C6 | Reach/inject 50k boundary safely. | Chat blocks; Report budget remains independent. | NOT EXECUTED | Exact automated boundary evidence allowed. |
| C7 | Generate a report after Chat use. | Report consumes only Report budget. | PASS | User-confirmed independent report budget. |
| C8 | Switch Account A to B. | B has an independent budget and local history. | PASS | User-confirmed account isolation. |
| C9 | Cross UTC reset safely. | Both budgets reset at UTC boundary. | NOT EXECUTED | Usually automated-only. |

## D. Daily And Weekly Report Actions

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Select Chat Health, then open Daily. | Daily starts empty; Chat selection is unchanged. | PASS | User-confirmed independent selection state. |
| D2 | Inspect Daily scopes. | Today/Health/Journal only; Growth absent. | PASS | User-confirmed scope boundary. |
| D3 | Inspect Daily date. | Current local natural date. | PASS | User-confirmed local-date behavior. |
| D4 | Cancel Daily and open Weekly. | Weekly starts empty and adds Growth. | PASS | User-confirmed independent selection state. |
| D5 | Inspect Weekly period. | Most recent seven local natural dates. | PASS | User-confirmed date-range behavior. |
| D6 | Select Journal and cancel warning. | It remains unselected; no call occurs. | PASS | User-confirmed privacy cancellation. |
| D7 | Confirm Journal warning. | Selection visible; no call before final confirmation. | PASS | User-confirmed explicit selection. |
| D8 | Continue from quick picker. | Canonical preview shows sources, Provider, privacy/cost warning, confirmation. | PASS | User-confirmed preview and confirmation. |
| D9 | Cancel final confirmation. | No pending report, call, or charge. | PASS | User-confirmed cancellation behavior. |
| D10 | Submit identical completed input. | Existing report is offered/reused without duplicate charge. | PASS | User-confirmed reuse behavior. |

## E. Chinese Reports, Persistence, And Sync

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Generate Daily with authorized real Provider. | All user-visible report content is Simplified Chinese. | PASS | User-confirmed authorized Provider result. |
| E2 | Generate Weekly with authorized real Provider. | All user-visible report content is Simplified Chinese. | PASS | User-confirmed authorized Provider result. |
| E3 | Inspect metadata where supported. | New reports use v3; Prompt text/fingerprint remain hidden. | PASS | User-confirmed privacy-safe metadata. |
| E4 | Open old v1 report. | Original text remains; no translation/regeneration. | NOT EXECUTED | Historical report required. |
| E5 | Return after generation. | Report reference appears; body is not copied into a message. | PASS | User-confirmed Chat/report boundary. |
| E6 | Send another text-only turn. | Report body/reference is not attached automatically. | PASS | User-confirmed text-only default. |
| E7 | Sync Reports across Windows/Android. | Report syncs; Chat thread does not. | PASS | User-confirmed cross-device boundary. |

## F. Failure, Reservation, Privacy, And Regression

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| F1 | Revoke consent and try Chat/Report. | New calls block; history/reports remain readable. | PASS | User-confirmed consent boundary. |
| F2 | Restore consent. | Nothing auto-sends or auto-generates. | PASS | User-confirmed explicit-action recovery. |
| F3 | Disable Provider in controlled window. | Fail closed without Provider call or charge. | NOT EXECUTED | Automated substitute accepted if no window. |
| F4 | Trigger pre-Provider rejection. | Reservation releases; no Token charged. | NOT EXECUTED | Automated-only if no safe fixture. |
| F5 | Trigger Provider failure without usage. | Conservative estimate charges once; error controlled. | NOT EXECUTED | Safe fixture or automation. |
| F6 | Trigger timeout/outcome unknown. | Reservation remains until status/lease; no auto-retry. | NOT EXECUTED | Safe fixture or lease automation. |
| F7 | Review logs. | No content, Prompt, Authorization, key, secret, or full user ID. | NOT EXECUTED | Controlled review pending. |
| F8 | Smoke Profile, Plan, Today, Journal, Health, Growth, export, report conflict, Sync All. | Existing behavior remains; Chat creates no business write. | PASS | User-confirmed product regression smoke. |

## G. Responsive, Keyboard, And Accessibility

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| G1 | Use 320px-equivalent Android. | Three actions wrap with no overflow. | PASS | User-confirmed narrow-phone layout. |
| G2 | Use 360px and 412px. | Conversation, picker, composer, references stay reachable. | PASS | User-confirmed phone layouts. |
| G3 | Use 720px. | No accidental wide split or hidden action. | PASS | User-confirmed compact wide layout. |
| G4 | Use 1200px Windows. | Thread pane and conversation are readable. | PASS | User-confirmed Windows layout. |
| G5 | Set TextScaler 2.0. | No clipping, overlap, or unreachable confirmation. | PASS | User-confirmed large-text layout. |
| G6 | Use Tab, Enter, Space, Enter-send, Shift+Enter. | Focus/actions work once; Shift+Enter adds newline. | PASS | User-confirmed keyboard contract. |
| G7 | Use TalkBack on budget/actions/messages/references. | Labels explain role, Token unit, and report-reference behavior. | PASS | User-confirmed Android accessibility. |

## Automated Substitutes Available

- `server/tests/test_ai_token_budget.py`: reservation, settlement, isolation,
  50k boundary, release, lease fallback, UTC reset.
- `server/tests/test_postgres_ai_ledger.py`: multi-process PostgreSQL
  concurrency and exact token reservation boundary.
- Server Chat/Report suites: idempotency, outcomes, V1/V3 compatibility,
  Chinese v3 fixtures, and logging privacy.
- Flutter Chat/route/report suites: fixed actions, independent selection,
  report references, account invalidation, responsive layout, keyboard, and
  Semantics.

## Gate Decision

Current result: **46 PASS / 0 FAIL / 8 NOT EXECUTED**.

The user completed every product-level row that can be safely and honestly
exercised in the Alpha environment. The remaining rows are C6 (50k boundary),
C9 (UTC reset), E4 (no retained v1 fixture), F3 (disabled Provider), F4
(pre-Provider rejection), F5 (Provider failure), F6 (timeout/outcome-unknown),
and F7 (controlled log review). They remain `NOT EXECUTED`, not manual PASS.

Automated substitutes are `server/tests/test_ai_token_budget.py`,
`server/tests/test_postgres_ai_ledger.py`, the Server Chat/Report suites, and
the Flutter Chat/route/report suites listed above. They prove the controlled
boundary, concurrency, fault, recovery, and privacy invariants without changing
the deployed Provider configuration or exposing sensitive logs. Residual risk:
a real production incident may still differ from the deterministic fixture.

Gate: **CLOSED WITH ACCEPTED AUTOMATED SUBSTITUTIONS**. This records the
user-confirmed Alpha deployment, Windows/Android product acceptance, and the
specified automated evidence. It does not make the unsupported live fault
injections manual PASS, nor does it certify a public-production release.
