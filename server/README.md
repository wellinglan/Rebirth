# Rebirth Server

> Classification: **Active Server development and operations guide**
> Current repository-wide state: `../docs/CURRENT_BASELINE.md`
> Release blockers: `../docs/RELEASE_READINESS.md`

Rebirth Server is the FastAPI API Version 1 implementation for authentication,
device registration, Sync Protocol 2, and explicit AI generation. It supports
local SQLite development and PostgreSQL 17 operation. Public username/password
authentication and optional non-production developer login use the same
session foundation. Manual sync currently serves Profile, Plan, Today,
Journal, Health, and AI Report. It is not by itself a Production-safe cloud
deployment.

Sprint 8D added a durable, JWT-user-isolated AI request ledger to the explicit Weekly generation gateway. Sprint 9A adds a typed Daily Insight foundation on the same ledger. Sprint 14A.1 adds a DeepSeek JSON adapter and database-backed cost safety. Provider defaults to `disabled`; `fake` is development/test only. Flutter never receives or stores Provider API keys.

AI endpoints:

- `GET /ai/capabilities`
- `GET /ai/usage/me`
- `POST /ai/reports/daily/generate`
- `POST /ai/reports/weekly/generate`
- `GET /ai/requests/{request_id}`

Capabilities expose typed `report_contracts`: Daily uses `daily_insight`, `daily-insight-v1`, one local date, and Today/Health/Journal scopes; Weekly uses `weekly_report`, `weekly-report-v1`, seven local dates, and may also include Growth. Daily rejects Growth and Goals. Selected missing records are `[]`, unselected scopes are absent, and `null` remains distinct from `0`.

OpenAI requires `OPENAI_API_KEY` and `REBIRTH_AI_MODEL`. Calls use strict structured output, `store=false`, no streaming/tools/background mode, and no automatic SDK retry. `store=false` is not an absolute zero-retention promise. The Server verifies canonical SHA-256 and strips sources/identities before Provider forwarding.

DeepSeek requires `DEEPSEEK_API_KEY` and `REBIRTH_AI_MODEL`. Calls use
non-streaming JSON Output, the same validated report schemas, and no automatic
retry. User/global UTC-day quotas and active concurrency are reserved before
the external call.

The `ai_generation_requests` ledger provides at-most-once Provider ownership for one JWT user and request ID. It stores minimal request identity and temporarily stores only validated output for recovery. It never stores the input payload, canonical JSON, sources, Journal text, Provider request body, raw Provider response, token, or API key. Defaults are 24 hours for recoverable output, 30 days for the dedupe tombstone, and 5 minutes for a processing lease. Cleanup is lazy on AI request entry. This is not exactly-once: a crash after Provider return but before the completed update becomes `outcome_unknown` after lease expiry and is never automatically retried.

Sprint 8E validates configuration relationships at startup, declares the complete Generate/Status OpenAPI responses, emits allowlisted body-free JSON events, adds a reusable cleanup CLI, and provides PostgreSQL multiprocessing plus Uvicorn multi-worker verification. Operational details are in `../docs/12_AI_OPERATIONS_AND_OBSERVABILITY.md`.

## Health Contract

`GET /health` returns:

```json
{
  "status": "ok",
  "service": "rebirth-api",
  "api_version": 1,
  "sync_protocol_version": 2,
  "environment": "development"
}
```

No secret, token, database credential, user data, or local path is exposed.

## Windows + SQLite

```powershell
cd E:\Projects\Rebirth\server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The default database is `server/rebirth_dev.sqlite`. Back it up before migration or manual experiments:

```powershell
Copy-Item .\rebirth_dev.sqlite .\rebirth_dev.backup.sqlite
```

For a new database, set `REBIRTH_DATABASE_URL` and run:

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
```

Before applying Sprint 8D to an existing database, stop the API and make a backup, then run `alembic upgrade head`. Revision `20260717_0002` adds the ledger without dropping existing account or sync data. Application startup never drops or recreates tables.

For a Sprint 6D SQLite database already created by SQLAlchemy, first back it up. Running the Sprint 6E server once adds the non-destructive `sync_clock` table through `create_all`; then mark the equivalent migration state:

```powershell
.\.venv\Scripts\python.exe -m alembic stamp 20260716_0001
```

Restore a development database by stopping the server and replacing it with the backup. Never automate deletion of the database file.

## Docker + PostgreSQL

Copy `.env.example` to a local `.env` and replace development passwords/secrets. `.env` is ignored by Git.

```powershell
cd E:\Projects\Rebirth\server
docker compose -f docker-compose.dev.yml up --build
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml down
```

The API waits for PostgreSQL readiness, runs `alembic upgrade head`, listens on `0.0.0.0:8000`, and exposes `/health` for container health checks. Normal `down` retains the named PostgreSQL volume.

To deliberately delete all container database data:

```powershell
# WARNING: destructive; this permanently deletes the development PostgreSQL volume.
docker compose -f docker-compose.dev.yml down --volumes
```

No startup script removes a SQLite file or Docker volume.

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest
```

Ordinary tests use temporary SQLite. PostgreSQL integration is opt-in:

```powershell
$env:REBIRTH_POSTGRES_TEST_URL = 'postgresql+psycopg://rebirth:password@127.0.0.1:5432/rebirth_test'
.\.venv\Scripts\python.exe -m pytest -m postgres
```

The PostgreSQL test runs Alembic, concurrent sync writes, and an atomic Plan parent/child batch. It is skipped, not passed, when `REBIRTH_POSTGRES_TEST_URL` is absent.

For an isolated PostgreSQL 17 AI reliability run:

```powershell
docker compose -f docker-compose.test.yml up -d
$env:REBIRTH_POSTGRES_TEST_URL = 'postgresql+psycopg://rebirth_test@127.0.0.1:55432/rebirth_test'
$env:REBIRTH_DATABASE_URL = $env:REBIRTH_POSTGRES_TEST_URL
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m pytest -m postgres
.\.venv\Scripts\python.exe scripts/verify_ai_multiworker.py --workers 2
docker compose -f docker-compose.test.yml down -v
```

Cleanup uses the same rules as request-entry lazy cleanup:

```powershell
.\.venv\Scripts\python.exe -m app.maintenance.ai_ledger_cleanup --dry-run
.\.venv\Scripts\python.exe -m app.maintenance.ai_ledger_cleanup
```

Read-only AI production operations use the existing ledgers:

```powershell
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai config-check
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai audit --days 7
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai monitor --window-minutes 60
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai ledger-check --days 7
```

The commands expose no HTTP route and do not repair data. The complete deployment,
kill-switch, incident, privacy, and rollback procedure is in
`../docs/44_AI_OPERATOR_RUNBOOK.md`.

GitHub Actions runs Server SQLite, PostgreSQL multiprocessing/multi-worker, Flutter analyze/test, and Android debug build jobs. A checked-in workflow is not evidence of a CI PASS until GitHub executes it.

## Sync Identity and Versioning

- Profile cloud identity is `<cloud-user-id>/user_profiles/profile`.
- Windows and Android keep independent local Flutter Profile UUIDs.
- Sprint 6D UUID-shaped cloud Profile rows are lazily copied to canonical `profile`; the newest undeleted legacy version wins and all legacy rows remain.
- `sync_clock` allocates versions with a database-level atomic `UPDATE ... RETURNING`; no Python global lock or `max()+1` allocator is used.
- The clock initializes at or above the greatest existing SyncItem version.
- Flutter record `server_version` and client pull cursor are separate.

The typed Flutter Coordinator and Adapter boundary now registers six product
modules: Profile, Plan, Today, Journal, Health, and AI Report. Protocol v2
allowlists `user_profiles`, `goals`, `today_records`,
`journal_prompt_configurations`, `journal_entries`, `health_records`, and
`ai_reports`. Journal runs prompt configuration before entries. All sync is
user-triggered; there is no startup, scheduled, background, or automatic sync.

The Profile client continues to call `POST /sync/push` and
`POST /sync/pull`. Deletion remains represented by `deleted_at`; Protocol v2
has no separate `operation` field. The Server derives the owner only from the
bearer JWT and requires a registered Device owned by that user.

Flutter Profile and Plan cursors remain stored outside SQLite under the existing
endpoint/user/scope-bound SharedPreferences key. It advances only after local
apply.

Sprint 10B enforces strict optimistic concurrency: cloud-new records require
client version zero, existing updates require the current server version, and
client timestamps never resolve stale writes. Exact retries return the current
version without a new clock allocation. Push batches are preflighted before
writes or version allocation, including Goal UUID, payload, hierarchy, cycle,
and subtree tombstone validation. Any real conflict produces no partial write
and does not advance `sync_clock`.

Plan keeps Goal UUIDs as stable cloud IDs and continues storing cloud rows in
`sync_items`; there is no dedicated Server Goal table. No Server model, API
field, Alembic revision, or PostgreSQL schema changed in Sprint 10B.

## Configuration and Security Boundary

| Variable | Default | Purpose |
|---|---|---|
| `REBIRTH_ENV` | `development` | Runtime environment |
| `REBIRTH_DATABASE_URL` | local SQLite URL | SQLAlchemy SQLite/PostgreSQL URL |
| `REBIRTH_JWT_SECRET` | generated in development | JWT signing secret |
| `AUTH_REFRESH_TOKEN_HMAC_KEY` | generated in development | Opaque refresh-token digest key |
| `AUTH_DEV_IDENTITY_HMAC_KEY` | generated in development | Dev identity subject key |
| `AUTH_RATE_LIMIT_HMAC_KEY` | generated in development | Login throttle bucket key |
| `AUTH_JWT_ISSUER` | `rebirth-api` | Access-token issuer |
| `AUTH_JWT_AUDIENCE` | `rebirth-client` | Access-token audience |
| `AUTH_ACCESS_TOKEN_MINUTES` | `15` | Access-token lifetime |
| `AUTH_REFRESH_TOKEN_DAYS` | `30` | Refresh-token lifetime |
| `AUTH_SESSION_ABSOLUTE_DAYS` | `90` | Absolute session lifetime |
| `AUTH_LEGACY_TOKEN_MIGRATION_ENABLED` | `false` | Controlled legacy JWT exchange |
| `AUTH_LEGACY_TOKEN_MIGRATION_DEADLINE` | none | Required UTC cutoff when enabled |
| `REBIRTH_AI_PROVIDER` | `disabled` | `disabled`, development `fake`, `deepseek`, or `openai` |
| `OPENAI_API_KEY` | none | Server-only Provider secret |
| `DEEPSEEK_API_KEY` | none | Server-only DeepSeek secret |
| `REBIRTH_AI_MODEL` | none | Configured Provider model ID |
| `REBIRTH_AI_TIMEOUT_SECONDS` | `90` | Provider timeout |
| `REBIRTH_AI_MAX_OUTPUT_TOKENS` | `1600` | Provider output limit |
| `REBIRTH_AI_RESULT_RETENTION_HOURS` | `24` | Recoverable validated result TTL |
| `REBIRTH_AI_DEDUPE_RETENTION_DAYS` | `30` | Minimal request tombstone TTL |
| `REBIRTH_AI_PROCESSING_LEASE_MINUTES` | `5` | Processing ownership lease |
| `REBIRTH_AI_DAILY_USER_LIMIT` | `10` | Per-user UTC-day Provider reservations |
| `REBIRTH_AI_DAILY_GLOBAL_LIMIT` | `100` | Deployment UTC-day Provider reservations |
| `REBIRTH_AI_MONTHLY_GLOBAL_LIMIT` | `3000` | UTC-month operational alert threshold |
| `REBIRTH_AI_MAX_CONCURRENT_REQUESTS` | `5` | Active Provider reservations |
| `REBIRTH_AI_BUDGET_WARNING_PERCENT` | `80` | Daily/monthly budget warning percentage |
| `REBIRTH_AI_FAILURE_RATE_WARNING_PERCENT` | `25` | Provider failure-rate warning percentage |
| `REBIRTH_AI_TIMEOUT_RATE_WARNING_PERCENT` | `10` | Provider timeout-rate warning percentage |
| `REBIRTH_AI_PROCESSING_BACKLOG_WARNING` | `1` | Unique stale processing request threshold |

Normal pytest uses Fake/mocks and never calls real OpenAI. The opt-in smoke test requires `REBIRTH_RUN_OPENAI_SMOKE=1`, a key, and a model, and may incur cost. Weekly manual flow is documented in `docs/manual_tests/18_ai_manual_weekly_generation.md`; the developer-only Daily contract is documented in `docs/manual_tests/21_daily_insight_contract.md`.

Outside `development`, all four authentication secrets are mandatory and must
be at least 32 bytes. Production must use HTTPS, managed secret rotation,
PostgreSQL backups, observability, and a security review. Flutter stores refresh
credentials through Android/Windows secure storage and keeps access tokens in
memory. Public username/password registration and login are implemented. There
is still no password recovery, MFA, real WeChat SDK/login/QR flow, or background
sync. WeChat identity and OAuth transaction code is a fail-closed security
foundation, not a usable WeChat login product.
