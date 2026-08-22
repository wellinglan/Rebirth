# Sprint 18B Conversation-first AI Coach Manual Acceptance

> Sprint: **18B**
> Candidate baseline: `a3325939c45a9b138b8f717448e394fb4ecd7930`
> Matrix status: **NOT EXECUTED**
> Result: **0 PASS / 0 FAIL / 54 NOT EXECUTED**
> Gate: **OPEN**

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
| A1 | Record full-SHA image and digest. | Both match final 18B publication. | NOT EXECUTED | Deployment pending. |
| A2 | Run normal Alembic upgrade. | Head is `20260822_0009`; no data loss. | NOT EXECUTED | Deployment pending. |
| A3 | Recreate only API and inspect services. | API healthy; PostgreSQL was not recreated. | NOT EXECUTED | Deployment pending. |
| A4 | Call `/health`. | HTTP 200, API 1, Sync Protocol 2. | NOT EXECUTED | Runtime pending. |
| A5 | Run `config-check`. | Four token controls appear; no secret or database URL. | NOT EXECUTED | Operator run pending. |
| A6 | Call authenticated Usage V1 and V2. | V1 still responds; V2 separates Chat/Report Token budgets. | NOT EXECUTED | API run pending. |

## B. Conversation-first Entry And Navigation

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| B1 | Open first-level AI Coach. | Conversation opens directly, not old overview. | NOT EXECUTED | Client run pending. |
| B2 | Open `/ai-coach/chat`. | Same conversation opens without loop. | NOT EXECUTED | Deep-link run pending. |
| B3 | Inspect AppBar. | History, new thread, report library, consent are compact and reachable. | NOT EXECUTED | Client run pending. |
| B4 | Inspect above composer. | Reference, Daily, and Weekly actions are visible. | NOT EXECUTED | Client run pending. |
| B5 | Wait without interaction. | No AI, report, sync, or usage change. | NOT EXECUTED | Runtime observation pending. |
| B6 | Open history and return. | Draft and conversation remain. | NOT EXECUTED | Client run pending. |
| B7 | Open report library/consent and return. | No message or generation is created. | NOT EXECUTED | Client run pending. |

## C. Token Budget And Account Isolation

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| C1 | Inspect fresh Chat budget. | UI uses Token, not remaining request count, and shows local reset time. | NOT EXECUTED | Client run pending. |
| C2 | Send one ordinary message. | Used Token increases once after success. | NOT EXECUTED | Provider run pending. |
| C3 | Send with explicit context. | Input context contributes to usage; only selected scopes are sent. | NOT EXECUTED | Provider run pending. |
| C4 | Rapidly activate Send. | One Provider call and one charge. | NOT EXECUTED | Automation supports result. |
| C5 | Reopen/recover a completed request. | Result reuses the same request without another charge. | NOT EXECUTED | May use ledger automation if no safe fixture. |
| C6 | Reach/inject 50k boundary safely. | Chat blocks; Report budget remains independent. | NOT EXECUTED | Exact automated boundary evidence allowed. |
| C7 | Generate a report after Chat use. | Report consumes only Report budget. | NOT EXECUTED | Client/API run pending. |
| C8 | Switch Account A to B. | B has an independent budget and local history. | NOT EXECUTED | Two-account run pending. |
| C9 | Cross UTC reset safely. | Both budgets reset at UTC boundary. | NOT EXECUTED | Usually automated-only. |

## D. Daily And Weekly Report Actions

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| D1 | Select Chat Health, then open Daily. | Daily starts empty; Chat selection is unchanged. | NOT EXECUTED | Client run pending. |
| D2 | Inspect Daily scopes. | Today/Health/Journal only; Growth absent. | NOT EXECUTED | Client run pending. |
| D3 | Inspect Daily date. | Current local natural date. | NOT EXECUTED | Client run pending. |
| D4 | Cancel Daily and open Weekly. | Weekly starts empty and adds Growth. | NOT EXECUTED | Client run pending. |
| D5 | Inspect Weekly period. | Most recent seven local natural dates. | NOT EXECUTED | Client run pending. |
| D6 | Select Journal and cancel warning. | It remains unselected; no call occurs. | NOT EXECUTED | Client run pending. |
| D7 | Confirm Journal warning. | Selection visible; no call before final confirmation. | NOT EXECUTED | Client run pending. |
| D8 | Continue from quick picker. | Canonical preview shows sources, Provider, privacy/cost warning, confirmation. | NOT EXECUTED | Client run pending. |
| D9 | Cancel final confirmation. | No pending report, call, or charge. | NOT EXECUTED | Client run pending. |
| D10 | Submit identical completed input. | Existing report is offered/reused without duplicate charge. | NOT EXECUTED | Client run pending. |

## E. Chinese Reports, Persistence, And Sync

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| E1 | Generate Daily with authorized real Provider. | All user-visible report content is Simplified Chinese. | NOT EXECUTED | Cost-authorized run required. |
| E2 | Generate Weekly with authorized real Provider. | All user-visible report content is Simplified Chinese. | NOT EXECUTED | Cost-authorized run required. |
| E3 | Inspect metadata where supported. | New reports use v3; Prompt text/fingerprint remain hidden. | NOT EXECUTED | Client run pending. |
| E4 | Open old v1 report. | Original text remains; no translation/regeneration. | NOT EXECUTED | Historical report required. |
| E5 | Return after generation. | Report reference appears; body is not copied into a message. | NOT EXECUTED | Client run pending. |
| E6 | Send another text-only turn. | Report body/reference is not attached automatically. | NOT EXECUTED | Client run pending. |
| E7 | Sync Reports across Windows/Android. | Report syncs; Chat thread does not. | NOT EXECUTED | Cross-device run pending. |

## F. Failure, Reservation, Privacy, And Regression

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| F1 | Revoke consent and try Chat/Report. | New calls block; history/reports remain readable. | NOT EXECUTED | Client run pending. |
| F2 | Restore consent. | Nothing auto-sends or auto-generates. | NOT EXECUTED | Client run pending. |
| F3 | Disable Provider in controlled window. | Fail closed without Provider call or charge. | NOT EXECUTED | Automated substitute accepted if no window. |
| F4 | Trigger pre-Provider rejection. | Reservation releases; no Token charged. | NOT EXECUTED | Automated-only if no safe fixture. |
| F5 | Trigger Provider failure without usage. | Conservative estimate charges once; error controlled. | NOT EXECUTED | Safe fixture or automation. |
| F6 | Trigger timeout/outcome unknown. | Reservation remains until status/lease; no auto-retry. | NOT EXECUTED | Safe fixture or lease automation. |
| F7 | Review logs. | No content, Prompt, Authorization, key, secret, or full user ID. | NOT EXECUTED | Controlled review pending. |
| F8 | Smoke Profile, Plan, Today, Journal, Health, Growth, export, report conflict, Sync All. | Existing behavior remains; Chat creates no business write. | NOT EXECUTED | Regression pending. |

## G. Responsive, Keyboard, And Accessibility

| ID | Procedure | Expected | Status | Evidence / note |
|---|---|---|---|---|
| G1 | Use 320px-equivalent Android. | Three actions wrap with no overflow. | NOT EXECUTED | Device/widget evidence pending. |
| G2 | Use 360px and 412px. | Conversation, picker, composer, references stay reachable. | NOT EXECUTED | Device run pending. |
| G3 | Use 720px. | No accidental wide split or hidden action. | NOT EXECUTED | Client run pending. |
| G4 | Use 1200px Windows. | Thread pane and conversation are readable. | NOT EXECUTED | Windows run pending. |
| G5 | Set TextScaler 2.0. | No clipping, overlap, or unreachable confirmation. | NOT EXECUTED | Device run pending. |
| G6 | Use Tab, Enter, Space, Enter-send, Shift+Enter. | Focus/actions work once; Shift+Enter adds newline. | NOT EXECUTED | Keyboard run pending. |
| G7 | Use TalkBack on budget/actions/messages/references. | Labels explain role, Token unit, and report-reference behavior. | NOT EXECUTED | Accessibility pending. |

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

Current result: **0 PASS / 0 FAIL / 54 NOT EXECUTED**.

Gate: **OPEN** pending final CI, migration deployment, authorized real-Provider
Chinese review, Windows/Android execution, and recorded manual results.
