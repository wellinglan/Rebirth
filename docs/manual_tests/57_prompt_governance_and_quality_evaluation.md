# Prompt Governance and Quality Evaluation Manual Acceptance

> Sprint: **15C**
> Source baseline: `38dc8373a4de739a892bc7f7ee9cc44de72a80fe`
> Gate: **OPEN**
> Result: **0 PASS / 0 FAIL / 38 NOT EXECUTED**
> Last updated: **2026-08-06**

All rows start as `NOT EXECUTED`. Automated tests and local CLI output are
supporting evidence only and must not be entered as manual PASS. Use repository
synthetic fixtures only. Do not authorize a paid Provider run as part of this
matrix unless a separate explicit cost decision is recorded first.

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
| A1 | Run `prompt-list --strict`; four rows appear in stable Prompt/version order. | NOT EXECUTED | |
| A2 | Daily v1 and Weekly v1 show `active`; Daily v2 and Weekly v2 show `candidate`. | NOT EXECUTED | |
| A3 | Exactly one active version exists for each report type. | NOT EXECUTED | |
| A4 | Daily metadata contains only Today/Health/Journal; Weekly additionally contains Growth. | NOT EXECUTED | |
| A5 | Run `prompt-show-metadata` for Daily v1; fingerprint and contracts appear but full instructions do not. | NOT EXECUTED | |
| A6 | Repeat A5; fingerprint remains identical. | NOT EXECUTED | |
| A7 | Request an unknown Prompt version; CLI exits non-zero with a controlled metadata-not-found error and no stack trace or secret. | NOT EXECUTED | |

## B. Static Governance Validation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| B1 | Run `prompt-validate --strict`; status is `ok`, Level is 1, read-only is true. | NOT EXECUTED | |
| B2 | Output reports four Prompt definitions, two active definitions, and nine synthetic cases. | NOT EXECUTED | |
| B3 | Required Daily categories include null/zero, injection, Unicode, missing data, and all Scope combinations. | NOT EXECUTED | |
| B4 | Required Weekly categories include full/sparse data, Growth-only, outlier/trend, injection, diagnosis, and fabricated statistics. | NOT EXECUTED | |
| B5 | Validation reports `provider_called=false` and `database_required=false`. | NOT EXECUTED | |
| B6 | No full Prompt, fixture body, credential, private path, account identity, or Endpoint appears in output. | NOT EXECUTED | |

## C. Offline Evaluation and Comparison

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| C1 | Run `prompt-evaluate --offline --strict`; Level 2 returns 18 deterministic results and zero Critical failures. | NOT EXECUTED | |
| C2 | Contract, Grounding, Safety, and Coach Quality are separate Gate fields; Operational is `not_applicable`. | NOT EXECUTED | |
| C3 | Provider, model, tokens, latency, and cost are `not_applicable`, not fabricated zeros. | NOT EXECUTED | |
| C4 | Repeat C1 and compare JSON; ordering and values are identical. | NOT EXECUTED | |
| C5 | Compare Daily v1 with v2; candidate remains `candidate` and no Critical regression is reported. | NOT EXECUTED | |
| C6 | Compare Weekly v1 with v2; candidate remains `candidate` and no Critical regression is reported. | NOT EXECUTED | |
| C7 | Compare with a missing candidate under `--strict`; exit code is non-zero and no mutation occurs. | NOT EXECUTED | |

## D. Read-only, Privacy, and Cost Boundary

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| D1 | Record safe local Generation Ledger count, run A-C, and confirm the count is unchanged. | NOT EXECUTED | |
| D2 | Record safe local Usage Ledger count, run A-C, and confirm the count is unchanged. | NOT EXECUTED | |
| D3 | Confirm no local AI Report is created and no Report lifecycle state changes. | NOT EXECUTED | |
| D4 | Confirm no outbound Provider/network request occurs while A-C run. | NOT EXECUTED | |
| D5 | Search CLI output for Prompt body, API key, Authorization, real user data, private path, and Endpoint; none appears. | NOT EXECUTED | |
| D6 | Confirm no CLI command exists to edit, delete, activate, deprecate, or retire a Prompt. | NOT EXECUTED | |

## E. Runtime Regression

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| E1 | Start the Server with Disabled or Fake Provider and request authenticated `/ai/capabilities`; it still advertises only Daily v1 and Weekly v1. | NOT EXECUTED | |
| E2 | Submit the ordinary Fake Daily flow; it completes with `daily-insight-v1` metadata. | NOT EXECUTED | |
| E3 | Submit the ordinary Fake Weekly flow; it completes with `weekly-report-v1` metadata. | NOT EXECUTED | |
| E4 | Attempt a candidate version through Generate; Server rejects it as unsupported and Fake Provider call count does not advance. | NOT EXECUTED | |
| E5 | Recover/replay a completed v1 request; Prompt version and output remain stable without a second Provider call. | NOT EXECUTED | |

## F. Platform and CI

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| F1 | Execute A-C in Windows PowerShell using the documented commands; JSON is UTF-8 and readable. | NOT EXECUTED | |
| F2 | Inspect GitHub Quality Server SQLite logs; Level 1, Level 2, Daily compare, and Weekly compare commands pass. | NOT EXECUTED | |
| F3 | GitHub Server PostgreSQL/multi-worker regression passes without a new migration. | NOT EXECUTED | |
| F4 | Flutter analyze/test and Android Debug jobs pass with schemaVersion 11, API 1, and Sync Protocol 2 unchanged. | NOT EXECUTED | |

## G. Real Provider Evaluation

| ID | Manual action and expected result | Status | Evidence / notes |
|---|---|---|---|
| G1 | With no separate cost authorization, do not set the opt-in variable and do not run `prompt-provider-evaluate`. | NOT EXECUTED | Must remain NOT EXECUTED for this Sprint unless separately authorized. |
| G2 | Provider timeout/rate/error quality scenarios are not injected against a paid Provider without a safe reviewed sandbox. | NOT EXECUTED | Honest controlled-scenario limitation. |
| G3 | No Fake Provider result is presented as evidence of real model quality. | NOT EXECUTED | Verify completion report wording. |

## Gate Decision

The Prompt Governance and Quality Evaluation Gate remains **OPEN** until the
applicable rows are manually executed and recorded. G1-G2 may remain honestly
`NOT EXECUTED` when there is no cost/fault-injection authorization, but the Gate
decision must explicitly accept that limitation rather than relabeling it PASS.
