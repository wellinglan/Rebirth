# AI Data Consent Foundation Manual Test

## 前置条件

- 使用包含 Sprint 8A 的 Windows 或 Android debug build；
- 不需要启动 FastAPI、Docker、登录或连接网络；
- 准备至少一条 Today、Journal 和 Health 本地记录，便于验证撤销不删除数据。

## 授权流程

1. 新安装或清除本地数据后启动 App。
2. 进入 Settings，找到“AI 数据与隐私”。
3. 确认状态为“未启用”，且页面说明当前不会向网络发送数据。
4. 点击“启用 AI 数据使用”，确认出现授权 Dialog。
5. 检查 Dialog 说明主动操作、每次 scope 选择、Journal 不自动包含、可撤销和数据保留边界。
6. 点击“取消”，确认仍为“未启用”。
7. 再次打开 Dialog，点击“同意并启用”。
8. 确认状态变为“已启用”并显示最近同意时间。
9. 完全关闭并重启 App，确认启用状态仍然保留。
10. 快速重复点击授权操作，确认保存中按钮禁用且没有重复提交。

## 撤销与数据保留

1. 点击“撤销授权”，确认撤销 Dialog 说明未来输入停止、已有报告保留、原始数据不受影响。
2. 取消一次，确认状态不变。
3. 再次打开并确认撤销，确认状态回到“未启用”。
4. 重启 App，确认仍为“未启用”，最近同意时间可以继续显示。
5. 检查已有 Today、Journal、Health 和 Plan 数据仍存在。
6. 检查 Growth 只读聚合仍可打开且数据未被删除。
7. 如测试库已有 AIReport，确认报告行仍存在。

## 隐私与平台检查

1. 在整个启用/撤销流程中观察网络工具，确认没有新增网络请求。
2. 确认 Settings 中没有 Provider、model 或 API Key 配置。
3. Windows 宽屏与窄窗口检查卡片、Dialog 无 overflow。
4. 运行 `flutter build apk --debug`，确认 Android debug APK 可构建。
5. Android 真机如未执行，在验收记录中明确写“未执行”，不得用 APK 构建结果代替真机结果。
