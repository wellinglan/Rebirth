# Rebirth Development API

This directory contains the development backend introduced in Sprint 6B and connected to Flutter account flows in Sprint 6C. It is a local FastAPI service for validating Rebirth account, device, and incremental sync contracts. It is not a production cloud deployment.

## Requirements

- Python 3.11 or newer
- A local virtual environment

## Setup on Windows

```powershell
cd server
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

## Run

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Open `http://127.0.0.1:8000/health`. The expected response is:

```json
{"status":"ok","service":"rebirth-api"}
```

## Test

```powershell
pytest
```

## Current Capabilities

- Development-only `POST /auth/dev-login`
- JWT access and refresh token issuance
- Authenticated, idempotent `POST /devices/register`
- Authenticated `POST /sync/push` and `POST /sync/pull` contract
- Tombstone transport through `deleted_at`
- WeChat endpoint placeholders that return `not_implemented`

The Flutter app calls `/health`, `/auth/dev-login`, and `/devices/register` for development account diagnostics. It does not call the sync endpoints. Today, Journal, Plan, and Health remain local-first and continue using their existing local repositories.

## Configuration

Environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `REBIRTH_ENV` | `development` | Runtime environment |
| `REBIRTH_DATABASE_URL` | `sqlite:///.../server/rebirth_dev.sqlite` | SQLAlchemy database URL |
| `REBIRTH_JWT_SECRET` | development-only placeholder | JWT signing secret |
| `REBIRTH_ACCESS_TOKEN_MINUTES` | `30` | Access token lifetime |
| `REBIRTH_REFRESH_TOKEN_DAYS` | `30` | Refresh token lifetime |

The built-in JWT secret is deliberately labelled development-only. A non-development environment refuses to start unless `REBIRTH_JWT_SECRET` is set. Production must use a strong secret from a managed secret store, HTTPS, PostgreSQL, token revocation and rotation, rate limiting, structured audit logging, and an explicit deployment security review.

No WeChat AppID or AppSecret belongs in this repository. Future WeChat credentials must be backend-only secrets. Refresh tokens are signed tokens and are not persisted in plaintext by this service.

The local SQLite file, `.env` files, virtual environment, and secret files are ignored by Git and must not be committed.

## Known Limits

- No real WeChat SDK or Open Platform call
- No production refresh endpoint or token revocation
- No background jobs or pagination
- Basic conflict reporting only; no domain-specific merge workflow
- SQLite and the current server-version allocator are development-only
