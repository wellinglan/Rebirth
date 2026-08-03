# Sprint 14A.4 AI Operations Acceptance And Incident Drill

Status: `PASS`

Baseline: `5932964873e7ae1f4495b431929d65429f05f29b`

Resumed: `2026-08-03`

Accepted commit: `764f52e12cada3e81703d3eacbe641e85d952223`

Progress: all 72 applicable rows passed. The AI Usage Audit Gate and AI
Operation Safety Gate are closed for the authorized Alpha environment.

Batch 2 evidence (`2026-08-03`): 38 focused Server incident/ledger tests, 57
focused Flutter recovery/responsive tests, and the full 267-test Server SQLite
regression passed. PostgreSQL multi-process and multi-worker behavior is also
required to pass in the Quality workflow for the recording commit.

Batch 3 evidence (`2026-08-03`): 44 focused Flutter timeout, unavailable, retry,
and pending-recovery tests plus 39 focused Server CLI, ledger, Provider failure,
and privacy tests passed. Acceptance found and repaired two UI gaps: terminal
failure now exposes a confirmed manual retry, and pending recovery opens the
refreshed local-report tab without starting another generation. The CLI fixture
executes `monitor` and `ledger-check` against an isolated SQLite incident ledger;
it does not alter Alpha data, firewall, DNS, Provider credentials, or limits.

Batch 4 evidence (`2026-08-03`): the user completed the kill-switch, disabled
UI, non-AI regression, restore, and post-restore generation drill with all
presented checks passing.

Final evidence (`2026-08-03`): the real Provider, quota, account-isolation,
privacy, schema, version, and recovery checks passed. A Growth-only weekly
request exposed a client preflight defect because derived Growth data correctly
has no source rows. Commit `764f52e` permits that supported derived scope while
retaining the empty non-Growth guard; focused tests, the 1,138-test Flutter
suite, Windows release build, and Windows real-Provider retest passed. A real
invalid DeepSeek credential then produced one `provider_auth_failed` request,
one failed generation/usage pair, no retry, and a controlled client message.
The protected valid credential was restored by recreating only API; PostgreSQL
and the API image stayed unchanged, and a new request completed. Developer
entry created separate CloudUsers for the failure and recovery requests, so
their displayed quotas remained isolated as designed. Final ledger state was
9 completed plus 1 failed with zero anomalies. The intentional failure raised
the expected rolling-window Provider failure warning without a backlog.
Quality run `30809996652` passed Flutter, Android Debug, Server SQLite,
PostgreSQL, Alembic, and multi-worker validation.

Target API image:
`ghcr.io/wellinglan/rebirth-api:5932964873e7ae1f4495b431929d65429f05f29b`

This matrix runs only in the authorized Alpha environment. It proves operating
safety; it does not add AI product capability. Never place an API key, JWT,
Authorization value, database URL, prompt, Journal/Health text, AI output, or
full user ID in evidence. Use counts, controlled error codes, image digests, and
redacted screenshots only.

`PASS` means the operator actually observed the expected result. Automated rows
may be marked PASS from the named test evidence. All other rows require direct
execution. Stop the drill and restore the previous API configuration if API
health, Provider readiness, or ledger consistency unexpectedly fails.

## A. Deployment And Baseline

| ID | Procedure | Expected | Result |
|---|---|---|---|
| A1 | Record current API image tag/digest and PostgreSQL container ID. | Safe rollback evidence exists; no secret is recorded. | PASS |
| A2 | Back up the restricted environment file without displaying it. | A protected rollback copy exists. | PASS |
| A3 | Pull the target image and verify its digest against the published GHCR result. | Exact target image is locally available. | PASS |
| A4 | Update only the API image reference and recreate only `api`. | PostgreSQL is not restarted and its container ID is unchanged. | PASS |
| A5 | Run `docker compose ... ps` and inspect API logs. | API is running/healthy with no startup traceback or secret. | PASS |
| A6 | Call `/health`. | HTTP 200, API Version 1, Sync Protocol 2. | PASS |
| A7 | Run Alembic current/head inspection only. | Existing database is current; no undocumented migration runs. | PASS |
| A8 | Run `ledger-check --days 7`. | Exit 0 and `status=ok` before the drill. | PASS |

## B. Real Provider And Usage

| ID | Procedure | Expected | Result |
|---|---|---|---|
| B1 | Run `config-check` in the API container. | Real Provider is enabled and ready; model, timeout, token ceiling, and limits are correct. | PASS |
| B2 | Review `config-check` output. | No key, Secret, credential, Authorization value, or database URL appears. | PASS |
| B3 | Record the authenticated user's safe `/ai/usage/me` counts. | Enabled, daily limit, used, remaining, UTC reset time are readable. | PASS |
| B4 | Generate one approved Daily Insight on Windows or Android. | Request completes through the real Provider. | PASS |
| B5 | Inspect the Daily result metadata. | Provider and model match `config-check`; no raw request is exposed. | PASS |
| B6 | Generate one approved Weekly Report. | Request completes through the real Provider. | PASS |
| B7 | Inspect the Weekly result metadata. | Provider and model match `config-check`. | PASS |
| B8 | Read `/ai/usage/me` again. | Used increases exactly twice and remaining decreases exactly twice. | PASS |
| B9 | Run `audit --days 1`. | Daily and Weekly each add one successful aggregate request with non-negative token totals. | PASS |
| B10 | Reopen both results, restart the client, and reopen again. | Local result recovery works without a new Provider call or extra usage. | PASS |

## C. Provider Authentication Failure

| ID | Procedure | Expected | Result |
|---|---|---|---|
| C1 | Confirm the automated DeepSeek incident test covers HTTP 401/403. | `provider_auth_failed`, one Provider call, failed ledgers, cleared leases, and idempotent replay pass. | PASS |
| C2 | In the approved Alpha window, replace only the Provider key with a known-invalid test value using a non-echoing editor, then recreate only API. | API remains healthy; PostgreSQL is unchanged. | PASS |
| C3 | Attempt one approved generation. | Stable `provider_auth_failed`; no Provider body or Secret is shown. | PASS |
| C4 | Inspect safe logs and usage audit. | One failed reservation is counted; no prompt, content, credential, or unbounded retry appears. | PASS |
| C5 | Restore the protected valid configuration and recreate only API. | Provider readiness and one low-cost generation recover. | PASS |
| C6 | Run `ledger-check --days 7`. | Exit 0 and no lease or status anomaly. | PASS |

## D. Timeout And Pending Recovery Semantics

| ID | Procedure | Expected | Result |
|---|---|---|---|
| D1 | Run the automated Provider timeout incident test. | `provider_timeout` is terminal failed, both leases clear, and identical request ID does not call Provider twice. | PASS |
| D2 | Run the automated client-network uncertainty test. | Local report remains pending with its binding and no automatic POST retry. | PASS |
| D3 | Run the automated stale generation lease test. | Stale processing changes once to `outcome_unknown`, including multi-worker coverage. | PASS |
| D4 | Confirm the UI message for Provider timeout. | A controlled failure is shown and explicit retry is available. | PASS |
| D5 | Confirm the UI message for client-network uncertainty. | Pending recovery is shown; status polling never starts a new generation. | PASS |
| D6 | Run `monitor` and `ledger-check` against the test evidence. | Timeout aggregates are visible and consistency remains diagnosable. | PASS |

## E. Provider Unavailable

| ID | Procedure | Expected | Result |
|---|---|---|---|
| E1 | Run the automated Provider unavailable incident test; do not change Alpha firewall or DNS. | `provider_unavailable`, failed ledgers, cleared leases, one Provider call. | PASS |
| E2 | Repeat the same request ID in the automated fixture. | Same controlled failure is replayed without another Provider call or charge. | PASS |
| E3 | Exercise the Flutter controlled unavailable state. | Existing form/preview remains intact and an explicit retry can succeed. | PASS |
| E4 | Review error and log output. | No stack trace, Provider body, prompt, content, Secret, or token appears. | PASS |
| E5 | Run `ledger-check --days 7`. | The simulated incident leaves no consistency anomaly. | PASS |

## F. Kill Switch And Recovery

| ID | Procedure | Expected | Result |
|---|---|---|---|
| F1 | Record current Provider/model and protected configuration backup. | Rollback values are available without displaying credentials. | PASS |
| F2 | Set only `REBIRTH_AI_PROVIDER=disabled` and recreate only API. | API is healthy; PostgreSQL is unchanged. | PASS |
| F3 | Run `config-check`. | `provider=disabled`, `enabled=false`, `provider_ready=true`. | PASS |
| F4 | Attempt Daily and Weekly generation. | Both return `ai_disabled`; no generation row, usage row, or external Provider call is created. | PASS |
| F5 | Use non-AI app features on both clients. | They remain usable and sync behavior is unchanged. | PASS |
| F6 | Restore the reviewed real Provider/model/config and recreate only API. | `/health` and `config-check` pass. | PASS |
| F7 | Generate one approved low-cost request. | Real Provider works again; exactly one new usage record appears. | PASS |
| F8 | Run `monitor` and `ledger-check`. | No failed/unknown request was automatically retried; consistency is `ok`. | PASS |

## G. Ledger And Cost Protection

| ID | Procedure | Expected | Result |
|---|---|---|---|
| G1 | Confirm automated successful DeepSeek replay coverage. | One request ID creates one generation, one usage record, and one Provider call with matching token totals. | PASS |
| G2 | Confirm automated duplicate request and PostgreSQL multi-process tests. | One claim owner and one charge across workers. | PASS |
| G3 | Run `audit --days 7`, then `ledger-check --days 7`. | Aggregate counts are credible and consistency is `ok`. | PASS |
| G4 | Run the checked inconsistency fixture only; never corrupt Alpha data. | Diagnostic reports anomalies, exits 2, and performs no repair. | PASS |
| G5 | Reach a safe per-user test limit in an approved account. | Excess request returns `usage_limit_reached` before Provider call and adds no reservation. | PASS |
| G6 | Verify another authorized test user below its limit. | Per-user isolation remains effective. | PASS |
| G7 | Use automated budget warning/critical fixtures or an isolated reviewed threshold. | Warning and critical events contain only aggregate metric/threshold data. | PASS |
| G8 | Verify non-AI and sync data before and after the limit drill. | No business row or sync state changes. | PASS |

## H. Privacy And Secret Rotation Walkthrough

| ID | Procedure | Expected | Result |
|---|---|---|---|
| H1 | Inspect API logs for every drill by safe event name. | No API key, JWT, Authorization/Refresh token, prompt, Journal/Health text, or report body. | PASS |
| H2 | Inspect controlled API error bodies. | Only stable codes/messages; no Provider body, Secret, stack trace, or user content. | PASS |
| H3 | Inspect `ai_usage_records` schema and representative rows without exporting them. | Only accounting metadata/IDs/timestamps/leases/tokens/status; no source or generated content. | PASS |
| H4 | Inspect generation ledger boundaries. | Request identity and temporary result metadata follow existing retention; no input contract or source content is stored. | PASS |
| H5 | Walk through Runbook Section 11 without exposing a real credential. | Two-phase replacement, verification, old-key revocation, and rollback are executable. | PASS |
| H6 | Confirm repository and evidence files contain no secrets. | No PAT, Provider key, JWT Secret, database password, or real user content is committed. | PASS |

## I. Flutter Acceptance

| ID | Procedure | Expected | Result |
|---|---|---|---|
| I1 | Windows: load AI page with real Provider available. | Usage status and generate controls load correctly. | PASS |
| I2 | Android: load AI page with real Provider available. | Same state is readable and usable. | PASS |
| I3 | Observe generation in progress and tap repeatedly. | Loading is visible and duplicate submission is suppressed. | PASS |
| I4 | Observe an approved controlled failure and retry. | Failure is readable; current input remains; explicit retry works. | PASS |
| I5 | Observe disabled state during F2-F4. | AI unavailable state is explicit and generate action is disabled. | PASS |
| I6 | Observe usage limit state during G5. | Remaining count is zero and generation is blocked. | PASS |
| I7 | Test 320 px width. | No overflow or hidden operation. | PASS |
| I8 | Test maximum supported text scaling, including 2.0. | Text, status, and actions remain readable without overflow. | PASS |
| I9 | Android Back during normal, loading, failure, and result states. | Navigation is safe and no duplicate request starts. | PASS |
| I10 | Windows keyboard navigation with Tab, Enter, and Space. | Focus and activation remain predictable. | PASS |

## J. Version And Scope Invariants

| ID | Procedure | Expected | Result |
|---|---|---|---|
| J1 | Verify `/health` after all drills. | API Version remains 1 and Sync Protocol remains 2. | PASS |
| J2 | Verify Flutter database source and migration history. | `schemaVersion` remains 9; no Sprint 14A.4 Drift migration. | PASS |
| J3 | Compare Alembic heads and migration files with baseline. | No Sprint 14A.4 database migration or business-table change. | PASS |
| J4 | Review Profile/Plan/Today/Journal/Health sync behavior. | No sync scope, payload, or algorithm changed. | PASS |
| J5 | Confirm no new AI surface exists. | No chat, agent, tool calling, background generation, reminder, or AI report sync. | PASS |

## Final Result

- PASS: `72`
- FAIL: `0`
- NOT EXECUTED: `0`
- AI Usage Audit Gate: `CLOSED`
- AI Operation Safety Gate: `CLOSED`

Both gates are `CLOSED` for this authorized Alpha acceptance scope. This does
not declare the AI product complete or authorize a production rollout.
