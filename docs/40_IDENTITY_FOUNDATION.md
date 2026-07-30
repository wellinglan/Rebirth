# Multi Identity Authentication Foundation

> Status: Sprint 13B.1 implementation complete; manual acceptance pending
> Scope: identity model, safe identity discovery, and Settings presentation

## Purpose

Rebirth authentication separates the durable cloud account from the way a
person proves access to it:

```text
CloudUser
  |
  +-- AuthIdentity (password_username)
  |
  +-- AuthIdentity (dev, Alpha only)
  |
  +-- AuthIdentity (future providers)
```

One `CloudUser` may own multiple identities. Each `(provider,
provider_subject)` pair is globally unique and therefore belongs to exactly one
cloud user. Authentication continues to issue sessions for the cloud user ID;
identity changes do not create another local profile or data space.

## Existing Table Reuse

The server already had the canonical `auth_identities` table before Sprint
13B.1. It was used by password and development login, and durable auth sessions
already referenced `auth_identities.id`.

Creating a second `user_identities` table would have introduced two competing
sources of truth. Sprint 13B.1 therefore keeps `auth_identities` and adds only:

| Column | Type | Meaning |
|---|---|---|
| `last_used_at` | nullable bigint | UTC milliseconds of the most recent session issued through this identity |

The existing fields and unique constraint remain authoritative:

- `user_id` references `cloud_users.id`.
- `provider` identifies the authentication provider.
- `provider_subject` is the normalized provider-specific subject.
- `UNIQUE(provider, provider_subject)` prevents an external identity from
  belonging to multiple cloud users.

`provider_union_id` is an existing compatibility field. No new WeChat,
Apple, Google, OAuth credential, or provider-specific column was added.

## Provider Names

Internal values remain unchanged for compatibility:

- `password_username`
- `dev`

The identity discovery API maps them to presentation-safe names:

- `password`
- `developer`

JWT claims, session identity references, password registration, password login,
development login, and password attachment keep their existing behavior.

## Identity Discovery API

Authenticated clients may call:

```http
GET /auth/identities
Authorization: Bearer <access token>
```

Response:

```json
{
  "identities": [
    {
      "provider": "password",
      "created_at": 1785456000000,
      "last_used_at": 1785456000000
    }
  ]
}
```

The endpoint derives the account exclusively from the access token. It never
returns identity IDs, cloud user IDs, provider subjects, password hashes,
credentials, access tokens, refresh tokens, provider secrets, or OAuth codes.

## Server Boundaries

- `IdentityRepository` owns identity lookup and listing queries.
- `IdentityService` maps internal provider values to safe summaries and records
  identity usage.
- `AuthSessionService` still owns registration, login, refresh, and session
  issuance. It uses the identity repository for identity lookup.
- Issuing a new authenticated session updates `last_used_at` and `updated_at`.
- Errors do not disclose whether an identity belongs to another user.

## Flutter Boundaries

Flutter adds an `IdentityRepository`, safe `AuthIdentity` model, API data
source, Riverpod controller, and Settings account-security page.

Online authenticated accounts load `/auth/identities` through
`AuthSessionManager.runAuthorized`. Offline authenticated accounts make no
network request and show only the provider already present in the current
session, with a visible offline limitation. Signed-out users are denied by the
existing Auth Gate.

The page displays bound username/password or Alpha developer identities.
WeChat is visible only as a disabled future entry. Widgets do not import Drift,
`AppDatabase`, the API data source, or repository implementations.

## Account Boundary

Account Boundary remains:

```text
normalized endpoint + cloud_user_id
  -> one cloud_account_binding
  -> one local user_profiles data space
```

An identity is only a login route to a `CloudUser`. Adding or using another
identity for the same cloud user must resolve the same local binding. Identity
state does not create, merge, claim, move, or delete local profiles.

## Migration

Server Alembic revision `20260731_0004`:

1. Adds nullable `auth_identities.last_used_at`.
2. Backfills existing identities from `updated_at`.
3. Supports downgrade to `20260730_0003`.
4. Preserves cloud users, identities, credentials, sessions, and business data.

Flutter schema remains `9`; no local identity cache or Drift migration was
added.

## Unchanged Contracts

- API Version remains `1`.
- Sync Protocol remains `2`.
- Sync cursor, OCC, conflicts, tombstones, and manual-sync semantics are
  unchanged.
- Profile, Plan, Today, Journal, Health, Growth, and AI payloads are unchanged.
- No real WeChat, Apple, Google, or other OAuth flow is implemented.
- No automatic account merge, password recovery, or automatic sync is added.
