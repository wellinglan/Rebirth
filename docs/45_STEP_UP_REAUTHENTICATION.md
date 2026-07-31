# Step-up Reauthentication and OAuth Callback Contract

> Status: Sprint 13B.4 implementation complete; normal Alpha manual acceptance
> recorded with controlled callback scenarios pending
> Scope: short-lived reauthentication proofs and the authenticated WeChat
> binding callback contract

## Purpose

Sprint 13B.4 adds a server-verified step-up boundary before a future WeChat
identity can be bound. It does not implement WeChat login, call WeChat, ship a
WeChat SDK, configure real provider credentials, or merge accounts.

The flow reuses the existing authentication and identity architecture:

```text
authenticated session
  -> password or test-only developer reauthentication
  -> one-time reauthentication proof
  -> OAuth Transaction Service
  -> provider-neutral Adapter
  -> existing Identity Service
  -> existing AuthIdentity
```

`CloudUser`, `AuthIdentity`, and `AuthSession` remain authoritative. No second
user or identity model is introduced.

## Reauthentication Proof

Alembic revision `20260731_0006` adds `reauthentication_proofs` with:

- `id`, `cloud_user_id`, and `session_id`;
- the only supported purpose, `wechat_bind`;
- a SHA-256 `proof_hash`;
- `created_at`, `expires_at`, and optional `consumed_at`;
- monotonic status: `created`, `consumed`, `expired`, or `rejected`.

The raw proof is returned once and kept only in client memory. The server does
not persist plaintext proof, password, access token, authorization code, or
provider token. The default lifetime is five minutes and is controlled by the
server-only `REBIRTH_REAUTHENTICATION_PROOF_MINUTES` setting.

A proof is valid only for the JWT-derived user, current server session, and
`wechat_bind` purpose. It is consumed once. Expiration, logout, session
revocation, wrong account, wrong session, wrong purpose, malformed values, and
replay all fail closed.

## Reauthentication Methods

`POST /auth/reauthenticate/password` reuses the existing Argon2 password
verification and login-throttle behavior. Incorrect credentials return a
generic failure and do not disclose whether an identity or credential exists.

`POST /auth/reauthenticate/developer` exists only in development and test
environments. It verifies the existing HMAC-backed developer identity. The
route returns `404` in production and is not a production OAuth mechanism.

Both endpoints derive `cloud_user_id`, identity, and session from the bearer
JWT. The client cannot submit any of them.

## Binding Start

`POST /auth/identities/wechat/bind/start` now requires:

```json
{
  "reauthentication_proof": "one-time-memory-only-value"
}
```

Proof consumption and OAuth transaction creation share one database
transaction. The OAuth transaction is bound to the same user, session,
provider, and `wechat_bind` purpose. Existing pre-13B.4 transactions have no
session binding and cannot be completed by the new service.

The normal application still has no real WeChat Adapter. It therefore remains
fail closed with `provider_unavailable`; no real authorization starts.

## Callback Contract

The authenticated contract is:

```http
POST /auth/identities/wechat/bind/callback
Authorization: Bearer <Rebirth access token>
```

It accepts transaction ID, state, nonce, and the provider authorization
response. User and session ownership come only from the JWT. The provider
Adapter performs exchange and verification; the existing `IdentityService`
alone performs identity binding.

Stable domain errors are:

- `invalid_transaction`;
- `expired_transaction`;
- `already_consumed`;
- `provider_error`;
- `binding_conflict`.

Database details, provider subjects, credentials, and stack traces are not
returned. PostgreSQL row locking permits only one successful concurrent
exchange. A global `UNIQUE(provider, provider_subject)` continues to prevent
one provider identity from being bound to multiple users.

This callback is an application contract for a future trusted provider flow;
it is not a deployed WeChat callback and does not make WeChat login available.

## Flutter Boundary

Account Security may ask the current user to re-enter a password before the
existing binding-readiness action. The credential and proof stay in memory and
are not persisted by Flutter. Developer reauthentication is available only for
an existing developer identity in eligible Alpha environments.

Flutter adds no WeChat login entry, SDK, QR flow, Drift table, or migration.
Flutter `schemaVersion` remains `9`.

## Unchanged Contracts

- API Version remains `1`.
- Sync Protocol remains `2`.
- Password/developer login, refresh, logout, and identity discovery remain.
- Sync algorithms, cursors, OCC, conflicts, tombstones, Account Boundary, and
  all business modules are unchanged.
- No account merge, identity transfer, or ownership migration is added.

## Release Gates

The Step-up Reauthentication Gate requires persistent hashed proofs, strict
user/session/purpose binding, expiration, one-time consumption, revocation
behavior, auth regression coverage, CI PASS, and manual acceptance.

The OAuth Callback Contract Gate requires stable non-disclosing errors,
provider isolation, one-winner concurrent exchange, identity uniqueness,
fail-closed production behavior, CI PASS, and manual acceptance.

Normal Alpha manual acceptance records `24 PASS / 0 FAIL / 12 NOT EXECUTED`.
The remaining cases require proof delay/cross-session injection or a controlled
Fake Provider environment that the normal Alpha deployment intentionally does
not expose. Both gates therefore remain `OPEN` pending those controlled cases.

## Deferred Work

- real WeChat provider HTTP exchange and response validation;
- real AppID/AppSecret provisioning and rotation;
- Android WeChat SDK and desktop QR authorization;
- production redirect/callback allowlists and operational monitoring;
- WeChat login and session issuance.

Nothing in Sprint 13B.4 should be interpreted as supported WeChat login.
