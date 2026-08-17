# Rebirth AI Context

> Version: 1.0
> Status: Partially current / active mission with append-only Sprint history
> Last Updated: 2026-08

## Current Appendix: Sprint 15B AI Report Generation Pipeline

Sprint 15B does not expand AI capability. It consolidates existing explicit
Daily and Weekly AI Report generation into one application-layer coordinator.

`AiReportGenerationCoordinator` owns consent/session checks, endpoint-scoped
reusable report lookup, pending report creation, request binding persistence,
single-flight duplicate suppression, remote generation submission, terminal
local reconciliation, and status-only pending recovery. Presentation controllers
remain responsible for UI state and preview integrity, but no longer decide
Provider retry, repository terminal writes, binding cleanup, or recovery
semantics.

The boundary remains: no AI chat, no agents, no tool calling, no automatic
generation, no prompt changes, no Provider changes, no Sync Protocol changes,
and no server deployment implied by client implementation. See
`docs/51_AI_REPORT_GENERATION_PIPELINE.md`.

> Current-state authority: `docs/CURRENT_BASELINE.md`. Early technology notes
> that describe FastAPI or external AI as future work, and the Sprint 12D
> five-module Sync Center snapshot, are historical. The audited current code
> has a FastAPI Server, server-selected Disabled/Fake/OpenAI/DeepSeek AI
> Providers, public password authentication, and six manual sync modules:
> Profile, Plan, Today, Journal, Health, and AI Report.

> Sprint 14D: `ai_reports` is a manual Sync Protocol 2 aggregate. Its immutable
> versions travel only as children; payloads exclude prompts, inputs, runtime
> metadata, credentials, usage, and tokens. Schema is 11, API remains 1.

> Sprint 14D exposes the existing completed-to-archived lifecycle in the
> report detail UI. Archiving preserves body and immutable history, does not
> generate AI content, and transfers only aggregate metadata through manual
> sync. AI Report conflicts use the existing conflict center and never render
> report body, prompt, provider, token, or secret.

> Sprint 14E establishes `/ai-reports` as the single AI Report Library.
> Settings and AI Coach reach the same account-scoped list and detail state;
> the ordinary list shows lifecycle and safe sync status but never report body,
> Prompt, AI input, Provider/model, credentials, internal IDs, cursor, or
> payload. Schema remains 11, API remains 1, and Sync Protocol remains 2.
> Its Windows and Android manual matrix closed with 31 PASS and 0 FAIL on
> 2026-08-04.

> Sprint 14F adds explicit, local AI Report export. A single report is exported
> as UTF-8 Markdown and the active account library as versioned JSON. Export
> reads through the account-scoped Repository, rechecks account access before
> saving, and excludes identity, prompt/input, provider/model, ledger, sync,
> conflict, and credential metadata. It never mutates reports or starts AI or
> sync. Schema remains 11, API remains 1, and Sync Protocol remains 2.

> Sprint 15A adds explicit full personal data export for the current protected
> account. Typed modules produce a versioned plaintext JSON document with a
> deterministic SHA-256 over its canonical data payload. Credentials, account
> and device identity, endpoints, AI runtime inputs/ledgers, and sync/conflict
> state are excluded. Growth remains derived. The operation is local-only and
> non-mutating; import, restore, encryption, scheduling, and cloud backup remain
> unsupported. Schema remains 11, API remains 1, and Sync Protocol remains 2.

---

# 一、文档定位

本文件不是 Prompt。本文件是 Rebirth 项目的最高上下文（Highest Context）。

任何 AI（包括 ChatGPT、Codex、Claude、Gemini、Cursor 或未来新的 AI Agent）在参与本项目之前，都应首先阅读本文件。

如果代码实现、产品设计、开发建议与本文件冲突，应优先遵循本文件。

---

# 二、项目简介

## 项目名称

Rebirth

## 一句话介绍

**Rebirth 是一个由 AI 驱动的个人成长操作系统（Personal Operating System）。**

它不是：

- Todo 软件
- 打卡软件
- 日记软件
- 时间管理软件

而是：

帮助用户持续成长的长期陪伴系统。

---

# 三、项目使命（Mission）

Rebirth 存在的唯一目的：

> **帮助用户持续成为比昨天更好的自己。**

这里的成长包括但不限于：

- 学习
- 科研
- 健康
- 情绪
- 阅读
- 工作
- 人际关系
- 长期目标

成长，是整个产品唯一真正的 KPI。

---

# 四、产品愿景（Vision）

我们希望未来的 Rebirth：

不是记录用户做了什么。

而是真正理解：

- 用户为什么这样做；
- 用户目前处于什么阶段；
- 用户真正需要什么帮助。

最终形成一个真正理解用户的 AI Coach。

---

# 五、产品哲学（Product Philosophy）

这是整个项目最高优先级。

所有功能设计必须遵循以下原则。

---

## 原则一：成长高于效率

Rebirth 不以效率为最终目标。

效率只是成长的副产品。

如果一个功能能够提高效率，却不能促进成长，那么它不应该成为核心功能。

---

## 原则二：记录应该足够轻

用户每天记录时间应控制在：

**5 分钟以内。**

如果一个页面需要大量输入，应重新设计。

AI 的职责是减少输入，而不是增加输入。

---

## 原则三：AI 永远是教练，而不是裁判

AI 的身份：

Coach（教练）

而不是：

- 老师
- 家长
- 老板
- 考官

AI 可以：

- 引导
- 分析
- 鼓励
- 提供建议

AI 不应该：

- 指责用户
- 制造焦虑
- 使用命令式语言
- 对用户进行价值判断

---

## 原则四：所有数据必须产生价值

Rebirth 不记录无意义的数据。

每一项数据，都必须能够回答一个问题。

例如：

睡眠

↓

影响科研效率

↓

影响运动表现

↓

影响情绪状态

↓

影响长期成长

如果某项数据无法参与分析，就不应该要求用户记录。

---

## 原则五：长期理解用户

Rebirth 不关注：

"今天完成了多少任务。"

而关注：

"过去一年，用户发生了哪些变化。"

AI 应该逐渐建立长期用户画像，而不是短期聊天上下文。

---

# 六、产品边界

当前版本（V1.x）明确不做：

- 社交
- 排行榜
- 连续打卡奖励
- 勋章系统
- 游戏化积分
- 社区
- 广告
- 消息流

Rebirth 是一个个人产品。

不是社交平台。

---

# 七、目标用户

当前版本主要服务于：

- 本科生
- 研究生
- 博士
- 科研人员
- 工程师
- 长期学习者

共同特点：

希望持续成长，而不是单纯管理任务。

---

# 八、当前 MVP

V1.x 仅包含以下模块：

Today

Journal

Plan

Growth

Health

AI Coach

任何新增模块，都应经过 PRD 审核。

---

# 九、技术路线

当前技术栈：

前端：

Flutter

设计语言：

Material 3

状态管理：

Riverpod

路由：

GoRouter

数据库：

SQLite + Drift

网络：

Dio

图表：

fl_chart

后端：

FastAPI（当前已实现；“未来”是早期历史定位）

AI：

Server AI Provider abstraction（当前支持 disabled/fake/openai/deepseek）

目标平台：

Windows

Android

未来支持：

iOS

Web

---

# 十、软件架构原则

采用：

Feature First Architecture。

目录按照功能划分，而不是类型划分。

业务逻辑不得写入 Widget。

Widget 保持简单。

数据层、业务层、UI 层职责清晰。

任何模块都应能够独立维护。

---

# 十一、代码规范

代码全部采用英文命名。

用户界面文本采用中文资源文件。

变量命名应具有明确语义。

避免过度封装。

优先保证：

可读性。

其次才是：

可扩展性。

---

# 十二、Git 规范

Commit 使用 Conventional Commit。

例如：

feat:

fix:

docs:

style:

refactor:

test:

禁止使用：

update

aaa

123

final

等无意义提交信息。

---

# 十三、开发流程

所有功能必须遵循：

需求分析

↓

产品设计

↓

数据库设计

↓

UI 原型

↓

Flutter 实现

↓

测试

↓

Git Commit

↓

Push

不得跳过设计阶段直接编码。

---

# 十四、AI 的职责

AI 的职责包括：

产品设计

系统架构

代码生成

代码审查

Bug 分析

文档维护

数据库设计

AI 应始终优先保证：

项目一致性。

而不是：

局部实现速度。

---

# 十五、长期路线

未来可能加入：

云同步

多设备同步

Google Calendar

Health Connect

GitHub 数据同步

科研工作区

阅读系统

知识图谱

多 Agent 协作

但是：

所有功能都必须继续服务于：

> 帮助用户成长。

不得偏离项目使命。

---

# 十六、协作原则

未来可能由多个 AI 协作开发：

ChatGPT

Codex

Claude

Cursor

Gemini

未来其它模型

所有 AI 在修改代码之前，应优先阅读：

00_AI_CONTEXT.md

01_PRD.md

02_ARCHITECTURE.md

随后再开始开发。

---

# 十七、最终原则

框架可以升级。

模型可以替换。

代码可以重构。

UI 可以重新设计。

但是：

Rebirth 的使命不会改变。

它不是帮助用户完成更多事情。

而是帮助用户成为更好的自己。

---

> **Rebirth 的目标，不是帮助你做更多，而是帮助你成为更多。**

---

# 十八、本地个人数据聚合边界

Rebirth 通过 `PersonalDataProvider`、Registry 与 Aggregation Engine 对
Profile、Plan、Today、Journal、Health 进行可扩展的本地派生读取。

聚合结果不是新的业务数据源，不持久化、不自动同步、不上传 Server，也不等于
AI Consent。Journal 正文和 Health 备注不进入默认聚合结果；Health 始终作为
高度敏感数据处理。未来模块通过实现 Provider 并在 Composition Root 注册接入，
不得要求 Engine 或通用页面增加模块 switch。

详细约束见 `docs/36_PERSONAL_DATA_AGGREGATION.md`。

# 十九、Growth Projection 与 Journal 状态边界

Growth 是 Personal Data Aggregation Framework 的只读上层消费者。它通过纯
Dart `GrowthDimensionContributor`、不可变 Registry 与故障隔离 Projection
Engine 生成可追溯的本地投影，不得直接读取 Today、Health、Journal、Plan
Repository 或 Drift。

首批维度为 Focus、Recovery、Subjective State 与 Reflection。指标必须保留
null 与 0、覆盖率、质量、敏感度和安全来源引用，不生成评价、诊断或 AI 建议。
Journal 正文与 Health 备注不进入 Growth；Evidence 不上传、不持久化。

Journal 产品状态统一为未记录（派生）、草稿和已完成。用户可显式保存草稿、
完成复盘，并在确认后把已完成记录重新编辑为草稿。状态变化复用现有 Journal
同步、OCC 和冲突恢复语义，不自动同步。

详细约束见 `docs/37_GROWTH_SYSTEM_FOUNDATION.md`。

# 二十、Journal Prompt System 边界

Sprint 12C 将 Journal 从固定五问升级为用户级 Prompt Configuration
Aggregate。新建 Journal 读取当前启用的问题，保存时持久化问题文本与版本快照；
历史 Journal 不随问题编辑、排序、禁用或删除而变化。动态 item 是回答的唯一
Source of Truth，旧五列仅作为 Journal payload v1 的临时兼容镜像。

Prompt 配置和 Journal 条目仍仅由用户手动同步，配置先于条目同步，并使用现有
OCC、cursor 和显式冲突恢复。Prompt/Response 正文不得进入 Growth、Personal
Data、日志或测试证据。本 Sprint 只预留 `futureAi` 来源，不调用模型、不自动
提出或启用问题。详细约束见 `docs/38_JOURNAL_PROMPT_SYSTEM.md`。

# 二十一、Settings 与统一手动同步边界

Sprint 12D 将普通 Settings 整理为账号、数据与同步、个人数据与隐私、
Journal、高级设置和关于。Endpoint、Development User Key、设备诊断和旧数据
归属验证集中到受 `enableDevLogin` 控制的开发者选项；普通页面不显示 Token、
内部用户 ID、完整设备 ID 或 Profile 推拉方向。

Sprint 12D 当时的同步中心只包含 Profile、Plan、Today、Journal、Health
五个用户模块；当前第六个模块 AI Report 已在后续 Sprint 接入。
`SyncModuleRegistry` 显式定义顺序，Journal 在一个模块内先同步问题配置再同步
Journal 条目。同步仍由用户主动触发，并继续复用现有 Coordinator、OCC、cursor、
事务、账号隔离和显式冲突恢复。没有自动同步、后台队列、新 Sync Entity、
数据库迁移或 Server 变更。详见
`docs/39_SETTINGS_INFORMATION_ARCHITECTURE_AND_SYNC_CENTER.md`。

# 二十二、认证协议与安全会话边界

Sprint 13A.1 在不改变 CloudUser 数据所有权的前提下复用 AuthIdentity，新增
`password_username` 身份、Argon2id 凭据、数据库会话、旋转式 opaque refresh
token 与短期 access JWT。Dev User Key 新写入改为 HMAC subject；旧身份惰性
迁移时保持 CloudUser、设备和同步数据归属不变。

Flutter 的 refresh credential 只进入 Android/Windows 安全存储，access token
仅在内存中存在。`AuthSessionManager` 统一处理单航班 refresh、一次 401 重试、
endpoint 绑定、离线态和明确失效；不会删除本地业务数据，也不改变五模块手动
同步、OCC、cursor 或 Sync Protocol 2。

Sprint 13A.1 不提供公开注册/登录页面，不实现找回密码、MFA 或微信认证。
其人工验收结果为 67 PASS / 0 FAIL / 12 NOT EXECUTED；Refresh Token
Rotation、Development Account Upgrade 与 Account Boundary Isolation Gate 已
关闭，其余公开认证体验 Gate 转入 Sprint 13A.2。Flutter schemaVersion 保持
9，Server API 保持 1。详见
`docs/40_AUTHENTICATION_PROTOCOL_AND_SECURE_SESSION.md`。

# 二十三、公开认证产品入口边界

Sprint 13A.2 将普通入口升级为用户名密码登录与注册。App 必须先完成安全会话恢复，
再由 Router 进入登录、账号归属确认或受保护业务壳；启动时不得短暂展示旧账号正文。
登录与注册成功仍必须经过既有 Account Boundary，A/B 本地数据空间、conflict、
cursor 与 serverVersion 不得串用或被清理。

Production 构建强制关闭开发登录，即使传入冲突的编译参数也不能重新启用；
Alpha/Development 仅可在公开登录页底部提供低优先级独立开发入口。普通页面不显示
Endpoint、Dev Key、Token、Session ID 或内部账号 ID。

Password 只存在于临时 Widget Controller，Access Token 只存在于运行时，
Refresh Token 只进入平台安全存储。认证仍不触发自动同步。Password Recovery、
MFA、微信登录与绑定继续延期。Flutter schemaVersion 保持 9，API Version 保持
1，Sync Protocol 保持 2。详见
`docs/41_PUBLIC_USERNAME_PASSWORD_LOGIN.md`。

2026-07-30 人工验收结果为 107 PASS / 0 FAIL / 7 NOT EXECUTED。
H1-H7 因不存在可安全使用的未绑定旧数据环境而诚实保留为 NOT EXECUTED。
Public Login Experience、Authentication Protocol、Password Credential
Security 与 Secure Client Storage Gate 已 `CLOSED / ACCEPTED`。

# 二十四、AI 生产运维审计边界

Sprint 14A.3 在现有 `AiGenerationRequest` 与 `AiUsageRecord` 上增加 Server-only
只读运维查询和 CLI。审计按 UTC 日期、Provider、Model 与 Request Type 聚合请求、
成功、失败、超时、过期和 token 数量；配置检查只输出非敏感设置；预算、Provider
失败率与 stale lease 只生成字段白名单内的安全事件。

运维工具不公开普通用户 API，不输出完整 user ID、Prompt、Journal/Health 正文、
报告正文、Authorization、API Key、Secret 或数据库 URL，也没有自动修复模式。
月度全局额度是运维告警阈值，不改变现有每日用户/全局硬限制。AI kill switch
继续由 Server 的 `REBIRTH_AI_PROVIDER=disabled` 控制，客户端无权修改。

本 Sprint 不修改 Server 业务表或 Alembic revision，不修改 Flutter；
`schemaVersion` 保持 9，API Version 保持 1，Sync Protocol 保持 2。详见
`docs/44_AI_OPERATOR_RUNBOOK.md`。

# 二十五、AI Report 本地持久化边界

Sprint 14B 将既有 `ai_reports` 演进为独立、本地、版本化的 Report 聚合，并以
`ai_report_versions` 保存不可变的完成或失败版本。新的结果只能追加版本，旧版本
不能更新或删除；schema 9 的既有完成/失败报告迁移为 v1。

报告正文属于高敏感本地数据，不进入 Growth Evidence、Personal Data
Aggregation、Journal、普通日志或手动同步。所有查询继续由 active local profile
限定，账号切换后不得读取其他账号报告。设置中的“AI 报告”页面只读展示列表、
详情、状态和版本历史，不自动生成，不调用 Provider，也不显示 Token、Prompt、
Secret、原始模型元数据或完整内部 ID。

Flutter `schemaVersion` 升至 `10`；PostgreSQL、Alembic、API Version `1`、Sync
Protocol `2` 均不变。在 Sprint 14B 完成时，AI Report 云端存储与跨设备同步尚不
支持；该历史限制已由 Sprint 14C 的手动跨端同步实现取代。当前传输边界详见
`docs/46_AI_REPORT_CROSS_DEVICE_SYNC.md`，Sprint 14B 的本地持久化边界详见
`docs/45_AI_REPORT_PERSISTENCE.md`。

# 二十六、完整个人数据导出边界

Sprint 15A 在 Settings 的“个人数据与隐私”区域增加用户显式触发的完整个人数据
导出。导出仅面向当前受保护账号，包含 Profile、Plan、Today、Journal、Journal
Prompt Configuration、Health 与 AI Report 当前正文和不可变版本历史。模块通过
不可变 Registry 和 typed exporter 接入，便携 DTO 不复用 Drift Row、API DTO 或
Sync Payload。

文件为 UTF-8 明文 JSON，格式版本为 `1.0`，并对规范化 `data` 计算 SHA-256；保存
前必须在内存中重新校验。导出保留业务关系、自然日、生命周期、软删除事实、
`null`、`0` 与空字符串，但严格排除认证凭据、Cloud/Auth/Device 标识、Endpoint、
AI Provider 输入与 Ledger、serverVersion、cursor、sync/conflict/tombstone transport、
私人路径和日志。Growth 与 Personal Data Aggregation 是可重算派生结果，不进入备份。

该流程不联网、不调用 AI、不触发同步、不修改数据库，也不保存用户选择的路径。
账号切换、退出或 SessionRejected 会使导出状态失效；打开保存选择器前必须再次
确认当前账号。当前只建立未来恢复可以审计的格式基础，不实现 Import、Restore、
Merge、加密、自动或云备份，也不得向用户宣称文件已经可恢复。详细约束见
`docs/50_FULL_PERSONAL_DATA_EXPORT_AND_BACKUP.md`。

# 二十七、Prompt 治理与质量评估边界

Sprint 15C 将 Daily 与 Weekly 的 Prompt 身份、版本、报告契约、Scope、输出
Schema、安全策略、评估 suite 和规范化 SHA-256 fingerprint 收拢到唯一的
Server Prompt Registry。active 版本必须显式指定，candidate 不会通过版本排序、
配置、数据库或 CLI 自动激活；已发布 fingerprint 变化会 fail closed。

当前 Daily/Weekly v1 仍是 active 且生产指令原样保留，v2 仅为 candidate。九个
完全合成 Case 覆盖缺失、null/0、稀疏趋势、Unicode、Prompt Injection、诊断与
虚构统计等边界。Level 1/2 完全离线并进入普通 CI；它们验证治理与规则，不证明
真实模型质量。Level 3 必须另行授权费用、使用现有 Ledger 与额度，并且本 Sprint
保持 NOT EXECUTED。无新 API、Provider、数据库迁移或 Flutter UI；schemaVersion
保持 11，API 1，Sync Protocol 2。详见
`docs/52_PROMPT_GOVERNANCE_AND_QUALITY_EVALUATION.md`。

## Sprint 16A AI Coach MVP Product Experience Boundary

Sprint 16A 将现有 Daily、Weekly、Consent、Usage、Coordinator、Pending
Recovery 与唯一 AI Report Library 收束为一级 `AI 教练` 产品入口。首页只组合
任务、可用状态、少量最近报告和自然 CTA；不会因为打开页面而生成、轮询、同步或
恢复请求。Settings 只保留 AI 授权与隐私。

“请求预览”改为“本次使用的数据”。Prompt Version 与 Input Hash 不再占据主流程，
只允许在默认收起的技术信息中显示模板版本和安全缩略摘要。真实调用前仍需显式确认
Provider、Model 与可能费用。账号切换必须使 Usage、Preview、Generation、Recovery
和报告列表全部失效。完整合同见
`docs/53_AI_COACH_MVP_PRODUCT_EXPERIENCE.md`。

# 二十八、AI Report 反馈与质量信号边界

Sprint 16B 为具体的不可变完成报告版本增加独立、可修改、账号限定的结构化反馈
Aggregate。用户只能选择“有帮助”或“没帮助”；后者必须从七个固定原因中选择，
系统不收集自由文本。反馈先写本地，再随用户显式触发的 AI Report 手动同步，经
专用 API 使用 OCC 和删除墓碑收敛。它不注册为新的 Sync Protocol 2 Entity。

Flutter `schemaVersion` 升至 `12`，Server Alembic head 升至
`20260812_0008`。API Version 保持 `1`，Sync Protocol 保持 `2`。反馈不会修改
报告正文或不可变版本，不创建生成，不消耗额度，不改变 Provider、Ledger 或 active
Prompt。Server `feedback-audit` 只输出按报告类型和 Prompt 身份聚合的匿名统计，
不输出用户/报告 ID 或正文。完整合同见
`docs/54_AI_COACH_FEEDBACK_AND_QUALITY_SIGNAL.md`。

# 二十九、产品体验与 UI 设计系统边界

Sprint 17A 将 Rebirth 定位为安静、可信的成长工作台，而不是任务积分系统、数据
驾驶舱或聊天优先的 AI 包装。Flutter 设计底座增加语义状态色、响应式断点、最小
触控尺寸、减弱动态效果约束、统一页面宽度及 Loading/Error 组件。HomeShell 在
手机使用底部导航，在 Windows 中宽使用紧凑 NavigationRail，宽屏使用展开导航；
六个一级入口和路由语义不变。

本 Sprint 只建立基础契约并接入少量基础状态，不机械重写所有页面，也不锁定最终
功能级美术方向。Flutter schemaVersion 保持 12，Server Alembic、API 1、Sync
Protocol 2、Provider、Prompt、业务同步与 Sprint 16B 手动 Gate 均不改变。完整
审计与后续优先级见 `docs/55_PRODUCT_EXPERIENCE_AND_DESIGN_SYSTEM.md`。

# 三十、Home / Today / Health 体验原型边界

Sprint 17A.1 在仅开发者可达的路由中验证 Home 构图、按需出现的快捷预设、饮水
水杯模型和可复用步进输入。所有可变值只存在于页面内存；模拟保存明确提示未写入，
并且 presentation 不依赖 Repository、Drift、AppDatabase、AI 或同步。

饮水支持 100/250/500 ml 步长，默认 250 ml；研究、学习、运动和睡眠仅在原型中
复用 15/30/60 分钟步长。`null`、显式 `0` 与正数保持不同语义，减少操作不低于
零。水杯只显示相对水位和精确数值，不提供医学目标或达标判断。昼夜环境图是仓库
内离线 WebP，寄语按本地日期确定且不调用 AI。Production 不注册该路由，现有六个
一级入口、生产 Today/Health、schemaVersion 12、API 1 与 Sync Protocol 2 均不变。
详见 `docs/56_HOME_TODAY_HEALTH_EXPERIENCE_PROTOTYPE.md`。

Prototype Revision 1 adds a reusable `WellbeingRatingField` for Mood, Energy,
and body feeling. It is a nullable 1-10 discrete visual experiment with a
soft-red/warm-yellow/soft-green active track, outlined near-white inactive
track, white thumb, explicit number, and optional 80-character description.
Scores and descriptions live only in prototype page memory. They do not map to
the production 1-5 fields, database, AI, logs, or sync. Material icons identify
the recording regions without replacing their text labels. The 81-row manual
Gate remains OPEN; Sprint 16B acceptance remains suspended.
