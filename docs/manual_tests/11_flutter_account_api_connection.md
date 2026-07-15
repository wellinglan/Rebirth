# Sprint 6C Flutter Account API Connection 手动测试

## Windows 开发联调

1. 打开终端并进入 `server`：

   ```powershell
   cd E:\Projects\Rebirth\server
   .venv\Scripts\Activate.ps1
   uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
   ```

2. 浏览器访问 `http://127.0.0.1:8000/health`，确认返回 `status: ok` 和 `service: rebirth-api`。
3. 另开终端启动 Flutter Windows App：

   ```powershell
   cd E:\Projects\Rebirth
   flutter run -d windows
   ```

4. 进入 Settings，确认初始页面不会自动请求后端。
5. 点击“检查后端连接”，确认显示“开发服务已连接”，并出现“开发后端已连接”提示。
6. 点击“开发登录”，确认出现 `dev_user_key` 输入框。
7. 输入 `local-test-user` 并登录。
8. 确认显示“已登录，开发账号”和开发用户名称；“跨端同步”仍为“尚未启用”。
9. 点击“注册当前设备”。
10. 确认设备状态为“已注册”，并且只显示短格式设备 ID。
11. 关闭 App 后重新启动，确认开发登录和设备注册状态可以恢复。
12. 点击“退出登录”，确认状态回到“未登录”和“未注册”。
13. 检查已有 Today、Journal、Plan、Health 与 Profile 数据仍然存在。
14. 停止 FastAPI 服务，再次点击“检查后端连接”。
15. 确认显示“无法连接开发后端”，同时本地模块仍可读取和保存。
16. 点击“微信登录”和“同步设置”，确认两者仍明确显示尚未启用。
17. 确认页面没有显示“跨端同步已启用”“微信已绑定”或“云端已同步”。
18. 确认 Flutter 本地数据库 `schemaVersion` 仍为 `3`。

## Android 真机补充

1. 启动可被局域网访问的服务：

   ```powershell
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. Android 真机不能使用 `127.0.0.1` 访问电脑服务。
3. 当前 Sprint 尚未提供 Settings 内编辑 Base URL；后续需要配置为电脑局域网地址，例如 `http://192.168.x.x:8000`。
4. 确认电脑防火墙允许对应端口，且手机与电脑位于同一局域网。

## 安全与范围检查

- 不在日志、错误提示或截图中记录 access token、refresh token 或完整 Authorization header。
- 开发登录不代表业务数据已同步。
- 设备注册不触发 Today、Journal、Plan 或 Health 上传。
- 微信 AppID、AppSecret 和生产凭据不得放入 Flutter 客户端或仓库。
