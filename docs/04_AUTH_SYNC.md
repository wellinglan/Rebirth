# Rebirth Auth & Sync Architecture

> Status: Sprint 10B.2-A authenticated account-bound local data foundation
> Scope: Auth Gate plus manual Profile/Plan sync; not production authentication or full business sync

## 目标

- 支持同一用户未来在 Windows、Android、Web、iOS 和 macOS 上使用同一 Rebirth 账号。
- 保持本地优先：记录先可靠写入本地 SQLite，网络失败不得阻塞本地保存。
- 支持离线使用，并为后续增量云同步、冲突处理和恢复留出清晰边界。
- 支持第三方身份提供方，包括微信登录，但不把第三方平台 secret 放进客户端。
- 明确当前阶段只提供开发后端和领域接口，不声称真实微信登录或生产同步已经可用。

## 核心概念

### Rebirth User

Rebirth 自己的云端用户。其 ID 由 Rebirth 后端生成，不等于微信 `openid`、`unionid` 或其他第三方标识。

### Auth Identity

用户与身份提供方之间的绑定。`provider + provider_subject` 唯一，用于找到对应 Rebirth User。一个用户未来可以绑定多个身份提供方。

### Device

某个 Rebirth User 已注册的客户端设备。设备通过 `local_installation_id` 幂等注册；设备记录可撤销，不是登录凭据。

### Session

后端签发的 Rebirth access token / refresh token 会话。同步 API 只接受有效的 Rebirth access token。refresh token 不以明文持久化。

### Local Installation

Flutter 本地 `installation_info.installation_id` 表示一次安装生命周期。它不属于云账号或本地 UserProfile，也不用于跨安装追踪；注册设备后才与云端 Device 建立关联。`app_settings.local_installation_id` 在 schema 5 中仅作为兼容镜像保留，并由迁移统一为 installation singleton 的值。

### Sync Item

云端以单条业务记录为同步单位，包含表名、客户端记录 ID、业务 payload、更新时间、删除时间、来源设备与服务端版本。Sprint 6B 只建立通用存储和传输合同，不接入现有 Flutter Repository。

### Record Server Version

服务端接受变更时通过数据库 `sync_clock` 原子分配的全局单调递增版本。Profile 本地 `user_profiles.server_version` 保存 canonical 记录当前版本，用于上传并发控制；它不再兼任 pull cursor。

### Pull Cursor

客户端成功处理服务端变更流后保存的位置。当前 cursor 使用 SharedPreferences，并按 normalized endpoint、cloud user ID、scope 三个维度隔离。pull 解析、本地写入或 conflict 失败时不推进；cursor 丢失时从 0 重拉是安全退化。

### Canonical Profile Identity

Profile 是账号级单例，云端固定为 `cloud user + user_profiles + profile`。Windows 与 Android 的本地 `user_profiles.id` 仍分别保留各自 UUID，不写入 cloud `record_id`，也不互相替换。Sprint 6D 遗留 UUID Profile 会在首次 pull 时懒迁移：选择最高 `server_version` 的未删除记录复制为 canonical Profile，legacy rows 保留且后续 pull 只返回 `profile`。

### Conflict Resolution

当客户端版本落后且双方内容都发生变化时，不应静默覆盖。Sprint 6B 仅返回基础 conflict 结果；Journal、Daily Note、Today、Health 等业务的可恢复冲突流程留给后续 Sprint。

### Tombstone / Soft Delete

删除通过 `deleted_at` 作为 tombstone 同步。服务端和客户端必须继续传递 tombstone，直到所有相关设备有机会接收；不能把同步删除立即等同于物理删除。

## 微信登录定位

微信登录只负责证明用户身份，不负责存储或同步 Rebirth 数据。

### Mobile

```text
Flutter App
  -> WeChat SDK returns auth code
  -> Rebirth Backend receives code
  -> Rebirth Backend exchanges code with WeChat server
  -> Rebirth Backend obtains provider identity
  -> Rebirth Backend creates/finds Rebirth user
  -> Rebirth Backend issues Rebirth access token / refresh token
  -> Flutter App uses Rebirth token for sync
```

Sprint 6B 不集成微信 SDK，也不调用微信服务。`/auth/wechat/mobile` 只返回 `not_implemented`。

### Desktop / Web

```text
Flutter Desktop/Web
  -> Open browser or QR login flow
  -> WeChat returns code to backend callback
  -> Backend creates/finds Rebirth user
  -> Client receives or polls Rebirth session
  -> Client uses Rebirth token for sync
```

Sprint 6B 仅预留 start/callback endpoint 合同，不实现浏览器回调、二维码轮询或会话交付。

## 本地优先与同步边界

1. Flutter 现有 Today、Journal、Plan、Health 保存路径保持本地优先，但只对已认证且已激活绑定数据空间的用户开放。
2. 已绑定用户可在后端离线时继续访问和保存自己的本地数据；signed-out 或 `bindingRequired` 状态不能进入业务页面。
3. 后续同步层只能读取明确标记为待同步的本地变更，并通过 Repository 边界回写结果。
4. 同步范围必须由用户明确启用；在敏感数据范围设计完成前，不默认上传全部本地表。
5. 服务端接收时间可用于诊断，但不得静默改写自然日或客户端业务时间。

## 运行时 Server Endpoint

有效地址优先级为：用户在 Settings 保存的地址、`REBIRTH_API_BASE_URL` dart-define、`AppConfig` 默认 `http://127.0.0.1:8000`。Settings 只接受无 userInfo、query、fragment 和业务 path 的 HTTP/HTTPS origin；保存前必须通过兼容 `/health` 检查。endpoint 保存后 Riverpod 重建共享 ApiClient，无需重启 App 或重建 APK。

会话记录签发它的 normalized endpoint。切换到不同 endpoint 会清除旧 token 和 device registration，但不清除 Flutter SQLite、Profile、Today、Journal、Plan 或 Health。规范化后相同的地址不会退出登录，连接测试失败也不会保存或清除旧会话。

## 安全边界

- 客户端只持有 Rebirth 会话凭据和第三方 SDK 返回的短期授权 code。
- WeChat AppSecret、JWT signing secret 和生产数据库凭据只存在于后端受控环境变量或密钥系统。
- 开发默认 JWT secret 仅用于本机开发；非 development 环境必须显式配置。
- Device 必须属于当前 token 用户且未撤销，才可调用 push/pull。
- 日志和错误响应不得包含 token、第三方 code、AppSecret 或完整 Authorization header。

## 禁止事项

- Flutter 客户端保存 WeChat AppSecret。
- Flutter 客户端直接用 AppSecret 换取第三方 access token。
- 使用 `openid` 或其他 provider subject 直接当作 Rebirth user ID。
- 无 Rebirth token 访问同步 API。
- 无设备绑定上传或拉取数据。
- 忽略 `deleted_at` 的同步。
- 忽略 `server_version` 的增量语义。
- 同步失败影响本地保存。
- 在没有真实会话或同步结果时展示“已登录”“已同步”或“云端已连接”。

## Sprint 10B.2-A Account Boundary

Flutter schema 5 使用独立 `cloud_account_bindings` 表连接本地数据空间与云端身份：

```text
normalized endpoint + cloud_user_id
  -> exactly one cloud_account_binding
  -> exactly one local user_profiles row
  -> that profile's local business rows and sync metadata
```

`UNIQUE(endpoint_key, cloud_user_id)` 防止同一云账号映射到多个本地空间，`UNIQUE(local_user_id)` 防止一个本地空间属于多个云账号。登录和账号切换在同一 Drift transaction 中解析或创建绑定、切换唯一 active Profile，并在提交后失效账号范围内的 Riverpod 状态。

App 启动由 `initializing`、`signedOut`、`authenticated`、`authenticatedOffline`、`sessionRejected`、`bindingRequired` 和 `fatalMigrationError` 控制。Router 在未认证或迁移待确认状态下阻止 Today、Journal、Plan、Health、Growth 和 AI Coach。当前 Alpha 登录页继续使用 `/auth/dev-login`，并允许在进入业务页面前配置 Server Base URL。

Sync Coordinator 在 device registration、cursor read、collect、push、pull 和 apply 前验证 active local profile 的 binding 与当前 normalized Endpoint、cloud user 完全一致。失败返回 `accountScopeMismatch`，且不得上传、拉取、推进 cursor 或创建 conflict。

schema 4 升级到 5 时不自动认领旧 Profile。旧未绑定数据原样保留并进入 `bindingRequired`；现有未完成的 `awaiting_remote_snapshot` conflict 保留 snapshot 与时间，并标记为 `superseded_by_account_isolation_migration`。

## 当前限制

Sprint 8D 的 AI pending recovery 额外将 request ID 绑定到 normalized endpoint 与当前 Rebirth cloud user ID。切换 endpoint 或账号后不会向新 Server/其他账号查询旧请求；用户切回原绑定后才能检查。Binding 不保存 token、业务 payload 或报告正文。

- Windows 开发仍可使用 SQLite；Docker 开发拓扑提供 FastAPI + PostgreSQL，但这不代表正式生产部署。
- JWT refresh 生命周期、撤销列表、密钥轮换和安全存储尚未实现。
- Profile 同步冲突只检测并提示，不提供字段级合并或覆盖选择 UI。
- 没有真实微信 Open Platform 配置或外部调用。
- Flutter Account 已通过独立 data layer 连接 `/health`、`/auth/dev-login` 和 `/devices/register`。
- 开发会话使用可替换的本地开发存储；尚未接入平台安全存储或 token refresh。
- Flutter 仅为 `user_profiles` 手动调用 `/sync/push` 和 `/sync/pull`。
- Today、Journal、Plan、Health 仍未接入同步，也没有自动后台同步。
- SharedPreferences 中的 token 仍是开发级存储，尚未接入 secure storage。
- 没有完整 refresh/revoke 生命周期、字段级 Profile 冲突合并或真实微信登录。
- HTTP 仅限本机、局域网与 alpha 测试，正式云部署必须使用 HTTPS。
- 旧未绑定 Profile 必须在 `bindingRequired` 页面显式认领或选择创建全新空间；系统不会自动猜测归属。
- 当前登录仍是 Development User Key，不是生产级注册、OAuth、微信登录或安全凭据存储。

## Sprint 10B.2-B Legacy Ownership Resolution

Flutter schema 6 将本地所有权和云同步资格拆成两个持久状态：

- `binding_origin` 记录 `clean_first_login`、`fresh_space` 或
  `legacy_claim`；
- `sync_eligibility_status` 记录 `ready` 或
  `legacy_review_required`；
- `ownership_confirmed_at` 记录显式确认或创建的 UTC 毫秒时间。

升级用户登录后会看到不含正文、完整身份标识或完整 Endpoint 的本地数据
空间概览。用户只能显式认领一个旧空间、创建一个全新空间，或退出登录。
认领和新建都需要二次确认，并在 Drift transaction 中重新验证当前 Session
与 Endpoint + cloud user 作用域。

`legacy_claim` 完成后允许进入本地业务页面，但同步资格为
`legacy_review_required`。`SyncCoordinator` 在 device、cursor、collect 和
网络操作前返回 `accountSyncReviewRequired`；Settings 同时禁用 Profile 和
Plan 手动同步。旧 `server_version`、`last_synced_at`、`sync_status`、cursor、
conflict 和 AI pending 均保留。`fresh_space` 与干净首次登录的同步资格为
`ready`，但仍然只允许用户主动使用既有手动同步，不增加自动同步。

## Sprint 10B.3 Legacy Cloud Ownership Verification

Flutter schema 7 adds an auditable verification state to each account
binding. Local ownership remains defined by `cloud_account_bindings`; cloud
history verification is a separate proof that old Profile/Plan sync metadata
matches records owned by the current JWT user.

The user must explicitly select `验证云同步资格` in Settings. The client sends
only `table`, canonical record ID, positive `server_version`, and a SHA-256
fingerprint over non-content sync metadata. It never sends a trusted
`user_id`, local Profile ID, business payload, token in the body, cursor,
conflict snapshot, or AI data. `POST /sync/verify-ownership` derives the owner
only from the bearer JWT.

Only a structured `verified` response changes
`legacy_review_required -> ready`. `unknown` remains `not_verified`;
`rejected` becomes `failed`; both keep sync closed. The transition rechecks
the Session, normalized Endpoint, active local Profile, and binding in a Drift
transaction. Verification success does not run Profile or Plan sync. Users
must still invoke an existing manual action.

The Sync Coordinator keeps the order:

```text
Auth scope -> binding -> sync eligibility + verification -> network
```

Cursor, conflict, tombstone, AI pending, and AI Consent state are never read
for recovery or changed by verification.

## Sprint 13A.1 Session-backed Authentication

The earlier development token limitations above are superseded for the current
codebase. Authentication now uses database-backed sessions, short-lived access
JWTs, rotating opaque refresh tokens, reuse detection, logout revocation, and
Android/Windows secure storage. Access tokens are memory-only.

Existing `dev` identities remain compatible through HMAC subject migration.
`password_username` identities may be registered, logged in, or attached to an
existing verified Dev account. The public username/password page is deferred to
Sprint 13A.2 and WeChat remains unimplemented.

Authentication gates every existing Sync API, but does not change API Version 1,
Sync Protocol 2, entity payloads, device ownership, cursor semantics, OCC, or the
manual-only sync policy. See
`docs/40_AUTHENTICATION_PROTOCOL_AND_SECURE_SESSION.md`.
