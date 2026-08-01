# Sprint 14A.3 AI Usage Audit And Operations Manual Matrix

Status: `NOT EXECUTED`

Baseline: `b70f8698bd2534d964b30a9bd2e48c107479e20b`

This matrix must run in an authorized Alpha Server environment. Never paste an
API key, JWT, database URL, prompt, Journal/Health content, or full user ID into
the evidence. Automated tests and CI do not become manual PASS.

## A. Configuration Inspection

| ID | Procedure | Expected | Result |
|---|---|---|---|
| A1 | Run `config-check` with the deployed environment. | Provider, model, timeout, max tokens, limits, enabled and readiness are present. | NOT EXECUTED |
| A2 | Review output for credentials and database information. | No key, Secret, Authorization value, endpoint credential, or database URL appears. | NOT EXECUTED |
| A3 | In an isolated candidate environment, omit the selected Provider credential. | Readiness is false or normal API startup fails closed; no secret value is printed. | NOT EXECUTED |
| A4 | Verify `/health`. | Healthy; API Version 1 and Sync Protocol 2. | NOT EXECUTED |

## B. Usage Audit

| ID | Procedure | Expected | Result |
|---|---|---|---|
| B1 | Run `audit` without `--days`. | Report covers 7 UTC calendar days. | NOT EXECUTED |
| B2 | Run `audit --days 30`. | Report covers 30 UTC calendar days. | NOT EXECUTED |
| B3 | Compare known Alpha generation outcomes with aggregate groups. | Date, Provider, model, request type and success/failure totals are credible. | NOT EXECUTED |
| B4 | Review timeout, expiry and aggregate token fields. | Counts are present and non-negative. | NOT EXECUTED |
| B5 | Search output for user or source content. | No full user ID, prompt, Journal/Health text, report text, key, Secret, or credential token. | NOT EXECUTED |

## C. Budget Alerts

| ID | Procedure | Expected | Result |
|---|---|---|---|
| C1 | In an isolated Alpha configuration, set a safe test threshold and reach its warning percentage. | `AI_USAGE_LIMIT_WARNING` appears with timestamp, Provider, metric, value, threshold. | NOT EXECUTED |
| C2 | Reach the configured test limit. | `AI_USAGE_LIMIT_EXCEEDED` appears. | NOT EXECUTED |
| C3 | Confirm daily user/global behavior. | Existing hard limit still rejects excess reservations. | NOT EXECUTED |
| C4 | Confirm monthly behavior. | Monthly value is an alert threshold only and does not add a hidden rejection rule. | NOT EXECUTED |

## D. Provider And Lease Monitoring

| ID | Procedure | Expected | Result |
|---|---|---|---|
| D1 | Run `monitor --window-minutes 60`. | Aggregate failure and timeout rates are shown per Provider. | NOT EXECUTED |
| D2 | Use an isolated failure scenario or existing safe incident fixture. | `AI_PROVIDER_FAILURE_RATE_HIGH` appears at threshold. | NOT EXECUTED |
| D3 | Use an isolated timeout scenario or existing safe incident fixture. | `AI_PROVIDER_TIMEOUT_RATE_HIGH` appears at threshold. | NOT EXECUTED |
| D4 | Use an isolated expired reservation fixture. | `AI_EXPIRED_GENERATION_DETECTED` appears. | NOT EXECUTED |
| D5 | Use an isolated stale lease fixture. | `AI_PROCESSING_LEASE_BACKLOG` counts each unique request once. | NOT EXECUTED |

## E. Ledger Consistency

| ID | Procedure | Expected | Result |
|---|---|---|---|
| E1 | Run `ledger-check --days 7` on a known-consistent environment. | Exit 0 and `status=ok`. | NOT EXECUTED |
| E2 | Run the checked automated inconsistency fixture; do not corrupt Alpha data manually. | Missing/orphan/token/status anomalies are reported and exit is 2. | NOT EXECUTED |
| E3 | Compare row counts before and after the command. | No generation, usage, sync, or business row changes. | NOT EXECUTED |
| E4 | Review output privacy. | No request ID, full user ID, content, or credential appears. | NOT EXECUTED |

## F. Kill Switch And Recovery

| ID | Procedure | Expected | Result |
|---|---|---|---|
| F1 | Follow Runbook Section 6 in Alpha. | Provider is disabled by Server configuration only. | NOT EXECUTED |
| F2 | Attempt an approved generation while disabled. | Explicit `ai_disabled`; no generation/usage row and no Provider call. | NOT EXECUTED |
| F3 | Verify ordinary app and `/health`. | App remains usable and API stays healthy. | NOT EXECUTED |
| F4 | Follow Runbook Section 7. | Provider readiness returns and no failed/unknown request is auto-retried. | NOT EXECUTED |

## G. PostgreSQL And Multi-worker

| ID | Procedure | Expected | Result |
|---|---|---|---|
| G1 | Run audit repeatedly against deployed PostgreSQL. | Stable snapshot totals when no new request arrives. | NOT EXECUTED |
| G2 | Run the PostgreSQL multiprocess operation-read test. | All readers return identical totals and consistency status. | NOT EXECUTED |
| G3 | Run Alembic current/head checks. | Existing revision remains current; Sprint 14A.3 adds no migration. | NOT EXECUTED |
| G4 | Verify Flutter database source. | `schemaVersion` remains 9. | NOT EXECUTED |

## H. Operator Runbook

| ID | Procedure | Expected | Result |
|---|---|---|---|
| H1 | Walk through Provider deployment and limit-change steps without exposing secrets. | Steps are executable and scoped to API operation. | NOT EXECUTED |
| H2 | Walk through Provider failure and budget exhaustion response. | Disable, diagnose, and restore decisions are clear. | NOT EXECUTED |
| H3 | Walk through rollback. | Previous environment/image can be restored without database downgrade. | NOT EXECUTED |
| H4 | Locate safe incident events in API logs. | Only allowlisted operational fields are present. | NOT EXECUTED |

## Final Result

- PASS: `0`
- FAIL: `0`
- NOT EXECUTED: `34`
- AI Usage Audit Gate: `OPEN`
- AI Operation Safety Gate: `OPEN`
