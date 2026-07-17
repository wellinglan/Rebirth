# AI Coach Privacy and Input Contract

## 1. 当前范围

Sprint 8A 建立 AI Coach 的本地隐私、输入合同与报告生命周期基础，Sprint 8B 在该合同上增加
Request Preview 与 Local History：

- AI 数据使用默认关闭；
- 不调用网络，不接入 AI Provider，不保存 API Key；
- 不生成真实报告，也不用本地模板冒充 AI 输出；
- Preview 只在本机组装和展示，不创建 pending report；
- History 只读取本地 `ai_reports`，仅允许查看与软删除；
- 唯一可构建的报告类型是 `weekly_report`；
- `ai_reports` 是本地报告唯一事实来源，`schemaVersion` 保持 3。

## 2. Consent 与 Scope Selection

全局 Consent 保存在 `app_settings.ai_data_sharing_enabled`，最近一次同意时间保存在
`ai_data_sharing_consent_at`，时间单位为 UTC millisecondsSinceEpoch。

Consent 只表示用户允许 App 在其主动操作下准备输入。它不表示自动发送、自动生成、自动选择全部数据，
也不是不可撤销的永久授权。每次构建仍必须传入非空 `AiDataSelection`，且没有 `selectAll` 默认入口。

撤销时设置 `enabled = false`，保留最近一次 `consentAt` 作为本地授权审计信息。撤销会阻止新的输入构建
和 pending 报告创建，但不会删除已有 AIReport，也不会删除或修改 Today、Journal、Health、Plan、Growth
及其他原始数据。授权字段不参与 Profile Sync 或云同步。

## 3. Weekly Report 合同

Weekly Report 使用当前本地自然日及之前共 7 天，日期范围为闭区间，包含今天：

- `schema_version = 1`
- `report_type = weekly_report`
- `prompt_version = weekly-report-v1`
- `period.start_date` 与 `period.end_date` 为 `YYYY-MM-DD`

顶层固定字段为：

```json
{
  "schema_version": 1,
  "report_type": "weekly_report",
  "prompt_version": "weekly-report-v1",
  "period": {
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD"
  },
  "scopes": [],
  "data": {},
  "sources": []
}
```

合同不得包含用户 ID、安装 ID、设备 ID、token、endpoint、数据库路径、Provider、model 或同步元数据。

## 4. Scope 与最小化字段

当前可用 scope：

- `growth_summary`
- `today_metrics`
- `health_metrics`
- `journal_reflections`

`active_goals` 仅预留枚举，选择时明确失败，不会静默忽略。

### 4.1 growth_summary

数据来自已有 `GrowthRepository` 的 7 天 `GrowthSnapshot`，不修改 Growth Aggregator。包含：

- period days；
- research、learning、exercise、sleep、mood、energy summary；
- 每个 summary 的 recorded day count、total、average、minimum、maximum；
- journal recorded days 与 journal completed days。

### 4.2 today_metrics

包含日期、科研/学习分钟、Mood、Energy、有效 priority 数、完成 priority 数和状态。明确排除 priority
文本、goalId 和 dailyNote。

### 4.3 health_metrics

包含日期、睡眠分钟、运动分钟、身体状态评分、饮水量和体重。明确排除 note、source record ID、
data source 和 todayRecordId。

### 4.4 journal_reflections

只有显式选择时才查询和加入。包含日期、状态以及五个结构化回答；文本只做 trim，空字符串归一为
`null`。data 中不包含 Journal ID、todayRecordId、userId 或同步字段。Journal 正文不得进入日志或异常。

Today dailyNote、priority 文本、Health note、Goal 文本均不在本合同的默认结构化输入中。

## 5. Sources 追踪

行级 source 只来自显式选择的明细 scope：`today_records`、`health_records`、`journal_entries`。
每条引用仅含 `table`、`id`、`updated_at`，先按 table、再按 id 升序，同一 table/id 去重并保留最大的
updatedAt。软删除记录由各业务 Repository 在查询边界排除。

GrowthSummary 是派生数据，不伪造 `growth_summary` 表引用。它采用稳定可验证的替代追踪：完整统计值、
日期范围、schema version 与 prompt version 都进入 Canonical 合同和 hash；相同本地 Growth 查询可重算验证。
因此未选择 Journal scope 时，纯 Journal 正文变化不会因 source updatedAt 泄漏到 hash。

## 6. Canonical JSON 与 Input Hash

Canonical JSON 规则：

1. Map key 递归按字典序排列；
2. scopes、sources 和日期数组由 Assembler 在编码前稳定排序；
3. 使用 UTF-8，不加入格式化空白；
4. 保留 `null`、`0`、bool、int 和有限 double 的 JSON 类型；
5. 禁止对 Dart `toString()` 或当前 HashMap 迭代顺序进行哈希。

`input_hash` 对完整 Canonical Input Contract 的 UTF-8 字节执行 SHA-256，保存 64 位小写十六进制。
schema、report type、prompt version、period、scopes、data 与 sources 均参与。Provider、model、generation
mode、请求时间、设备和同步元数据不参与。`null` 与 `0` 产生不同 hash。

## 7. Snapshot 与报告生命周期

`persistInputSnapshot` 默认 `false`，因此 `input_snapshot_json` 默认保存 `NULL`。只有调用方明确设置为
`true` 时，Repository 才保存已构建的 `canonicalJson`，Repository 不得自行扩大保存范围。

本地生命周期：

1. `createPending` 再次检查 Consent，固定 `generation_mode = manual`、`sync_status = local_only`；
2. `pending -> completed` 在事务内写入非空正文、可选结构化输出/Provider/model、generatedAt 和 updatedAt；
3. `pending -> failed` 只保存受控 error code，不保存 Exception、StackTrace、HTTP body 或 token；
4. completed 或 failed 不允许再次转换；
5. completed 复用必须同时匹配本地用户、类型、日期范围、prompt version、input hash、completed 状态，
   且记录未软删除；
6. 软删除报告不影响任何输入来源或原始记录。

未来网络接入必须建立在本合同之上。Future Provider 只能接收完整的 `AiCoachInputBundle`，不得绕过
Input Assembler；Future UI 不得直接把 Drift 行或数据库查询结果发送给模型。AI 输出永远不能覆盖用户事实。

## 8. Sprint 8B Preview 与 History 边界

## 9. Sprint 8C Provider 发送边界

Preview 仍是纯本地操作且不创建 pending。只有登录、Consent、capabilities、合同版本、reusable 检查和最终发送确认全部通过后，Controller 才创建本地 pending 并调用 Rebirth Server。Server 对完整 Canonical payload 重算 hash，但向模型移除 `sources`、所有记录 ID、请求/hash/用户/设备/token/endpoint/sync 元数据，只转发明确选择的最小化 scope data。

OpenAI Key 只存在于 Server 环境；客户端不持有、不保存也不提供设置 UI。Provider 请求使用 `store=false`、无 tools、无 streaming，但产品文案不得将此描述为绝对零保留。报告输出只读，不修改任何原始记录；AIReport 继续 local-only 且 input snapshot 默认为空。

- Settings 是 AI Coach 的唯一入口，独立路由为 `/ai-coach`，不增加 Bottom Navigation 项；
- 全局 Consent 与单次 Scope Selection 分离，所有 Scope 默认关闭；
- Journal 每次加入当前 Selection 前都需单独确认，确认不持久化，也不改变 Global Consent；
- Preview 通过现有 `AiCoachInputAssembler` 构建，`persistInputSnapshot` 固定为 `false`；
- Preview 只展示类型化的最小字段、缩略 Input Hash 和来源数量，不展示完整 Canonical JSON；
- 构建后只调用 `findReusableCompleted` 检查完全匹配的本地 completed report；
- Preview 不调用 `createPending`、`markCompleted` 或 `markFailed`，也不调用网络；
- History 来自本地 `ai_reports`，详情不展示 `input_snapshot_json` 或 structured output 正文；
- 软删除仅影响选中的 AIReport，不影响 Consent 或 Today、Journal、Health、Plan、Growth 源数据。

详细页面、Controller、匹配条件和后续 Provider 边界见
`docs/09_AI_COACH_PREVIEW_AND_HISTORY.md`。
