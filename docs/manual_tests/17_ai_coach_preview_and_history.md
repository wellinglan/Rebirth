# AI Coach Preview and History Manual Test

## 前置条件

- 使用 Sprint 8B 的 Windows debug build；
- 不需要 FastAPI、Docker、登录或网络；
- 可选：测试数据库中准备 completed、pending、failed 各一条 AIReport；
- 不得在生产代码中增加示例报告按钮。

## Consent 与入口

1. Consent 关闭时，从 Settings 的“AI Coach”入口进入。
2. 确认显示授权门禁和“当前不会准备任何 AI 输入”。
3. 点击“前往授权设置”，确认返回 Settings 的 AI 数据与隐私区域。
4. 启用 Consent 后返回 AI Coach，确认显示 Scope UI。

## Scope 与 Preview

5. 确认 Growth、Today、Health、Journal 默认均未选择，构建按钮禁用。
6. 只选 Growth，构建本地 Preview，检查汇总字段和 `null`/`0` 区别。
7. 改选 Today，确认旧 Preview 立即消失，再检查日期升序和排除字段说明。
8. 选择 Health，检查睡眠、运动、饮水、体重和身体评分。
9. 点击 Journal，选择取消，确认 Journal 仍关闭。
10. 再次点击 Journal 并确认，检查 Dialog 的私人内容、本机预览和不保存快照说明。
11. 构建 Preview，确认 Journal 仅在明确选择后出现，空回答显示“未填写”。
12. 确认页面明确说明不会发送服务器或 AI 模型。
13. 确认只显示缩略 Input Hash，不显示完整 Canonical JSON。
14. 关闭任一 Scope，确认旧 Preview 与 reusable 提示消失。

## History 与详情

15. 无报告时切换到“本地报告”，确认显示克制空状态且不插入示例数据。
16. 有 completed fixture 时，确认列表显示已完成、正文预览与元数据。
17. 有 pending fixture 时，确认显示“待处理”文字且无无限 loading 动画。
18. 有 failed fixture 时，确认显示“生成失败”且无底层异常。
19. 打开 completed 详情，确认正文只读，Input Snapshot 只显示是否存在。
20. 打开 pending 详情，确认没有继续处理按钮。
21. 打开 failed 详情，确认 error code 为友好文案，不显示 StackTrace/HTTP body。
22. 使用无效 reportId，确认显示可读的未找到状态。

## Soft Delete 与数据保留

23. 从列表打开删除确认，检查 Today、Journal、Health、Plan、Growth 和 Consent 保留说明。
24. 取消一次，确认报告仍存在；再次确认，仅选中报告消失。
25. 在详情删除当前报告，确认返回 History。
26. 检查 Today、Journal、Health、Plan、Growth 原始数据均未变化。

## 平台与可访问性

27. Windows 在 320、360、412、720、840、1200 宽度及 2.0 文字缩放下检查滚动、Dialog、Tab、Scope
    Semantics、状态文字和删除 tooltip，无 RenderFlex overflow。
28. 运行 `flutter build apk --debug`。如未连接 Android 真机，验收记录明确写“Android 真机：未执行”，
    不得用 APK 构建成功代替真机结果。
