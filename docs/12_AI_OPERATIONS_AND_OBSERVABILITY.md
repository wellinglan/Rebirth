# AI Operations And Observability

## Configuration Guardrails

The Server validates AI operational settings during startup. Every value must be positive, `REBIRTH_AI_TIMEOUT_SECONDS` must be finite, and `REBIRTH_AI_MAX_OUTPUT_TOKENS` must be a positive integer.

The processing lease must include at least 30 seconds beyond the Provider timeout:

```text
processing_lease_seconds >= ai_timeout_seconds + 30
```

The dedupe tombstone must last at least as long as result retention and strictly longer than the processing lease:

```text
dedupe_retention_seconds >= result_retention_seconds
dedupe_retention_seconds > processing_lease_seconds
```

These relationships prevent a still-running Provider request from losing its ownership lease and prevent a replayable result from outliving the request tombstone. Invalid configuration stops application startup with configuration names only; values and secrets are not echoed.

## Safe AI Events

The `rebirth.ai` logger emits JSON events:

- `ai_request_claimed`
- `ai_request_replayed`
- `ai_request_processing`
- `ai_request_conflict`
- `ai_request_outcome_unknown`
- `ai_provider_started`
- `ai_provider_completed`
- `ai_provider_failed`
- `ai_result_purged`
- `ai_tombstone_deleted`
- `ai_status_recovered`

Allowed fields are `event`, `request_id`, namespaced one-way `pseudonymous_user_id`, `provider`, `model`, `status`, controlled `error_code`, `latency_ms`, the first eight characters of `input_hash`, aggregate cleanup counts, and `environment`.

Logs must never include the full hash, payload, Canonical JSON, Sources, Journal/Today/Health text, report Markdown, Structured Output, token, API key, Authorization header, database URL, or raw Provider request/response. Replay and real Provider calls use different event names. Provider completion and failure include elapsed milliseconds.

## Cleanup

Lazy cleanup remains active on AI request/status entry. The same `AiRequestLedger.cleanup` implementation is available as a maintenance command:

```powershell
cd server
.\.venv\Scripts\python.exe -m app.maintenance.ai_ledger_cleanup --dry-run
.\.venv\Scripts\python.exe -m app.maintenance.ai_ledger_cleanup
```

The command prints only current UTC milliseconds, candidate/actual aggregate counts, and elapsed milliseconds. Dry-run rolls back without modification. Repeating an executed cleanup returns zero until more rows expire.

Production may schedule this command through Cron or a Kubernetes Job after database backup, access-control, overlap, alerting, and retention review. No scheduler is deployed by Rebirth in this Sprint.

## PostgreSQL Verification

Docker-based local verification uses an isolated test-only PostgreSQL 17 instance with trust authentication and tmpfs data:

```powershell
cd server
docker compose -f docker-compose.test.yml up -d
$env:REBIRTH_POSTGRES_TEST_URL = 'postgresql+psycopg://rebirth_test@127.0.0.1:55432/rebirth_test'
$env:REBIRTH_DATABASE_URL = $env:REBIRTH_POSTGRES_TEST_URL
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m pytest -m postgres
.\.venv\Scripts\python.exe scripts/verify_ai_multiworker.py --workers 2
docker compose -f docker-compose.test.yml down -v
```

The multiprocessing suite uses four spawned processes with independent SQLAlchemy Engine/Session instances and includes a Daily marker that verifies one claim owner and one ledger row. The multi-worker script remains a Weekly regression: it starts two Uvicorn workers, sends eight concurrent duplicate requests through real HTTP, checks one Ledger row, and counts one `ai_provider_started` event. Both use Fake Provider only and add no diagnostic HTTP endpoint.

## CI Quality Gate

`.github/workflows/quality.yml` defines four required jobs: Server SQLite, Server PostgreSQL multiprocessing/multi-worker, Flutter analyze/test, and Android debug build. Flutter is pinned to stable `3.44.4`. Normal CI never configures or invokes real OpenAI.

Sprint 9A keeps the same event allowlist for Daily and Weekly. `report_type`, input/output bodies, Sources, and report content are not added to logs; existing request identity, controlled status, Provider metadata, truncated hash, and latency fields remain sufficient for operations.

## Remaining Reliability Boundary

The durable Ledger remains an at-most-once ownership mechanism for a retained request ID, not exactly-once. Provider return and the completed database commit are not atomic. A crash in that interval can become `outcome_unknown`; logs and maintenance do not remove this crash gap.
