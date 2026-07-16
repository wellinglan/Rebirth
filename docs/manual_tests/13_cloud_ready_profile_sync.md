# Sprint 6E Cloud-Ready Profile Sync 手动验证

> 当前只同步 canonical Profile。Today、Journal、Plan、Health 均保持本地，不执行后台或定时同步。

## 链路 A：Windows + SQLite

1. 启动 Server：

   ```powershell
   cd E:\Projects\Rebirth\server
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. 打开 `http://127.0.0.1:8000/health`，确认 `status=ok`、`service=rebirth-api`、`api_version=1`、`sync_protocol_version=2`。
3. 启动 `flutter run -d windows`。
4. Settings 显示 `http://127.0.0.1:8000`，测试连接。
5. 使用唯一 `dev_user_key` 登录并注册 Windows 设备。
6. 修改本地 Profile，上传后再拉取。
7. 确认云端 `user_profiles` 的 `record_id=profile`，本地 Profile UUID 未改变。

## 链路 B：Windows + Android 局域网

示例地址为 `http://183.172.12.151:8000`，只用于当前局域网手动测试，不是 AppConfig 默认值。

1. Server 必须监听 `0.0.0.0:8000`，电脑防火墙允许该端口。
2. 手机浏览器打开 `http://183.172.12.151:8000/health`。
3. 构建普通 alpha APK：

   ```powershell
   cd E:\Projects\Rebirth
   flutter build apk --release --split-per-abi
   ```

4. 安装与手机 ABI 匹配的 APK，例如 arm64：

   ```powershell
   adb install -r .\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
   ```

5. Android Settings → 开发服务器 → 修改服务器，输入示例地址，点击“测试连接”，成功后保存。
6. Windows 和 Android 使用同一 `dev_user_key`，分别注册自己的设备。
7. 记录两端本地 Profile UUID，确认二者不同。
8. Windows 修改 Profile 并上传，Android 拉取；确认 Android 本地 UUID 不变。
9. Android 修改 Profile 并上传，Windows 拉取；确认 Windows 本地 UUID 不变。
10. 检查 Server：同一 cloud user 只有一个 `user_profiles/profile` canonical row；可能存在的 legacy UUID rows 仅保留兼容，不再 pull。
11. PC 局域网 IP 改变后，只在 Android Settings 修改、测试并保存新地址，不重新构建 APK。
12. cleartext HTTP 只适用于 alpha LAN；正式云服务必须使用 HTTPS。

## 链路 C：Docker + PostgreSQL

1. 准备本地 `.env`，不要提交真实密码：

   ```powershell
   cd E:\Projects\Rebirth\server
   Copy-Item .env.example .env
   docker compose -f docker-compose.dev.yml up --build
   docker compose -f docker-compose.dev.yml ps
   ```

2. 确认 `postgres` 和 `api` healthy，`/health` 返回兼容版本。
3. Flutter Settings 输入 Docker host 的可达地址并保存。
4. 验证 dev login、device register、canonical Profile push/pull。
5. 使用另一个 `dev_user_key`，确认不能读取前一用户 Profile。
6. 执行 `docker compose -f docker-compose.dev.yml down`，再启动，确认 Profile 仍存在。
7. 可选 PostgreSQL 测试：

   ```powershell
   $env:REBIRTH_POSTGRES_TEST_URL = 'postgresql+psycopg://rebirth:password@127.0.0.1:5432/rebirth_test'
   .\.venv\Scripts\python.exe -m pytest -m postgres
   ```

8. 不使用 `down --volumes`，除非明确接受永久删除开发数据库。

## 链路 D：Endpoint 切换与 Session 绑定

1. 连接 Server A，完成登录和设备注册。
2. 输入不可达 Server B 并测试：确认不能保存，A endpoint 和 session 保持。
3. 输入可达 B 并测试成功，点击保存。
4. 确认出现退出登录说明，明确本地 Profile/Today/Journal/Plan/Health 不受影响。
5. 确认保存后旧 session 与旧 device registration 被清除。
6. 在 B 重新登录并注册，后续 health、Account、device 与 Profile sync 请求只发往 B。
7. 输入与 B 规范化后相同的地址（例如只多一个 `/`），确认不会退出登录。
8. 恢复默认地址时重复同一确认逻辑；切回 A 后需重新登录。

## 链路 E：Conflict 与 Pull Cursor

1. Windows 与 Android 先同步到相同 canonical Profile 版本。
2. Windows 修改本地 Profile 但不上传，使状态为 `pending`。
3. Android 修改并上传。
4. Windows 拉取，确认显示“检测到本地与云端都有修改，暂未自动覆盖”。
5. Windows 本地内容和云端内容都不被静默覆盖。
6. Windows pull cursor 不推进。
7. 再次 pull，确认仍能获得同一 canonical 服务端变更。
8. 当前 Sprint 不提供字段级合并或覆盖选择 UI。

## Legacy Profile 兼容

1. 使用含一个或多个 Sprint 6D `user_profiles/<local-uuid>` rows 的备份 Server 数据库。
2. 新客户端 pull Profile。
3. 确认最高 `server_version` 的未删除 legacy payload 被复制为 `user_profiles/profile`。
4. canonical 获得新的全局 server version，legacy rows 未删除。
5. 重复或并发 pull 不产生第二个 canonical row。

## 安全与范围

- 不记录 access token、refresh token、JWT secret、数据库密码或完整 Authorization header。
- 当前 token 存储仍为开发级 SharedPreferences，没有 secure storage 和完整 refresh/revoke。
- 没有真实微信登录、mDNS、UDP、网段扫描、自动同步或正式云部署。
- Flutter Drift `schemaVersion` 保持 3；endpoint、cursor 和 session metadata 使用 SharedPreferences。

