# Rebirth Cloud Deployment Foundation

> Status: Sprint 6E development foundation, not a production deployment guide

## One Contract, Multiple Environments

Windows SQLite, LAN FastAPI, Docker PostgreSQL, and a future HTTPS cloud server use the same API contract from `docs/05_API_CONTRACT.md`. The Base URL and database engine are environment differences; Flutter Account and Sync business logic do not fork by environment.

Flutter endpoint priority is:

1. Settings saved runtime endpoint.
2. `--dart-define=REBIRTH_API_BASE_URL=...` build fallback.
3. `AppConfig.defaultApiBaseUrl`, currently `http://127.0.0.1:8000`.

Settings normalizes and validates an HTTP/HTTPS origin, tests `/health`, checks API v1 and sync protocol v2, then saves. A changed endpoint rebuilds ApiClient immediately and clears the old endpoint-bound session/device registration without touching SQLite business data.

## Local SQLite

SQLite remains the fastest Windows development mode:

```powershell
cd E:\Projects\Rebirth\server
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Before schema work, stop Server and copy `rebirth_dev.sqlite` to a backup. Existing Sprint 6D data is preserved; Sprint 6E adds `sync_clock` and lazily canonicalizes Profile rows without deleting legacy rows.

## Docker PostgreSQL

```powershell
cd E:\Projects\Rebirth\server
Copy-Item .env.example .env
docker compose -f docker-compose.dev.yml up --build
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml down
```

`api` waits for PostgreSQL health, runs `alembic upgrade head`, then starts Uvicorn. PostgreSQL data lives in `rebirth_postgres_data`; normal `down` keeps it. `down --volumes` is deliberately destructive and must never be part of normal startup/cleanup.

## Alembic

New database:

```powershell
$env:REBIRTH_DATABASE_URL = 'postgresql+psycopg://...'
.\.venv\Scripts\python.exe -m alembic upgrade head
```

Existing SQLAlchemy-created Sprint 6D SQLite database:

1. Stop Server and back up the file.
2. Start Sprint 6E once so `create_all` non-destructively adds missing `sync_clock`.
3. Run `alembic stamp 20260716_0001`.
4. Keep the backup until account, device, and canonical Profile checks pass.

Development rollback restores the backup file or a PostgreSQL backup. Do not run Alembic downgrade against data that must be retained because the initial downgrade drops cloud tables.

## Production Gaps

Sprint 8C adds a stateless AI gateway. Provider defaults to disabled; OpenAI credentials and model selection are Server environment secrets, and Fake is development/test only. OpenAI calls use Responses API structured output with `store=false`, no streaming/tools/background mode, explicit timeout/output limit, and no SDK retries. `store=false` is not an absolute zero-retention guarantee. Before production, complete privacy/legal/provider-retention/cost/rate-limit/observability reviews and design durable idempotency without storing unnecessary user content.

- HTTP cleartext is limited to localhost, LAN, and alpha builds; production must use HTTPS.
- JWT secret and database credentials must come from a managed secret system.
- Flutter tokens still use development-level SharedPreferences, not secure storage.
- Refresh/revoke, key rotation, rate limiting, audit logging, monitoring, backup drills, and disaster recovery are incomplete.
- Real WeChat login is not implemented.
- Only canonical Profile manual sync is connected; Today, Journal, Plan, and Health remain local-only.
- No field-level Profile conflict resolution or background synchronization exists.

These gaps mean Sprint 6E is cloud-compatible scaffolding, not production security readiness.
