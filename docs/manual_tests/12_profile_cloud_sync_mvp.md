# Sprint 6D Profile Cloud Sync MVP 手动测试

## 准备

1. 启动开发后端：

   ```powershell
   cd E:\Projects\Rebirth\server
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
   ```

2. 启动 Windows App：

   ```powershell
   cd E:\Projects\Rebirth
   flutter run -d windows
   ```

3. 确认本地数据库 `schemaVersion` 仍为 `3`。

## Windows 单端测试

1. 进入 Settings，点击“检查后端连接”。
2. 使用 `local-test-user` 完成开发登录。
3. 点击“注册当前设备”。
4. 进入 Profile，修改昵称与成长方向并保存。
5. 确认保存提示只表示本地资料已保存，网络异常不会阻止该操作。
6. 返回 Settings，确认“Profile 同步”显示“可手动同步”。
7. 点击“上传 Profile”，确认提示“Profile 已上传”。
8. 点击“拉取 Profile”，确认提示“没有新的 Profile 更新”或“Profile 已更新”，且没有错误。
9. 再次修改 Profile 并保存，确认本地记录的 `sync_status` 变为 `pending`。
10. 再次上传，确认本地同步元数据更新为 `synced`，并保存 `server_version` 与 `last_synced_at`。
11. 确认 Settings 没有显示 Today、Journal、Plan 或 Health 已同步。

## 跨端测试

1. 让 PC 后端监听局域网：

   ```powershell
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. Windows 使用同一 `dev_user_key` 修改并上传 Profile。
3. Android 使用同一 `dev_user_key` 登录并注册为另一台设备。
4. Android 拉取 Profile，确认昵称、成长方向和时区更新，本地 Profile UUID 不被云端 ID 替换。
5. 在 Android 修改并上传 Profile，再由 Windows 拉取，确认反向更新成立。
6. 当前 Settings 尚不能编辑 API Base URL；Android 真机联调使用编译期覆盖：

   ```powershell
   flutter run -d <android-device-id> --dart-define=REBIRTH_API_BASE_URL=http://192.168.x.x:8000
   ```

## 冲突测试

1. Windows 先完成一次上传，使本地 Profile 处于 `synced`。
2. Windows 修改 Profile 但不上传，使本地状态变为 `pending`。
3. 另一客户端修改并上传同一账号的 Profile。
4. Windows 点击“拉取 Profile”。
5. 确认提示“检测到本地与云端都有修改，暂未自动覆盖”。
6. 确认 Windows 本地未上传内容仍然存在，且 `sync_status` 标记为 `conflict`。

## 登录与故障测试

1. 退出登录，确认本地 Profile 不被删除。
2. 未登录点击上传或拉取，确认提示“请先开发登录”。
3. 登录但不注册设备，确认提示“请先注册当前设备”。
4. 停止 FastAPI 后上传或拉取，确认提示“无法连接开发后端，本地资料未受影响”。
5. 确认本地 Profile 仍可编辑、保存和重新打开。

## 范围检查

- 同步请求中的表只能是 `user_profiles`。
- 不自动同步，不在 App 启动或登录后上传 Profile。
- 不上传 Today、Journal、Plan 或 Health。
- 不实现真实微信登录。
- 不在日志、错误、截图或测试快照中暴露 access token。
