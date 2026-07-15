# Rebirth API Contract Draft

> Status: Sprint 6C development contract and Flutter account client
> Authentication: `Authorization: Bearer <Rebirth access token>` where marked

## Base URL

- Development: `http://127.0.0.1:8000`
- LAN test: `http://<local-ip>:8000`
- Production: TBD and must use HTTPS

Timestamps are UTC milliseconds since epoch. IDs are opaque UUID strings. Error payloads use FastAPI's standard `detail` field unless an endpoint defines a domain response.

## Health

### `GET /health`

Response `200`:

```json
{
  "status": "ok",
  "service": "rebirth-api"
}
```

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

Only items with `server_version > since_server_version` and a requested table are returned. Deleted records remain in the response with `deleted_at` as tombstones.

## Current Contract Limits

- There is no production refresh endpoint, token revocation, account linking, device management UI, background sync, batch pagination, encryption-at-rest policy, or business-specific conflict resolution yet.
- The development SQLite service is not a production deployment topology.
- Flutter Sprint 6C 调用 `/health`、`/auth/dev-login` 和 `/devices/register`。
- Flutter 尚未调用 `/sync/push` 或 `/sync/pull`；业务数据继续只走本地 Repository。
