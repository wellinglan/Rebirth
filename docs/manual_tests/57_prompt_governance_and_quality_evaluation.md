# Prompt Governance and Quality Evaluation Manual Acceptance

> Sprint: **15C**
> Source baseline: `38dc8373a4de739a892bc7f7ee9cc44de72a80fe`
> Gate: **CLOSED WITH ACCEPTED AUTOMATION AND COST LIMITATIONS**
> Result: **30 PASS / 0 FAIL / 8 NOT EXECUTED**
> Last updated: **2026-08-09**

Manual `PASS` is reserved for actions that were actually executed or rows whose
acceptance target is the inspected CI result itself. A high-cost manual runtime
repetition may remain honestly `NOT EXECUTED` when precise automated coverage is
named and the product owner explicitly accepts that evidence for the Gate. Use
repository synthetic fixtures only. Do not authorize a paid Provider run as
part of this matrix unless a separate explicit cost decision is recorded first.

## Preconditions

- Checkout the reviewed Sprint 15C working tree on Windows.
- Use the Server virtual environment with dependencies installed.
- Do not place an API key, token, private endpoint, real export, Journal body,
  Health body, account ID, or device ID in commands, screenshots, or notes.
- Record Generation/Usage Ledger counts before read-only CLI checks if a safe
  local database is available; offline commands do not require a database.
- Keep `REBIRTH_RUN_PROMPT_PROVIDER_EVAL` unset for A-F.

## A. Registry and Metadata

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| A1 | Run `prompt-list --strict`; four rows appear in stable Prompt/version order. | PASS | Operator-reported deployed Server CLI acceptance, 2026-08-07. |
| A2 | Daily v1 and Weekly v1 show `active`; Daily v2 and Weekly v2 show `candidate`. | PASS | Operator-reported A1-A7 PASS. |
| A3 | Exactly one active version exists for each report type. | PASS | Operator-reported A1-A7 PASS. |
| A4 | Daily metadata contains only Today/Health/Journal; Weekly additionally contains Growth. | PASS | Operator-reported A1-A7 PASS. |
| A5 | Run `prompt-show-metadata` for Daily v1; fingerprint and contracts appear but full instructions do not. | PASS | Operator-reported A1-A7 PASS. |
| A6 | Repeat A5; fingerprint remains identical. | PASS | Operator-reported A1-A7 PASS. |
| A7 | Request an unknown Prompt version; CLI exits non-zero with a controlled metadata-not-found error and no stack trace or secret. | PASS | Operator-reported A1-A7 PASS. |

## B. Static Governance Validation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| B1 | Run `prompt-validate --strict`; status is `ok`, Level is 1, read-only is true. | PASS | Initial image `829ba1ae` exposed a missing-fixture packaging blocker; fixed by `621f4352` and passed after redeployment. |
| B2 | Output reports four Prompt definitions, two active definitions, and nine synthetic cases. | PASS | Operator-reported B1-B6 PASS on fixed image. |
| B3 | Required Daily categories include null/zero, injection, Unicode, missing data, and all Scope combinations. | PASS | Operator-reported B1-B6 PASS on fixed image. |
| B4 | Required Weekly categories include full/sparse data, Growth-only, outlier/trend, injection, diagnosis, and fabricated statistics. | PASS | Operator-reported B1-B6 PASS on fixed image. |
| B5 | Validation reports `provider_called=false` and `database_required=false`. | PASS | Operator-reported B1-B6 PASS on fixed image. |
| B6 | No full Prompt, fixture body, credential, private path, account identity, or Endpoint appears in output. | PASS | Operator-reported B1-B6 PASS on fixed image. |

## C. Offline Evaluation and Comparison

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| C1 | Run `prompt-evaluate --offline --strict`; Level 2 returns 18 deterministic results and zero Critical failures. | PASS | Operator-reported C1-C7 PASS, 2026-08-09. |
| C2 | Contract, Grounding, Safety, and Coach Quality are separate Gate fields; Operational is `not_applicable`. | PASS | Operator-reported C1-C7 PASS. |
| C3 | Provider, model, tokens, latency, and cost are `not_applicable`, not fabricated zeros. | PASS | Operator-reported C1-C7 PASS. |
| C4 | Repeat C1 and compare JSON; ordering and values are identical. | PASS | Operator-reported deterministic comparison PASS. |
| C5 | Compare Daily v1 with v2; candidate remains `candidate` and no Critical regression is reported. | PASS | Operator-reported Daily comparison PASS. |
| C6 | Compare Weekly v1 with v2; candidate remains `candidate` and no Critical regression is reported. | PASS | Operator-reported Weekly comparison PASS. |
| C7 | Compare with a missing candidate under `--strict`; exit code is non-zero and no mutation occurs. | PASS | Operator-reported controlled failure PASS. |

## D. Read-only, Privacy, and Cost Boundary

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| D1 | Record safe local Generation Ledger count, run A-C, and confirm the count is unchanged. | PASS | Operator-reported before/after aggregate unchanged. |
| D2 | Record safe local Usage Ledger count, run A-C, and confirm the count is unchanged. | PASS | Operator-reported before/after aggregate unchanged. |
| D3 | Confirm no local AI Report is created and no Report lifecycle state changes. | PASS | Operator-reported no lifecycle mutation. |
| D4 | Confirm no outbound Provider/network request occurs while A-C run. | PASS | Operator-reported no Provider event; CLI also reported `provider_called=false`. |
| D5 | Search CLI output for Prompt body, API key, Authorization, real user data, private path, and Endpoint; none appears. | PASS | Operator-reported privacy scan PASS. |
| D6 | Confirm no CLI command exists to edit, delete, activate, deprecate, or retire a Prompt. | PASS | Operator-reported CLI surface scan PASS. |

## E. Runtime Regression

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| E1 | Start the Server with Disabled or Fake Provider and request authenticated `/ai/capabilities`; it still advertises only Daily v1 and Weekly v1. | NOT EXECUTED | Manual HTTP repetition omitted; `test_disabled_capabilities_are_safe` and `test_fake_capabilities_are_enabled` passed in Quality. |
| E2 | Submit the ordinary Fake Daily flow; it completes with `daily-insight-v1` metadata. | NOT EXECUTED | Manual HTTP repetition omitted; `test_daily_fake_success_minimizes_provider_payload_and_replays` passed. |
| E3 | Submit the ordinary Fake Weekly flow; it completes with `weekly-report-v1` metadata. | NOT EXECUTED | Manual HTTP repetition omitted; `test_fake_generation_success_and_minimized_payload` passed. |
| E4 | Attempt a candidate version through Generate; Server rejects it as unsupported and Fake Provider call count does not advance. | NOT EXECUTED | Manual HTTP repetition omitted; `test_unsupported_contract_blocks_provider` verifies rejection and zero Provider calls. |
| E5 | Recover/replay a completed v1 request; Prompt version and output remain stable without a second Provider call. | NOT EXECUTED | Manual HTTP repetition omitted; Daily replay test verifies identical output and one Provider call. |

## F. Platform and CI

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| F1 | Execute A-C in Windows PowerShell using the documented commands; JSON is UTF-8 and readable. | NOT EXECUTED | Separate user-operated Windows repetition omitted; local Windows engineering verification passed before publication. |
| F2 | Inspect GitHub Quality Server SQLite logs; Level 1, Level 2, Daily compare, and Weekly compare commands pass. | PASS | Quality run `31294393856`, Server SQLite job passed all four commands. |
| F3 | GitHub Server PostgreSQL/multi-worker regression passes without a new migration. | PASS | Quality run `31294393856`, PostgreSQL/Alembic/multi-worker job passed; no new revision. |
| F4 | Flutter analyze/test and Android Debug jobs pass with schemaVersion 11, API 1, and Sync Protocol 2 unchanged. | PASS | Quality run `31294393856`; Flutter and Android Debug passed with versions unchanged. |

## G. Real Provider Evaluation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| G1 | With no separate cost authorization, do not set the opt-in variable and do not run `prompt-provider-evaluate`. | NOT EXECUTED | Must remain NOT EXECUTED for this Sprint unless separately authorized. |
| G2 | Provider timeout/rate/error quality scenarios are not injected against a paid Provider without a safe reviewed sandbox. | NOT EXECUTED | Honest controlled-scenario limitation. |
| G3 | No Fake Provider result is presented as evidence of real model quality. | PASS | Documentation and completion wording explicitly distinguish deterministic Fake evidence from real model quality. |

## Gate Decision

The Prompt Governance and Quality Evaluation Gate is **CLOSED WITH ACCEPTED
AUTOMATION AND COST LIMITATIONS**. The product owner accepted the precise
automated runtime evidence for E1-E5 and the existing Windows engineering
evidence for F1 instead of requiring expensive duplicate manual execution. G1-G2
remain honestly `NOT EXECUTED`: no paid Provider quality run or unsafe fault
injection was authorized. These limitations are not relabeled as manual PASS and
Fake Provider output is not evidence of real model quality.
