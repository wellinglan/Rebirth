# WeChat Identity Provider Foundation

> Status: Sprint 13B.2 implementation complete; manual acceptance suspended
> Scope: provider metadata, trusted identity binding boundary, and safe Flutter entry

## Purpose

Sprint 13B.2 makes WeChat the first modeled external identity provider without
claiming that real WeChat OAuth is available. It extends the identity
foundation while keeping authentication, account ownership, local data, and
synchronization separate:

```text
Identity Provider
  -> verified provider identity
  -> AuthIdentity
  -> CloudUser
  -> existing Account Boundary
  -> existing local Profile and sync ownership
```

Adding an identity is another way to reach the same `CloudUser`. It does not
create, transfer, merge, claim, or delete a local data space.

## Provider Registry

The server has one provider registry with:

- provider ID;
- display name;
- supported capabilities;
- enabled status.

Current providers are:

| Internal ID | Display name | Capabilities | Enabled |
|---|---|---|---|
| `password_username` | Username and password | login | yes |
| `dev` | Developer account | login | yes |
| `wechat` | WeChat | login, bind | no |

`wechat` declares the capabilities required by a future integration, but is
disabled because no AppID, SDK, OAuth callback, or provider exchange is
configured in this Sprint.

## Existing Identity Table

WeChat reuses `auth_identities`; no provider-specific or duplicate identity
table is introduced. The existing columns already cover the required durable
identity:

- `provider`;
- `provider_subject`;
- optional `provider_union_id`;
- owning `user_id`;
- creation, update, and usage timestamps.

The existing global `UNIQUE(provider, provider_subject)` rule ensures that one
verified WeChat identity cannot belong to two Rebirth accounts. Sprint 13B.2
adds no Alembic revision and no Flutter migration. Flutter `schemaVersion`
remains `9`.

## Provider Subject Rules

Only the server-side trusted provider verification result may create a WeChat
identity:

```text
unionid available -> unionid:<normalized unionid>
otherwise         -> openid:<normalized app id>:<normalized openid>
```

Union ID is preferred because it can identify the same person across eligible
applications under the same provider account. Open ID remains scoped by AppID.
Empty, oversized, or control-character values are rejected.

Nickname and avatar are not identity keys. The client cannot submit a trusted
`cloud_user_id`, provider subject, Open ID, or Union ID to select an account.

## Binding Security Model

The future complete binding sequence is:

```text
authenticated Rebirth session
  -> explicit binding request
  -> reauthentication
  -> provider authorization
  -> server verifies provider response
  -> server creates AuthIdentity
  -> client refreshes safe identity list
```

The trusted service method requires both the current Rebirth user and a
server-verified provider result. It rejects binding without reauthentication.
If the provider identity already exists, the operation returns a generic
conflict and does not disclose its owner, transfer the identity, or merge
accounts.

The public authenticated foundation endpoint is:

```http
POST /auth/identities/wechat/bind/start
Authorization: Bearer <access token>
Content-Type: application/json

{}
```

Because real provider authorization is not configured, it returns a structured
`provider_unavailable` result. A request body cannot select the cloud user or
inject provider identity data.

## Flutter Presentation

Settings > Account Security displays safe identity summaries:

- username/password, if bound;
- developer identity, if bound in an eligible build;
- WeChat as bound or unbound.

An online authenticated user may enter the WeChat binding foundation flow. The
UI first explains that reauthentication and server verification are required,
then receives the current unavailable result. Offline users cannot start the
flow. A bound WeChat identity has no duplicate binding action.

The page never displays provider subject, Open ID, Union ID, token, secret, or
cloud user ID. Widgets continue to depend on the Riverpod controller rather
than API, Repository implementation, Drift, or `AppDatabase`.

## Privacy and Credential Storage

- No WeChat access token, refresh token, AppSecret, OAuth code, or SDK secret is
  stored in `auth_identities`.
- No provider credential is returned by identity discovery or binding-start
  responses.
- Client-supplied identity metadata is ignored by the binding-start endpoint.
- Errors are generic and do not reveal whether another account owns an
  identity.
- Existing log policy continues to prohibit credentials and provider subjects.

## Unchanged Boundaries

- API Version remains `1`.
- Sync Protocol remains `2`.
- Account Boundary remains normalized endpoint + Rebirth cloud user ID.
- Local Profile ownership and active-profile selection are unchanged.
- Cursor, OCC, conflict, tombstone, and manual-sync behavior are unchanged.
- Password and developer login remain unchanged.
- No business synchronization entity is added.

## Deferred Work

A later Sprint must separately design and review:

- WeChat Open Platform configuration and secret management;
- Android/iOS SDK integration;
- desktop or web authorization entry;
- OAuth callback, state, nonce, and replay protection;
- reauthentication user experience;
- session issuance through WeChat;
- operational monitoring and provider outage behavior.

Unbinding, account merge, automatic login, phone login, email login, password
recovery, and identity transfer remain outside this Sprint.
