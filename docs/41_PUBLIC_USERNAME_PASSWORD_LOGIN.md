# Sprint 13A.2 Public Username/Password Login

## Scope

Sprint 13A.1 established the authentication protocol, Argon2id credentials,
rotating refresh sessions, secure client storage, and account boundary. Sprint
13A.2 exposes that foundation as the normal product entry on Windows and
Android. It does not redesign the Server protocol.

The public flow is:

```text
App start
  -> auth bootstrap
  -> public login or registration
  -> secure session
  -> account boundary resolution
  -> account-scoped local data space
  -> protected app shell
```

Password recovery, email or SMS verification, MFA, passkeys, biometrics, WeChat,
automatic sync, background sync, and new sync entities remain out of scope.

## Build Environment

`AppConfig.fromEnvironment()` is the only normal build entry. It reads:

- `REBIRTH_ENV`: `production`, `alpha`, or `development`
- `REBIRTH_SERVER_ENDPOINT`: build-time Server origin
- `REBIRTH_ENABLE_DEV_LOGIN`: explicit development-login permission

Tests construct `AppConfig.test()` through dependency injection and do not read
platform environment or contact Alpha.

Production fails closed when the endpoint is absent. Production always sets
`enableDevLogin` to false even if the build accidentally requests true.
Production neither registers the developer login page nor Developer Options
route. Alpha shows its badge and developer entry only when the permission is
explicitly true. Development retains the local endpoint fallback for local
work.

See `release/rebirth_client_environment_build_guide.md` for commands. Examples
use `<endpoint>` deliberately; no private endpoint belongs in Git.

## Public Login And Registration

`PublicLoginPage` is `/auth/login`; `PublicRegisterPage` is `/auth/register`.
The public login page contains username and password only. It never displays an
endpoint, Development User Key, token, session ID, CloudUser ID, or internal
provider value.

Username rules match the Server: 4-64 characters, ASCII letter or digit first,
then letters, digits, dot, underscore, or hyphen. Submission lowercases the
identifier. Password values are never trimmed or normalized. Registration
requires 12-128 Unicode characters, rejects control characters, and compares
confirmation exactly. Display name is optional, trimmed, and limited to 128
characters.

Both forms disable submission while busy. The Widget and
`AppAuthController` independently prevent duplicate requests. A failed request
retains username and clears password fields. Passwords are held only by
ephemeral `TextEditingController` instances and are disposed with the page.

## Application Boundary

The call path is:

```text
Public auth Widget
  -> AppAuthController
  -> PasswordAuthService
  -> AuthSessionManager
  -> ApiClient
```

The UI does not import Drift, `AppDatabase`, an implementation repository,
remote data source, or `ApiClient`. Login and registration use the same success
path: accept the secure session, resolve Account Boundary, invalidate
account-scoped providers once, and enter either the bound local space or the
existing ownership review.

If secure storage cannot persist a newly issued session, the client attempts
remote logout, discards runtime credentials, does not create a local binding,
and presents a privacy-safe error. The CloudUser is not deleted.

## Bootstrap And Router Gate

Startup creates `AppConfig` before endpoint/session initialization. Protected
pages are never the initial visible branch while secure session restoration is
pending.

- no session -> public login
- refreshed session -> authenticated local space
- trusted bound session plus transient network failure -> offline local space
- expired, revoked, reused, or invalid session -> public login
- refresh outcome unknown -> clear untrusted credentials and public login
- unresolved legacy ownership -> binding review only

An absolute-expired local session cannot enter offline mode. Session rejection
and refresh outcome unknown deactivate the active local profile but preserve
all local business records. Their public messages contain no Server code.

Signed-out deep links to business routes resolve to `/auth/login`. Production
deep links to `/auth/developer` also resolve to public login without creating a
developer Widget. Register and Developer Login return to login with normal Back
navigation. Logout clears runtime access and secure refresh credentials,
deactivates account scope, and leaves data, cursor, conflict, and serverVersion
untouched.

## Developer Login

Developer login is no longer the primary form. In allowed Alpha/Development
builds, a low-priority link opens `/auth/developer`. Its Dev Key field is
obscured, cleared immediately on submission, never persisted, and never shown
on public pages. The existing repository guard remains, and the controller adds
an independent build-config guard.

Production has no runtime setting, gesture, or version-tap escape hatch to
re-enable this route.

## Error Mapping

Presentation maps controlled failures without exposing HTTP status or raw
details:

| Condition | Message |
|---|---|
| invalid credentials | 用户名或密码不正确。 |
| unavailable username | 该用户名不可用。 |
| password policy | 密码不符合安全要求。 |
| rate limited | 尝试次数过多，请稍后再试。 |
| network unavailable | 当前无法连接服务器，请检查网络后重试。 |
| Server unavailable | 服务暂时不可用，请稍后再试。 |
| secure storage unavailable | 无法安全保存登录状态，请检查系统设置后重试。 |
| rejected/expired session | 登录状态已失效，请重新登录。 |
| refresh outcome unknown | 登录状态无法确认，请重新登录。 |
| unexpected | 操作未完成，请稍后重试。 |

Unknown username and incorrect password share exactly one login message.
Registration may disclose only that a requested username is unavailable.

## Privacy And Persistence

- Password: Widget memory only
- Access Token: `AuthSessionManager` runtime only
- Refresh Token: secure-store envelope only
- SharedPreferences: no password or access token
- Drift: no password or token
- Router: no credential or account identifier parameters
- logs and evidence: no credentials, endpoint, or private module body

No Flutter table or migration changed. Flutter schemaVersion remains 9. API
Version remains 1 and Sync Protocol remains 2. Server runtime, PostgreSQL
schema, and Alembic revisions are unchanged. Synchronization remains manual and
limited to the existing five modules.

## UI And Accessibility

Login and registration use Material 3, scrollable constrained layouts, normal
autofill hints, explicit password-visibility semantics, keyboard submission,
and readable live error text. Automated coverage includes 320, 360, 412, and
1200 pixel widths at text scale 2.0. Windows keyboard, Android Back/software
keyboard, release installation, and real secure-store behavior remain manual
acceptance.

## Gates

- Public Login Experience Gate: CLOSED / ACCEPTED
- Authentication Protocol Gate: CLOSED / ACCEPTED
- Password Credential Security Gate: CLOSED / ACCEPTED
- Secure Client Storage Gate: CLOSED / ACCEPTED
- Refresh Token Rotation Gate: CLOSED / ACCEPTED
- Development Account Upgrade Gate: CLOSED / ACCEPTED
- Account Boundary Isolation Gate: CLOSED / ACCEPTED
- Public Account Recovery Gate: OPEN / DEFERRED
- WeChat Login And Binding Gate: OPEN / DEFERRED TO SPRINT 13B

The manual matrix is
`manual_tests/41_public_username_password_login.md`. User acceptance on
2026-07-30 recorded 107 PASS, 0 FAIL, and 7 NOT EXECUTED. H1-H7 remain honest
NOT EXECUTED results because no safe unbound-legacy-data fixture was available.
