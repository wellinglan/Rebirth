# WeChat OAuth Transaction Security Foundation

> Status: Sprint 13B.3 complete; manual acceptance passed
> Scope: durable OAuth transactions, replay protection, and provider adapters

## Purpose

Sprint 13B.3 establishes the server-side security transaction needed by a
future WeChat OAuth integration. It does not implement WeChat login, call a
WeChat server, include a WeChat SDK, or configure real provider credentials.

The architecture remains:

```text
authenticated Auth Router
  -> OAuth Transaction Service
  -> OAuth Provider Adapter
  -> verified provider identity
  -> existing Identity Service
  -> existing AuthIdentity
```

`CloudUser` and `AuthIdentity` remain provider-neutral. There is no
`wechat_user`, `wechat_account`, or second identity model.

## Persistent Transaction

Alembic revision `20260731_0005` adds `oauth_transactions`:

| Field | Meaning |
|---|---|
| `transaction_id` | Random server-generated transaction identifier |
| `provider` | Provider ID, currently modeled with `wechat` |
| `purpose` | Security purpose, currently `bind` |
| `cloud_user_id` | Account derived from the authenticated Rebirth session |
| `state_hash` | SHA-256 of the one-time state value |
| `nonce_hash` | SHA-256 of the one-time nonce value |
| `status` | Monotonic transaction state |
| `created_at` | Server UTC milliseconds |
| `expires_at` | Server UTC expiration time |
| `consumed_at` | Successful consumption time |

The database never stores plaintext state, plaintext nonce, authorization
code, provider access token, provider refresh token, AppSecret, or provider
response payload. State and nonce are generated with a cryptographically
secure random source and returned only in the start response.

## Lifecycle

Allowed transitions are:

```text
created -> provider_verified -> completed -> consumed
created -> expired
created -> rejected
provider_verified -> rejected
```

States never move backwards. `expired`, `consumed`, and `rejected` are terminal.
The successful exchange performs provider verification, identity creation, and
the final transitions in one database transaction. The final durable success
state is `consumed`; the safe service result is `completed`.

The transaction row is locked during exchange. PostgreSQL therefore permits
only one winner when two workers exchange the same transaction concurrently.
A replay receives a generic unavailable result and cannot create another
identity.

## State and Nonce Validation

The exchange service hashes the presented state and nonce and compares each
digest using constant-time comparison. An incorrect value does not reveal
which field failed and does not expose the owning account.

Expired transactions are marked `expired` before rejection. Provider
verification failure is marked `rejected`. A transaction owned by account A
cannot be exchanged for account B, even if B knows its transaction ID.

## Provider Adapter

`OAuthProviderAdapter` is a provider-neutral interface. The OAuth transaction
service depends only on this interface and a registry. Provider-specific
verification returns a normalized `VerifiedProviderIdentity` to the existing
Identity Service.

`FakeWechatProvider` is deterministic test infrastructure. It is injectable
through `create_app` but is never registered by the default production app.
There is no `RealWechatProvider` in this Sprint.

The adapter receives an authorization code only in memory. The transaction
service does not persist or log it. A later real adapter must exchange the code
with WeChat and discard provider credentials after producing the verified
identity.

## Configuration

Reserved server-only environment variables are:

- `REBIRTH_WECHAT_APP_ID`
- `REBIRTH_WECHAT_APP_SECRET`
- `REBIRTH_WECHAT_OAUTH_TRANSACTION_MINUTES` (default `10`)

App ID and AppSecret must be configured together. Partial configuration stops
startup. Both values are excluded from `Settings` representation. They are not
sent to Flutter, written to the database, included in `/health`, or logged.

Configuration alone is insufficient. A provider is ready only when credentials
and an Adapter are both present. Because this Sprint provides no real Adapter,
normal deployments remain safely unavailable.

## API Boundary

The authenticated endpoint remains:

```http
POST /auth/identities/wechat/bind/start
Authorization: Bearer <Rebirth access token>

{}
```

The account always comes from the JWT-backed `AuthContext`; request bodies
cannot select `cloud_user_id`. When the provider is unavailable, the existing
safe `provider_unavailable` response remains unchanged. In an injected test
environment, the response contains transaction ID, one-time state and nonce,
purpose, and expiration.

The exchange/callback flow exists only as an internal service boundary in this
Sprint. No public completion endpoint is exposed because a production
reauthentication proof and real provider callback do not yet exist. The
internal exchange refuses to bind unless reauthentication has been verified.

## Identity Binding

The existing Identity Service accepts a generic server-verified provider
identity. Its existing global `UNIQUE(provider, provider_subject)` constraint
remains authoritative.

Consequences:

- one provider identity cannot bind to two `CloudUser` rows;
- duplicate binding returns a generic conflict;
- identity ownership is never transferred;
- accounts are never merged;
- local Account Boundary and Profile ownership do not change.

## Unchanged Contracts

- API Version remains `1`.
- Sync Protocol remains `2`.
- Flutter `schemaVersion` remains `9`; no Drift migration is added.
- Password, developer login, refresh, logout, and identity discovery remain.
- Profile, Plan, Today, Journal, Health, Growth, AI, cursor, OCC, conflict,
  tombstone, and manual sync behavior are unchanged.

## Deferred Work

A later Sprint must independently implement and review:

- a real WeChat Provider Adapter;
- provider HTTP exchange and response validation;
- production reauthentication proof issuance;
- Android WeChat SDK integration;
- desktop QR authorization;
- public callback/exchange endpoints with redirect allowlists;
- operational key rotation, monitoring, and incident response;
- WeChat login and session issuance.

Nothing in Sprint 13B.3 should be interpreted as supported WeChat login.

## Sprint 13B.4 Continuation

Sprint 13B.4 implements the previously deferred production reauthentication
proof boundary and authenticated callback contract. OAuth purpose is now
`wechat_bind`, and new transactions are bound to the current AuthSession.
Provider HTTP exchange, SDK integration, real credentials, and real WeChat
login remain deferred. See `docs/45_STEP_UP_REAUTHENTICATION.md`.
