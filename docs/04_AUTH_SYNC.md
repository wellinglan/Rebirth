# Rebirth Auth & Sync Architecture

> Status: Sprint 6E cloud-ready Profile sync foundation
> Scope: manual canonical Profile-only sync, not production or full business sync

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

Flutter 本地 `app_settings.local_installation_id` 表示一次安装生命周期。它不代表用户身份，也不用于跨安装追踪；注册设备后才与云端 Device 建立关联。

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

1. Flutter 现有 Today、Journal、Plan、Health 保存路径保持不变。
2. 本地保存成功不依赖后端在线，也不依赖账号状态。
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

## Sprint 6E 当前限制

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
