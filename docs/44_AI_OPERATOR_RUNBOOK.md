# AI Operator Runbook

## 1. Purpose And Boundary

This runbook operates the Server-side AI Provider, generation ledger, and usage
ledger introduced through Sprint 14A.3. It does not add an AI product feature,
public administration API, background generation, or client-controlled AI
configuration.

The operator commands are read-only. They never repair, delete, or rewrite AI
ledger rows. They print aggregate statistics only and must be executed inside a
trusted Server environment with database access.

API Version remains `1`, Sync Protocol remains `2`, and Flutter
`schemaVersion` remains `9`.

## 2. Configuration Reference

| Variable | Default | Meaning |
|---|---:|---|
| `REBIRTH_AI_PROVIDER` | `disabled` | `disabled`, `deepseek`, `openai`, or development/test-only `fake` |
| `REBIRTH_AI_MODEL` | none | Provider model ID |
| `REBIRTH_AI_TIMEOUT_SECONDS` | `90` | Provider timeout |
| `REBIRTH_AI_MAX_OUTPUT_TOKENS` | `1600` | Maximum output tokens per request |
| `REBIRTH_AI_DAILY_USER_LIMIT` | `10` | Per-user UTC-day hard reservation limit |
| `REBIRTH_AI_DAILY_GLOBAL_LIMIT` | `100` | Deployment UTC-day hard reservation limit |
| `REBIRTH_AI_MONTHLY_GLOBAL_LIMIT` | `3000` | UTC-month operational alert threshold, not a request hard limit |
| `REBIRTH_AI_BUDGET_WARNING_PERCENT` | `80` | Warning percentage for daily/monthly global thresholds |
| `REBIRTH_AI_FAILURE_RATE_WARNING_PERCENT` | `25` | Provider failure-rate warning threshold |
| `REBIRTH_AI_TIMEOUT_RATE_WARNING_PERCENT` | `10` | Provider timeout-rate warning threshold |
| `REBIRTH_AI_PROCESSING_BACKLOG_WARNING` | `1` | Stale unique request threshold |

Provider secrets remain Server-only environment values. Never place an API key,
JWT secret, database URL, or password in source control, shell history, tickets,
screenshots, or incident notes.

## 3. Command Reference

From the `server` directory with the production environment loaded:

```powershell
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai config-check
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai audit
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai audit --days 30
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai monitor --window-minutes 60
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai ledger-check --days 7
```

Inside the deployed API container:

```bash
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
  exec -T api python -m app.maintenance.rebirth_ai config-check
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
  exec -T api python -m app.maintenance.rebirth_ai audit --days 7
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
  exec -T api python -m app.maintenance.rebirth_ai monitor --window-minutes 60
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
  exec -T api python -m app.maintenance.rebirth_ai ledger-check --days 7
```

Exit code `0` means the command completed. `ledger-check` returns `2` when it
detects an inconsistency. Configuration or database operation failure returns
`1` with a generic, non-secret error code.

## 4. Deploy Or Change A Provider

1. Record the current API image tag and digest.
2. Back up the environment file using the Server's restricted backup process.
3. Set `REBIRTH_AI_PROVIDER`, `REBIRTH_AI_MODEL`, and the matching Server-only
   Provider credential.
4. Set timeout, token ceiling, hard daily limits, monthly alert threshold, and
   monitoring thresholds.
5. Run `config-check` in the candidate container environment. Confirm
   `provider_ready=true` and `enabled=true`; the output must not contain a key.
6. Recreate only the API service unless the deployment change separately
   includes a reviewed database migration.
7. Verify the API is running and healthy, then verify `/health` still reports
   API Version `1` and Sync Protocol `2`.
8. Run `audit`, `monitor`, and `ledger-check` once to establish a baseline.

`fake` is not allowed outside development/test. Missing real Provider
credentials fail closed during normal API startup.

## 5. Change Usage Limits

1. Record the current values and current audit totals.
2. Change only the intended environment values.
3. Remember that daily user/global limits are hard reservation limits.
4. Remember that `REBIRTH_AI_MONTHLY_GLOBAL_LIMIT` is an alert threshold only;
   it does not silently introduce a new monthly rejection rule.
5. Run `config-check` and confirm the safe values.
6. Recreate only the API service.
7. Verify `/health` and run `monitor`.

Lowering a hard daily limit never deletes prior usage. Existing reservations
continue to count until the next UTC day boundary.

## 6. Disable AI

1. Record the active Provider and image digest.
2. Set `REBIRTH_AI_PROVIDER=disabled`.
3. Do not remove the ledger, Provider credential, or database rows as part of
   the emergency switch.
4. Recreate only the API service.
5. Run `config-check`; confirm `provider=disabled`, `enabled=false`, and
   `provider_ready=true`.
6. Verify a generation attempt returns the existing explicit `ai_disabled`
   response, creates no generation row, creates no usage row, and makes no
   Provider call.
7. Verify `/health` remains healthy.

## 7. Restore AI

1. Confirm the Provider incident or budget decision is resolved.
2. Restore the previously reviewed Provider, model, and thresholds.
3. Run `config-check` before recreating the API.
4. Recreate only the API service and verify `/health`.
5. Run `monitor` and `ledger-check` before allowing normal Alpha use.
6. Perform one explicitly approved low-cost generation and confirm audit totals
   advance once.

Restoring AI does not retry failed, expired, or `outcome_unknown` requests.

## 8. Provider Failure Or Timeout

1. Run `monitor --window-minutes 60` and record only aggregate event names,
   values, and thresholds.
2. Check `AI_PROVIDER_FAILURE_RATE_HIGH`,
   `AI_PROVIDER_TIMEOUT_RATE_HIGH`, and Provider HTTP health outside Rebirth.
3. Do not paste request payloads, prompts, Journal text, Health text,
   Authorization values, or Provider responses into incident logs.
4. If impact continues, disable AI with the kill switch.
5. Preserve the generation and usage ledgers for diagnosis.
6. After recovery, restore AI through Section 7. Never automatically replay an
   `outcome_unknown` request because the Provider may already have charged it.

## 9. Budget Exhaustion

`AI_USAGE_LIMIT_WARNING` means a configured percentage threshold has been
reached. `AI_USAGE_LIMIT_EXCEEDED` means the daily hard limit or monthly alert
threshold has been reached.

1. Run `audit --days 7` and `monitor --window-minutes 1440`.
2. Compare aggregate request and token counts by Provider, model, and request
   type. No user content or full user ID is available from these commands.
3. Decide whether to keep AI disabled, wait for UTC reset, or apply a reviewed
   limit change.
4. For unexpected growth, disable AI first and investigate request counts and
   idempotency before raising a limit.

## 10. Ledger And Database Diagnostics

Run:

```bash
python -m app.maintenance.rebirth_ai ledger-check --days 7
```

The report compares generation and usage counts, terminal statuses, expired
states, duplicate/missing links, and token arithmetic. It is read-only and does
not expose request IDs or user IDs.

If `status=inconsistent`:

1. Stop optional AI generation by setting the kill switch if the anomaly is
   growing.
2. Record aggregate anomaly names and counts.
3. Confirm database availability, clock accuracy, and recent API restarts.
4. Preserve a protected database backup and relevant safe logs.
5. Do not run ad hoc UPDATE/DELETE statements and do not reset ledger versions.
6. Escalate for a reviewed repair Sprint. This command intentionally has no
   repair mode.

PostgreSQL and SQLite use the same ORM queries. Production operation should use
PostgreSQL backups and access controls. SQLite remains suitable for isolated
development diagnostics, not a substitute for the deployed database.

## 11. Rollback

1. Disable AI if continuing Provider calls are unsafe.
2. Restore the previous reviewed environment file without printing secrets.
3. Restore the previous API image tag/digest.
4. Recreate only the API service.
5. Do not downgrade or delete the database for Sprint 14A.3; it adds no
   migration.
6. Verify `/health`, `config-check`, `audit`, and `ledger-check`.
7. Keep AI disabled if any health or consistency check fails.

## 12. Incident Log Location And Privacy

Application AI safety events use the `rebirth.ai` JSON logger. Container logs can
be filtered by the exact event names without displaying environment secrets:

```bash
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs --since 60m api \
  | grep -E 'AI_USAGE_LIMIT_|AI_PROVIDER_|AI_EXPIRED_|AI_PROCESSING_'
```

Operational events contain timestamp, Provider, metric, value, threshold,
warning/critical severity, and environment only. Audit output contains aggregate
token counts because they are required for cost accounting, but never credential
tokens or source content.

## 13. Release Gates

The AI Usage Audit Gate closes only when audit, safe config inspection, budget
alerts, ledger diagnostics, CI, and manual acceptance pass. The AI Operation
Safety Gate additionally requires kill-switch, incident response, privacy, and
rollback acceptance. Until manual execution is recorded, both gates remain
open.
