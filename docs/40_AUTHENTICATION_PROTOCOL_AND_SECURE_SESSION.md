# Authentication Protocol And Secure Session Foundation

## Status

- Sprint: 13A.1
- Baseline: `153985f203f5918fc3b03951ea8f019468031b0d`
- Flutter schemaVersion: 9
- Server API Version: 1
- Sync Protocol: 2
- Public login experience: deferred to Sprint 13A.2
- WeChat authentication: design route only, deferred to Sprint 13B

## Scope

Sprint 13A.1 replaces the development-only token lifecycle with a production-shaped
authentication protocol while preserving the existing `CloudUser` and
`AuthIdentity` ownership model. It does not add a public registration/login page,
password recovery, MFA, WeChat integration, automatic sync, or new sync entities.

`CloudUser` remains the owner of cloud data. Login methods are identities attached
to that user:

```text
CloudUser
  -> AuthIdentity(provider=dev)
  -> AuthIdentity(provider=password_username)
       -> AuthCredential(Argon2id password hash)
```

The same CloudUser may therefore retain its existing development identity and gain
a password identity without moving Profile, Plan, Today, Journal, or Health data.
Identity provider subjects are never accepted as cloud user IDs.

## Username And Password Contract

Usernames are normalized to lowercase ASCII and must be 4-64 characters, start
with a letter or digit, and then contain only letters, digits, `_`, `-`, or `.`. The unique
boundary is `(provider, provider_subject)`. Display names are separate and are not
login identifiers.

Passwords are 12-128 Unicode code points. Spaces are significant; the Server does
not trim or Unicode-normalize a password. NUL and control characters are rejected.
No arbitrary composition rule is imposed. The Server is the final validator.

Passwords are stored only as Argon2id hashes with random salts. Raw passwords,
password hashes, Dev User Keys, tokens, and Authorization headers must never be
written to logs, responses, test evidence, or repository files. Unknown-user login
still performs dummy Argon2 verification to reduce obvious account-enumeration
timing differences. Successful login may rehash an outdated credential.

## Development Identity Migration

New development identities store an HMAC-SHA256 provider subject derived from the
Development User Key. Raw keys are no longer written as provider subjects or
display names. Existing raw subjects are lazily migrated during a successful Dev
login while keeping the same AuthIdentity ID and CloudUser ID. Existing SyncItem,
Device, and business ownership therefore remain unchanged.

Developer Options may attach a `password_username` identity after the current Dev
session re-authenticates with its Dev User Key. Username collision, wrong key,
non-Dev session, or an already attached password identity fails closed. The public
Settings page still does not expose the Dev Key or this operation.

## Session Model

The Server adds:

- `auth_credentials`
- `auth_sessions`
- `auth_refresh_tokens`
- `auth_login_throttles`
- `legacy_refresh_migrations`

An access token is a short-lived JWT containing `sub`, `sid`, `aid`, `jti`,
`type=access`, `iat`, `exp`, `iss`, and `aud`. Protected endpoints validate the
signature, issuer, audience, token type, user, identity, and current database
session state. Revoked or expired sessions invalidate otherwise unexpired access
tokens.

Refresh tokens are opaque values. Only an HMAC digest is persisted. Each successful
refresh atomically consumes the presented token and returns a new access/refresh
pair. Reusing a consumed, replaced, or revoked refresh token revokes that session
family. Other sessions and other users remain independent.

Logout revokes the current session family. Client logout is locally authoritative:
secure credentials are removed even if the remote revoke request cannot complete,
while local business data is retained.

## Login Throttle

Password login failures are counted in database-backed HMAC buckets derived from
the normalized login identifier and client network prefix. Neither raw username nor
raw IP is persisted. Blocking, expiry, and successful reset use Server time and do
not depend on process memory, so the policy remains shared across workers.

## Legacy Token Window

Legacy access/refresh compatibility is disabled by default. When explicitly
enabled it requires a UTC deadline. A valid legacy refresh JWT may be exchanged
once for a new database-backed session and opaque token; its digest is recorded in
`legacy_refresh_migrations`. Repeated migration, expiry, wrong token type, disabled
migration, or passing the cutoff fails closed. Newly issued tokens never use the
legacy format.

Deployment must keep the compatibility window deliberately short:

1. add all new Server secrets;
2. run Alembic upgrade;
3. deploy the compatible Server;
4. release the secure-storage client;
5. retain the declared legacy window only while old clients upgrade;
6. disable compatibility after the deadline.

## Client Credential Storage

Flutter uses `flutter_secure_storage` on Android and Windows. The secure envelope
contains the refresh token and minimum endpoint/account/session metadata. The
access token is runtime-only and is never included in the persisted envelope,
SharedPreferences, or Drift.

On first launch after upgrade, a valid legacy SharedPreferences session is copied
to secure storage, read back for verification, and only then removed from the
legacy store. Corrupt data, endpoint mismatch, write/read failure, or verification
failure fails closed without deleting business records.

The envelope is bound to the normalized Server endpoint and cloud account. Endpoint
switching clears session credentials and requires a new login but retains each
local account data space.

## AuthSessionManager

`AuthSessionManager` is the only client owner of runtime access credentials and
refresh coordination. Its states are:

- `uninitialized`
- `signedOut`
- `authenticated`
- `refreshing`
- `authenticatedOffline`
- `refreshOutcomeUnknown`
- `sessionRejected`

Concurrent callers share one refresh Future. An authenticated API request may be
replayed once only when the Server explicitly returns `access_token_expired`.
Side-effecting requests can disable replay. A second 401 stops; there is no refresh
loop.

A definitive invalid/reused/revoked/expired session clears credentials. A transient
network error does not delete local data. If a refresh request may have reached the
Server but its result is unknown, the old refresh token is no longer trusted or
persisted; the client enters `refreshOutcomeUnknown` and requires re-authentication.

Existing Sync and remote AI gateways obtain access through this manager. Sync
Protocol 2, entity payloads, OCC, cursor, transaction, conflict recovery, and
manual-only execution are unchanged.

## API

Additive API Version 1 routes:

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/dev-login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/session`
- `POST /auth/identities/password/attach`

`/auth/dev-login` is available only in development/test runtime. Requests do not
accept a trusted `user_id`; authorization derives ownership from the authenticated
session.

## Secrets And Operations

Non-development Server startup requires separate values of at least 32 bytes:

- `REBIRTH_JWT_SECRET`
- `AUTH_REFRESH_TOKEN_HMAC_KEY`
- `AUTH_DEV_IDENTITY_HMAC_KEY`
- `AUTH_RATE_LIMIT_HMAC_KEY`

It also requires stable issuer/audience configuration. These secrets have separate
purposes and must not reuse database passwords or provider keys. Rotating an HMAC
key invalidates the corresponding tokens/identity lookup, so rotation needs an
explicit migration plan.

The implementation phase did not deploy to Beijing Alpha. The matching API image
was deployed later for user acceptance with the existing PostgreSQL volume. On
2026-07-30, the post-acceptance operation restored the legacy runtime setting
`REBIRTH_ACCESS_TOKEN_MINUTES` from 30 to 15 and recreated only the API
container. The image digest and PostgreSQL container remained unchanged. The
container's existing startup hook ran `alembic upgrade head` as a no-op at
revision `20260730_0003`.

## Privacy And Account Boundary

Authentication changes session ownership, not business ownership. Existing
account bindings continue to isolate local data by normalized endpoint and
CloudUser ID. Logout and session rejection never delete Profile, Plan, Today,
Journal, Health, Growth projections, conflicts, cursors, or AI consent/pending
records.

Logs and evidence may contain only non-secret result counts, stable error codes,
run IDs, commit SHAs, and image digests. They must not contain credentials or
private module content.

## Gates

- Authentication Protocol Gate: OPEN / CARRIED TO SPRINT 13A.2
- Password Credential Security Gate: OPEN / CARRIED TO SPRINT 13A.2
- Refresh Token Rotation Gate: CLOSED / ACCEPTED
- Secure Client Storage Gate: OPEN / CARRIED TO SPRINT 13A.2
- Development Account Upgrade Gate: CLOSED / ACCEPTED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Login Experience Gate: OPEN / DEFERRED TO SPRINT 13A.2
- Public Account Recovery Gate: OPEN / DEFERRED
- WeChat Login And Binding Gate: OPEN / DEFERRED TO SPRINT 13B

## Manual Acceptance

User acceptance on 2026-07-30 recorded 67 PASS, 0 FAIL, and 12 NOT EXECUTED.
The retained rows are A8, C6-C8, and F1-F8. They remain honest capability or
fixture limitations and are not converted from automated coverage. See
`docs/manual_tests/40_authentication_protocol_and_secure_session.md`.
