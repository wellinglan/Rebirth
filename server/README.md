# Rebirth Cloud-Ready Development API

Sprint 6E provides one FastAPI contract for Windows SQLite development and Docker PostgreSQL development. It supports development login, device registration, and manual canonical Profile sync only. It is not a production-safe cloud deployment.

Sprint 8C also provides a stateless, JWT-protected AI Provider gateway for explicit weekly generation. Provider defaults to `disabled`; `fake` is development/test only; `openai` uses the official Python SDK Responses API. Flutter never receives or stores `OPENAI_API_KEY`.

AI endpoints:

- `GET /ai/capabilities`
- `POST /ai/reports/weekly/generate`

OpenAI requires `OPENAI_API_KEY` and `REBIRTH_AI_MODEL`. Optional limits are `REBIRTH_AI_TIMEOUT_SECONDS=90` and `REBIRTH_AI_MAX_OUTPUT_TOKENS=1600`. Calls use strict structured output, `store=false`, no streaming/tools/background mode, and no automatic SDK retry. `store=false` is not an absolute zero-retention promise. The Server verifies canonical SHA-256, strips sources/identities before Provider forwarding, and does not persist reports.

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

The PostgreSQL test runs Alembic and concurrent sync writes. It is skipped, not passed, when `REBIRTH_POSTGRES_TEST_URL` is absent.

## Sync Identity and Versioning

- Profile cloud identity is `<cloud-user-id>/user_profiles/profile`.
- Windows and Android keep independent local Flutter Profile UUIDs.
- Sprint 6D UUID-shaped cloud Profile rows are lazily copied to canonical `profile`; the newest undeleted legacy version wins and all legacy rows remain.
- `sync_clock` allocates versions with a database-level atomic `UPDATE ... RETURNING`; no Python global lock or `max()+1` allocator is used.
- The clock initializes at or above the greatest existing SyncItem version.
- Flutter record `server_version` and client pull cursor are separate.

## Configuration and Security Boundary

| Variable | Default | Purpose |
|---|---|---|
| `REBIRTH_ENV` | `development` | Runtime environment |
| `REBIRTH_DATABASE_URL` | local SQLite URL | SQLAlchemy SQLite/PostgreSQL URL |
| `REBIRTH_JWT_SECRET` | development-only placeholder | JWT signing secret |
| `REBIRTH_ACCESS_TOKEN_MINUTES` | `30` | Access-token lifetime |
| `REBIRTH_REFRESH_TOKEN_DAYS` | `30` | Refresh-token lifetime |
| `REBIRTH_AI_PROVIDER` | `disabled` | `disabled`, development `fake`, or `openai` |
| `OPENAI_API_KEY` | none | Server-only Provider secret |
| `REBIRTH_AI_MODEL` | none | Configured OpenAI model ID |
| `REBIRTH_AI_TIMEOUT_SECONDS` | `90` | Provider timeout |
| `REBIRTH_AI_MAX_OUTPUT_TOKENS` | `1600` | Provider output limit |

Normal pytest uses Fake/mocks and never calls real OpenAI. The opt-in smoke test requires `REBIRTH_RUN_OPENAI_SMOKE=1`, a key, and a model, and may incur cost. Manual flows are documented in `docs/manual_tests/18_ai_manual_weekly_generation.md`.

Outside `development`, `REBIRTH_JWT_SECRET` is mandatory. Production must use HTTPS, managed secrets, PostgreSQL backups, secure client token storage, token refresh/revoke, rate limiting, observability, and a security review. The current SharedPreferences session is development-level only. There is no real WeChat login, background sync, field-level conflict merge, or Today/Journal/Plan/Health sync.
