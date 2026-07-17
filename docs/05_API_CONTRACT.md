# Rebirth API Contract Draft

> Status: Sprint 6E cloud-ready development contract and Profile sync client
> Authentication: `Authorization: Bearer <Rebirth access token>` where marked

## Base URL

- Development: `http://127.0.0.1:8000`
- LAN test: `http://<local-ip>:8000`
- Runtime selection: Settings saved endpoint > `REBIRTH_API_BASE_URL` > `http://127.0.0.1:8000`
- Production: must use HTTPS

Timestamps are UTC milliseconds since epoch. IDs are opaque UUID strings. Error payloads use FastAPI's standard `detail` field unless an endpoint defines a domain response.

## Health

### `GET /health`

Response `200`:

```json
{
  "status": "ok",
  "service": "rebirth-api",
  "api_version": 1,
  "sync_protocol_version": 2,
  "environment": "development"
}
```

The response contains no credentials, database URL, user data, or local file path. Flutter accepts API version 1 and sync protocol version 2.

## Authentication

### `POST /auth/dev-login`

Development only. Production-like environments return `404`.

Request:

```json
{
  "dev_user_key": "local-test-user"
}
```

Response `200`:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "token_type": "bearer",
  "user": {
    "id": "...",
    "display_name": "Dev local-test-user"
  }
}
```

Repeated requests with the same `dev_user_key` return the same Rebirth user but fresh session tokens.

### `POST /auth/wechat/mobile`

Draft only. It makes no external WeChat call in Sprint 6B.

Request:

```json
{
  "code": "short-lived-provider-code",
  "platform": "android"
}
```

Response `200`:

```json
{
  "status": "not_implemented",
  "message": "WeChat login requires configured Open Platform credentials."
}
```

`platform` accepts `android` or `ios`.

### `GET /auth/wechat/desktop/start`

Draft only. Returns the same `not_implemented` shape. No QR code or provider URL is created.

### `GET /auth/wechat/callback`

Draft only. Returns the same `not_implemented` shape. No provider code is exchanged.

## Devices

### `POST /devices/register`

Requires a Rebirth access token.

Request:

```json
{
  "local_installation_id": "installation-uuid",
  "platform": "windows",
  "device_name": "Research PC",
  "app_version": "1.0.0+1"
}
```

`platform` accepts `windows`, `android`, `ios`, `macos`, or `web`.

Response `200`:

```json
{
  "device_id": "device-uuid",
  "server_time": 1784073600000
}
```

Registration is idempotent for `user + local_installation_id`. Re-registering updates device metadata and `last_seen_at` without creating another device.

## Sync

For `user_profiles`, `id` is always the canonical value `profile`. Flutter local Profile UUIDs are device-local identities and never replace this cloud key. Other table IDs retain the general opaque record-ID contract, although Flutter Sprint 6E does not sync those tables.

Supported Sprint 6B table names:

- `user_profiles`
- `today_records`
- `journal_entries`
- `goals`
- `health_records`

### `POST /sync/push`

Requires a Rebirth access token and a registered, non-revoked device owned by that user.

Request:

```json
{
  "device_id": "device-uuid",
  "items": [
    {
      "table": "today_records",
      "id": "record-uuid",
      "payload": {
        "record_date": "2026-07-15"
      },
      "updated_at": 1784073600000,
      "deleted_at": null,
      "origin_device_id": "installation-uuid",
      "client_version": 0
    }
  ]
}
```

Response `200`:

```json
{
  "accepted": [
    {
      "table": "today_records",
      "id": "record-uuid",
      "server_version": 1
    }
  ],
  "conflicts": []
}
```

An item is returned as a conflict when the supplied `client_version` no longer matches the stored version and the incoming client update is older than the stored client update. Sprint 6B does not auto-merge conflicts.

### `POST /sync/pull`

Requires a Rebirth access token and a registered, non-revoked device owned by that user.

Request:

```json
{
  "device_id": "device-uuid",
  "since_server_version": 0,
  "tables": [
    "user_profiles",
    "today_records",
    "journal_entries",
    "goals",
    "health_records"
  ]
}
```

Response `200`:

```json
{
  "server_version": 10,
  "items": [
    {
      "table": "today_records",
      "id": "record-uuid",
      "payload": {
        "record_date": "2026-07-15"
      },
      "updated_at": 1784073600000,
      "deleted_at": null,
      "origin_device_id": "installation-uuid",
      "server_version": 10
    }
  ]
}
```

Only items with `server_version > since_server_version` and a requested table are returned. For `user_profiles`, only canonical `id=profile` is returned. If only Sprint 6D legacy UUID rows exist, Server lazily creates canonical Profile from the newest undeleted legacy version and retains the legacy rows. Deleted records for other generic scopes remain tombstones.

`server_version` on a record and the client's pull cursor are distinct. Flutter advances its endpoint/user/scope cursor to response `server_version` only after every returned Profile item is parsed and applied successfully; an empty successful response can also advance it. Conflict, parse failure, network failure, or local write failure does not advance cursor.

## Current Contract Limits

## AI Manual Weekly Generation And Recovery (Sprint 8D)

Sprint 8E completes the OpenAPI response contract. `POST /ai/reports/weekly/generate` declares `200` completed, `202` processing, and controlled `409`, `410`, `422`, `429`, `502`, `503`, and `504` responses. `GET /ai/requests/{request_id}` declares `200`, `401`, and non-disclosing `404`. Error bodies use `AiErrorResponse`; the OpenAPI document contains no Server database model or secret.

`GET /ai/capabilities` and `POST /ai/reports/weekly/generate` require the existing bearer JWT. The only report contract is input schema 1, `weekly_report`, `weekly-report-v1`, and output schema 1. Generation accepts the existing typed canonical payload plus its SHA-256; Server normalizes/recomputes the hash before Provider invocation and rejects extra fields. Responses return the echoed request identity/hash, actual provider/model, server-rendered Markdown, and validated structured output.

The Server persists a minimal request ledger, not user report history. It temporarily retains only validated output for replay and never persists input payloads, sources, canonical JSON, source IDs, Journal text, Provider request/raw response, credentials, stack traces, database URLs, or local paths. Flutter local `ai_reports` remains report history.

`GET /ai/capabilities` additionally returns `durable_request_ledger`, `request_status_recovery`, `result_retention_hours`, `dedupe_retention_days`, `processing_lease_minutes`, and `exactly_once_guaranteed=false`.

`POST /ai/reports/weekly/generate` atomically binds one JWT user/request ID. A retained completed request replays; active processing returns HTTP 202 with status metadata; conflicting identity returns `409 idempotency_conflict`; stale processing becomes `outcome_unknown`; failed and expired requests never call Provider again.

`GET /ai/requests/{request_id}` is JWT protected and returns the current user's `processing`, `completed`, `failed`, `outcome_unknown`, or `result_expired` status. Completed includes retained validated output; processing includes lease metadata; failed includes only a controlled code. Missing and other-user requests both return 404 `not_found`. There is no Server request-list endpoint.

- There is no production refresh endpoint, token revocation, account linking, device management UI, background sync, batch pagination, encryption-at-rest policy, or business-specific conflict resolution yet.
- Windows SQLite and Docker PostgreSQL expose the same API contract; Base URL is an environment difference, not a business-layer difference.
- SharedPreferences token storage is development-only; secure storage and complete refresh/revoke are not implemented.
- HTTP is development-only. Production requires HTTPS and a deployment security review.
- Flutter 调用 `/health`、`/auth/dev-login` 和 `/devices/register`。
- Flutter Sprint 6D 只为 `user_profiles` 手动调用 `/sync/push` 和 `/sync/pull`。
- Today、Journal、Plan、Health 继续只走本地 Repository，且不会在登录后自动上传。
