# AI Coach Request Preview and Local History

## 1. Sprint 8B 基线与当前范围

Sprint 8B 建立本地 Request Preview 与 History；Sprint 8C/8D 已增加显式每周生成和 pending 状态恢复。Preview 仍不创建 pending、不保存 Input Snapshot，也不发送网络。Sprint 9A 新增 Daily Insight 的底层合同与开发测试链路，但不增加可见 Preview、生成按钮或 History 筛选。当前仍没有聊天、流式输出、后台任务或自动生成。

入口位于 Settings 的“AI Coach”分区：

- 列表路由：`/ai-coach`
- 详情路由：`/ai-coach/reports/:reportId`
- 主 Bottom Navigation 仍为 Today、Journal、Plan、Health、Growth 五项

## 2. Consent 与 Selection

Global Consent 表示用户允许 App 在主动操作时准备 AI 输入。单次 Scope Selection 表示本次 Preview
具体可以读取哪些数据，两者不能互相替代。

- Consent 关闭时不调用 Input Assembler，也不查询业务数据；
- 所有 Scope 默认未选择，不提供“全选”；
- 当前可选 Growth Summary、Today Metrics、Health Metrics、Journal Reflections；
- Journal 必须通过当前 Selection 的一次性确认，确认不写数据库；
- 关闭 Scope 或撤销 Consent 会清除 Preview、Bundle 与 reusable match；
- Consent 撤销时 Scope 重置为空，但已有 History 保留。

## 3. Weekly Preview

Preview 固定为包含今天的最近 7 个本地自然日，Prompt Version 为 `weekly-report-v1`。Controller 仅调用
现有 `AiCoachInputAssembler.buildWeeklyReport`，并固定 `persistInputSnapshot = false`。

页面显示报告类型、日期范围、已选 Scope、Prompt Version、来源数量，以及 Input Hash 的前 8 位和后
8 位。页面不显示或复制完整 Canonical JSON，也不显示 userId、记录 UUID、deviceId、endpoint 或同步元数据。

类型化 Preview 内容：

- Growth：科研、学习、运动总时长，平均睡眠、Mood、Energy，Journal 记录/完成天数；
- Today：日期、科研/学习分钟、Mood、Energy、Priority 数量和状态，不含 Daily Note/Priority 文本；
- Health：日期、睡眠、运动、饮水、体重、身体评分，不含 Health Note/外部来源标识；
- Journal：仅明确选择后显示日期、状态和五个结构化回答，正文只在本机显示，不摘要或改写。

`null` 显示“未记录/未填写”，已记录的 `0` 保持为真实 0。

## 4. Reusable Completed Report

Preview 成功后调用 `findReusableCompleted`。复用必须同时匹配：

- active local user；
- report type；
- period start/end；
- prompt version；
- input hash；
- completed 状态且未软删除。

Provider 和 model 不参与输入身份匹配。找到后只显示本地提示和详情入口，不自动打开、修改或新建报告。

## 5. Local History and Detail

History 通过 `AiReportRepository.listRecent()` 读取本地 `ai_reports`，按 requestedAt 降序显示类型、周期、
状态、请求/生成时间、Provider/Model（如有）、缩略 Hash、Input Snapshot 是否存在，以及 completed 正文预览。

详情按状态显示：

- completed：只读正文，并提示 AI 分析不修改原始记录；
- pending：显示一次性“检查服务器状态”操作；只调用 GET，不轮询、不重发 POST；Server 返回 not_found 时先保持 pending，用户明确确认后才将本地报告标记为失败；
- failed：只映射受控 error code，不展示异常、StackTrace 或 HTTP body。

详情只显示 Structured Output 和 Input Snapshot 是否存在，不展示它们的原始 JSON 正文。无效或已删除的
reportId 显示可读的未找到状态。

## 6. Soft Delete

列表和详情使用 `AiReportRepository.softDelete()`。确认对话框明确说明只软删除当前本地 AIReport，不删除
Today、Journal、Health、Plan、Growth，也不改变 Consent。删除当前详情后返回 History；失败时保留页面并
允许重试。当前没有回收站。

## 7. Architecture Boundaries

Presentation 只依赖 Domain 接口、类型化 presentation models 与 Riverpod Provider，不解析 Drift Row，
不访问 AppDatabase，不读取数据库 JSON 字符串。Preview Mapper 消费 `AiCoachInputBundle.canonicalPayload`
的公开只读合同，不读取 `canonicalJson`，不重新计算 Hash，也不重新查询业务 Repository。

Sprint 8B 不修改数据库表、migration 或 `schemaVersion = 3`，不修改 Growth、同步、Today、Journal、Health、
Plan，也不增加网络依赖。

## 8. Future Provider Boundary

未来 Sprint 8C 必须继续消费现有 `AiCoachInputBundle`，不得绕过 Consent、显式 Preview、Scope Selection 或
Input Assembler。真正网络发送前必须再次主动操作、重新检查 Consent，并完成新的隐私与错误处理评审。
Provider Gateway 不得读取 Drift Row、扩大 Scope、自动保存 Snapshot，或让模型输出覆盖用户事实。

## 9. Platform Verification

## 10. Sprint 8C Manual Generation

相同 Preview 若已有 completed report 继续优先复用，不显示重复生成主按钮。否则 Generation 区域独立加载 Server capabilities，不阻塞 Preview/History。用户必须阅读并确认 Provider/model、周期、scopes、Journal、最小化转发、source ID 排除、`store=false` 限制、准确性、费用和无自动重试后，才进入 `pending -> completed/failed`。

成功保存 Server 渲染的 Markdown、严格 structured output、实际 provider/model 并刷新 History；失败只保存受控 error code。Provider 明确 timeout 会 failed，客户端网络 timeout/connection loss 保持 pending 和 Binding。History 可按原 endpoint/account 查询 Server Ledger 并恢复，但不轮询、不重发 POST、不自动创建 request ID。

Server 临时结果只用于恢复，不是 History。`processing` 不保证完成；`outcome_unknown` 不代表必然未收费；`result_expired` 表示恢复窗口已结束。Consent 撤销后禁止新生成，但允许已有请求的状态恢复。

Windows 与 Android 共用独立路由和返回行为。Android debug APK 构建只证明可打包，不等于真机验收；
若本 Sprint 未连接 Android 真机，验收结果必须明确记录“未执行”。

## 11. Sprint 9A Daily Foundation Boundary

`daily_insight` 复用同一个本地 `ai_reports` 生命周期、Canonical/Hash、Gateway 和状态恢复抽象，但 Sprint 9A 不把它接入现有页面。普通用户仍只能使用既有 Weekly 手动流程。Daily 的显式日期、最小 Scope、严格输出与测试合同见 `docs/13_DAILY_INSIGHT_FOUNDATION.md`。
