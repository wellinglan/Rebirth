# 01_PRD.md

## Current Appendix: AI Report Generation Pipeline

The product promise for AI generation is still explicit and user-triggered:
the user reviews local preview data, grants consent, confirms the request, and
then receives a local AI Report. Sprint 15B improves the reliability boundary by
making Daily and Weekly generation share one coordinator rather than separate
controller decisions.

The user-visible behavior should remain conservative:

- duplicate taps must not create duplicate Provider calls;
- uncertain network outcomes remain pending and recoverable;
- recovery checks status only and does not regenerate;
- account, endpoint, and consent changes never silently write content into the
  wrong local space;
- completed local reports may be reused only when the report identity and
  endpoint identity match.

This is not AI Chat, automatic coaching, report editing, Provider selection, or
background generation. The manual product Gate remains open until
`docs/manual_tests/56_ai_report_generation_pipeline.md` is executed.

> Classification: **Partially current product foundation**
> The Sprint 0 / v0.1.0 metadata below is historical. Product mission and
> principles remain active, while implemented scope, versions, verification,
> deployment certainty, and release blockers are authoritative in
> `docs/CURRENT_BASELINE.md`.

# Rebirth 产品需求文档（PRD）

> 文档版本：v1.0  
> 项目版本：Rebirth v0.1.0-alpha  
> 文档状态：Draft  
> 最后更新：2026-07  
> 适用阶段：Sprint 0 / MVP 设计阶段  

---

## 1. 文档目的

本文档用于定义 Rebirth v1.0 的产品目标、用户场景、核心功能、功能边界、数据需求与阶段路线图。

本 PRD 是 Rebirth 项目的产品基线。后续任何新增功能、重构、UI 调整、数据库变更与 AI 行为设计，都应先回到本文档进行评估。

如果本文档与临时想法冲突，优先遵循本文档。

---

## 2. 项目概述

### 2.1 项目名称

**Rebirth**

### 2.2 一句话定位

**Rebirth 是一个由 AI 驱动的个人成长操作系统。**

它不是传统意义上的 Todo、打卡、日记或时间管理软件，而是一个帮助用户长期记录、理解、调整并重建自我的成长系统。

### 2.3 产品使命

> Rebirth 的使命，是帮助用户持续成为比昨天更好的自己。

这里的“更好”不只指效率提升，也包括：

- 更稳定的情绪；
- 更健康的作息；
- 更持续的学习；
- 更清晰的长期目标；
- 更理性的自我理解；
- 更有韧性的生活结构。

### 2.4 产品愿景

未来的 Rebirth 应成为用户的个人成长中枢。它不仅知道用户今天做了什么，更能理解：

- 用户为什么效率下降；
- 用户在哪些场景下容易情绪波动；
- 睡眠、运动、科研、学习之间如何互相影响；
- 用户的长期目标是否正在被日常行为支持；
- 用户在数月甚至数年尺度上发生了什么变化。

最终，Rebirth 应形成一个真正理解用户的 AI Coach。

---

## 3. 产品哲学

### 3.1 成长高于完成

Rebirth 不以“完成更多任务”为最终目标。  
任务完成只是成长的一部分，不是产品的全部。

如果用户今天没有完成计划，AI 不应简单判定“失败”，而应分析原因、识别模式、提出调整建议。

### 3.2 记录应该足够轻

每日记录的理想耗时应控制在 **5 分钟以内**。

如果某个页面让用户感到记录负担过重，应优先优化输入方式，而不是要求用户更努力地记录。

### 3.3 AI 是教练，不是裁判

AI 的角色是：

- 观察者；
- 分析者；
- 陪伴者；
- 教练。

AI 不应成为：

- 监工；
- 老师；
- 父母；
- 老板；
- 考官。

AI 不能通过羞耻、压力、批评或命令驱动用户。

### 3.4 数据必须产生意义

Rebirth 不为了统计而统计。

每一项数据都应该能够参与后续分析，例如：

- 睡眠是否影响科研效率；
- 运动是否影响情绪稳定；
- 情绪波动是否影响学习持续性；
- 计划完成度是否受到作息影响；
- 长期目标是否被日常行动支持。

### 3.5 长期理解用户

Rebirth 关注的不是“今天完成了多少”，而是“用户正在变成什么样”。

产品设计必须支持长期趋势分析，而不是只关注单日打卡。

---

## 4. 目标用户

### 4.1 核心用户

Rebirth v1.0 主要面向：

- 本科生；
- 研究生；
- 博士生；
- 科研人员；
- 工程师；
- 长期学习者；
- 正处于人生重建阶段的人。

### 4.2 用户共同特征

这些用户通常具有以下特点：

- 有长期目标，但日常执行容易波动；
- 希望建立稳定生活结构；
- 需要记录学习、科研、运动、情绪和健康；
- 不满足于普通 Todo 软件；
- 希望 AI 能基于长期数据提供反馈；
- 需要一个能陪伴多年而不是几天的新奇工具。

### 4.3 首位用户画像

当前阶段，Rebirth 的首位用户是项目作者本人。

典型特征：

- 博士阶段初期；
- 有科研、学习、运动、情绪重建和长期成长需求；
- 希望构建一个可持续使用多年的个人系统；
- 希望未来让 AI 能够基于长期记录进行深度反馈。

---

## 5. 用户痛点

### 5.1 普通 Todo 软件的问题

Todo 软件通常只能回答：

> 今天还有什么任务没做？

但无法回答：

> 为什么这些任务一直做不完？  
> 我的执行问题来自目标过多、睡眠不足、情绪波动，还是计划不合理？

### 5.2 普通打卡软件的问题

打卡软件容易制造“连续天数崇拜”。

它关注的是：

- 连续打卡多少天；
- 今天有没有断签；
- 是否完成每日目标。

但它很少关注：

- 用户是否真的成长；
- 用户为什么中断；
- 用户是否需要调整节奏；
- 用户是否因为打卡产生焦虑。

### 5.3 普通日记软件的问题

日记软件可以帮助表达，但通常缺少结构化分析能力。

用户写下了大量内容，但系统无法自动识别：

- 情绪趋势；
- 关键词变化；
- 长期困扰；
- 行为模式；
- 成长节点。

### 5.4 普通健康软件的问题

健康软件通常只记录单项指标，例如：

- 步数；
- 睡眠；
- 心率；
- 体重。

但这些数据很少与学习、科研、情绪和长期目标建立联系。

### 5.5 Rebirth 要解决的问题

Rebirth 要解决的是：

> 用户拥有很多局部工具，却没有一个真正理解自己的整体系统。

---

## 6. 产品范围

### 6.1 V1.0 核心模块

Rebirth v1.0 只包含以下六个核心模块：

1. Today
2. Journal
3. Plan
4. Growth
5. Health
6. AI Coach

任何新增模块都必须评估是否服务于“个人成长操作系统”的核心定位。

### 6.2 明确不做

V1.0 明确不做：

- 社交；
- 好友；
- 排行榜；
- 社区；
- 广告；
- 勋章；
- 积分；
- 连续打卡奖励；
- 即时聊天；
- 消息流；
- 游戏化任务系统。

Rebirth 是个人成长系统，不是社交产品，也不是成瘾型产品。

---

## 7. 核心用户流程

### 7.1 每日使用流程

用户每天打开 Rebirth 后：

1. 查看 Today 页面；
2. 明确今日最重要的三件事；
3. 快速记录今日状态；
4. 晚上完成 Journal；
5. AI 生成 Daily Insight；
6. 用户根据反馈调整明日计划。

### 7.2 每周使用流程

每周结束时：

1. 系统汇总本周数据；
2. AI 生成 Weekly Report；
3. 用户查看趋势；
4. 用户调整下周计划。

### 7.3 每月使用流程

每月结束时：

1. 系统汇总学习、科研、运动、睡眠、情绪等趋势；
2. AI 生成 Monthly Reflection；
3. 用户回顾长期目标；
4. 用户制定下月重点。

---

## 8. 功能需求

## 8.1 Today 模块

### 8.1.1 模块定位

Today 是 Rebirth 的日常入口，也是用户每天最常使用的页面。

它回答的问题是：

> 今天，我应该如何生活？

### 8.1.2 核心功能

Today 页面应包含：

- 日期；
- 今日三件事；
- 今日心情 Mood；
- 今日精力 Energy；
- 睡眠时长；
- 科研时间；
- 学习时间；
- 运动记录；
- 今日一句话；
- 今日完成状态；
- 进入复盘入口。

### 8.1.3 输入原则

Today 的记录必须轻量。

不得要求用户输入过长文本。

### 8.1.4 V1.0 验收标准

- 用户可以创建当天记录；
- 用户可以编辑当天记录；
- 用户可以查看历史 Today 记录；
- 数据能够保存到本地 SQLite；
- 页面可在 Windows 与 Android 上正常显示。

---

## 8.2 Journal 模块

### 8.2.1 模块定位

Journal 是每日复盘模块。

它不是自由作文工具，而是结构化自我观察工具。

### 8.2.2 默认问题

V1.0 默认包含以下问题：

1. 今天最重要的完成是什么？
2. 今天最消耗我的事情是什么？
3. 今天的情绪主要来自哪里？
4. 今天我学到了什么？
5. 明天最应该调整的一件事是什么？

### 8.2.3 输入限制

每个问题默认建议不超过 200 字。

目的不是限制表达，而是降低压力，鼓励持续使用。

### 8.2.4 V1.0 验收标准

- 用户可以创建每日 Journal；
- 用户可以编辑和查看历史 Journal；
- Journal 可与 Today 记录按日期关联；
- 后续 AI Coach 可读取 Journal 生成分析。

---

## 8.3 Plan 模块

### 8.3.1 模块定位

Plan 是长期目标管理模块。

它回答的问题是：

> 我的日常行动是否服务于长期目标？

### 8.3.2 层级结构

Plan 支持以下层级：

- 人生目标；
- 年度目标；
- 季度目标；
- 月目标；
- 周目标；
- 日目标。

### 8.3.3 V1.0 范围

V1.0 只实现基础树状目标管理：

- 创建目标；
- 编辑目标；
- 删除目标；
- 标记状态；
- 设置目标层级；
- 关联 Today。

### 8.3.4 暂不实现

V1.0 暂不实现复杂项目管理功能，例如：

- 甘特图；
- 多人协作；
- 高级依赖关系；
- 复杂提醒规则。

---

## 8.4 Growth 模块

### 8.4.1 模块定位

Growth 是趋势分析模块。

它回答的问题是：

> 我是否真的在成长？

### 8.4.2 核心指标

V1.0 展示以下趋势：

- 科研时间；
- 学习时间；
- 运动时间；
- 睡眠时长；
- 心情变化；
- 精力变化；
- Journal 连续记录情况。

### 8.4.3 展示方式

采用简洁图表：

- 折线图；
- 柱状图；
- 周/月汇总卡片。

图表必须服务于理解，不追求复杂装饰。

### 8.4.4 V1.0 验收标准

- 用户可以查看最近 7 天趋势；
- 用户可以查看最近 30 天趋势；
- 图表数据来自本地数据库；
- 页面不产生明显性能卡顿。

---

## 8.5 Health 模块

### 8.5.1 模块定位

Health 是身体状态记录模块。

它回答的问题是：

> 我的身体状态是否支持我的成长？

### 8.5.2 V1.0 数据项

V1.0 支持：

- 睡眠时长；
- 体重；
- 饮水；
- 运动类型；
- 运动时长；
- 主观身体状态。

### 8.5.3 未来扩展

未来可支持：

- Health Connect；
- Apple Health；
- 心率；
- 步数；
- 血压；
- 血糖；
- 可穿戴设备数据。

---

## 8.6 AI Coach 模块

### 8.6.1 模块定位

AI Coach 是 Rebirth 的核心差异化模块。

它不是普通聊天机器人，而是基于用户长期数据进行分析的个人教练。

### 8.6.2 AI 输出类型

V1.0 支持以下输出：

- Daily Insight；
- Weekly Report；
- Monthly Reflection；
- 明日建议；
- 趋势解释。

### 8.6.3 AI 语气要求

AI 应：

- 温和；
- 克制；
- 具体；
- 不说教；
- 不制造焦虑；
- 不使用命令式表达。

### 8.6.4 V1.0 实现方式

V1.0 可先预留 AI 接口结构，初期允许手动触发分析。

---

## 9. 页面结构

V1.0 初始页面结构：

```text
Splash
  ↓
Home
  ↓
Bottom Navigation
  ├── Today
  ├── Journal
  ├── Plan
  ├── Growth
  └── Profile
```

Profile 中包含：

- Health；
- Settings；
- AI Coach；
- Export；
- About。

---

## 10. 数据需求

V1.0 需要以下核心数据实体：

- UserProfile
- TodayRecord
- JournalEntry
- Goal
- HealthRecord
- AIReport
- AppSettings

详细字段以 `03_DATABASE.md` 为准。

---

## 11. 非功能需求

### 11.1 离线优先

V1.0 必须支持离线使用。

用户的核心记录数据应保存在本地 SQLite 中。

### 11.2 隐私优先

用户数据默认只存储在本地。

任何云同步或 AI 上传行为，都必须在未来版本中明确告知用户。

### 11.3 性能要求

- App 启动应尽量轻量；
- 常用页面切换应流畅；
- 图表加载不应阻塞 UI；
- 本地数据库查询应避免明显延迟。

### 11.4 可维护性

项目必须保持清晰目录结构和模块边界。

禁止将大量业务逻辑写入单个 Widget 文件。

---

## 12. MVP 验收标准

Rebirth v1.0 的 MVP 成功标准：

1. 用户可以每天记录 Today；
2. 用户可以完成 Journal；
3. 用户可以创建长期目标；
4. 用户可以查看基础趋势；
5. 用户可以记录基础健康数据；
6. 系统可以生成基础 AI 分析；
7. 所有核心数据可持久化；
8. Windows 和 Android 可正常运行。

---

## 13. Roadmap

### v0.1.0-alpha

目标：项目基础框架

- 建立目录结构；
- 接入主题；
- 接入路由；
- 接入 Riverpod；
- 建立基础页面壳。

### v0.2.0-alpha

目标：Today 模块

- Today 页面；
- Today 数据模型；
- Today 本地存储。

### v0.3.0-alpha

目标：Journal 模块

- Journal 页面；
- Journal 数据模型；
- Journal 历史记录。

### v0.4.0-alpha

目标：Plan 模块

- 目标树；
- 目标状态；
- 与 Today 关联。

### v0.5.0-alpha

目标：Growth 模块

- 7 天趋势；
- 30 天趋势；
- 基础图表。

### v0.6.0-alpha

目标：Health 模块

- 健康记录；
- 运动与睡眠统计。

### v0.7.0-alpha

目标：AI Coach 初版

- AI 接口；
- Daily Insight；
- Weekly Report。

### v1.0.0

目标：可长期使用的稳定版本

- 核心闭环完整；
- 体验稳定；
- 数据结构稳定；
- 可作为个人日常工具使用。

---

## 14. 成功指标

Rebirth 不以广告收入、点击率或社交传播作为核心指标。

V1.0 的成功指标是：

1. 用户连续使用 30 天；
2. 用户愿意继续使用 90 天；
3. 用户认为系统“越来越理解自己”；
4. 用户能够从趋势中获得真实反馈；
5. 用户感受到自己的生活结构有所改善。

---

## 15. 项目宣言

Rebirth 不会替用户生活。

Rebirth 不会替用户做决定。

Rebirth 不会定义什么是成功。

它只是记录、理解、陪伴，并在漫长时间里帮助用户重新生长。

> Rebirth 的目标，不是帮助你做更多，而是帮助你成为更多。

---

## 16. Personal Data Overview

Settings 提供“个人数据概览”入口，用于按本地自然日查看当前账号中 Profile、
Plan、Today、Journal 与 Health 的结构化本地摘要。页面支持前一天、后一天、
回到今天和手动刷新。

该页面是本地聚合基础设施的产品验证面，不是 Growth 图表或 AI Insight：

- 不创建或修改业务记录；
- 不自动触发云同步；
- 不调用 AI；
- 不展示 Journal 完整正文或 Health 备注；
- 不把聚合结果持久化；
- signed-out、binding-required 和 rejected session 不可进入；
- authenticated-offline 可使用。

未来个人数据模块通过统一 Provider 注册后自动进入通用页面，无需修改 Engine
或页面级模块 switch。技术边界见
`docs/36_PERSONAL_DATA_AGGREGATION.md`。

---

## 17. Extensible Growth Projection

Growth 通过 Personal Data Aggregation Engine 读取当前账号的结构化本地事实，
并由可扩展 Contributor 生成 Focus、Recovery、Subjective State 与 Reflection
投影。页面保留原始趋势，同时显示覆盖率、质量、敏感度和来源，不把缺失值当作
0，不评价投入好坏，也不进行医疗或心理判断。

Journal 生命周期明确为：

- 未记录：当日不存在 active Journal，仅为派生状态；
- 草稿：用户保存了尚可继续编辑的复盘；
- 已完成：用户明确完成复盘；
- 已完成记录只有在确认“重新编辑”后才回到草稿。

Growth 与 Journal 状态变化均保持本地优先，不自动同步，不调用 AI，不持久化
Growth 派生结果。详细设计见 `docs/37_GROWTH_SYSTEM_FOUNDATION.md`。

## 8.8 Journal 可配置问题

Journal 默认保留原五个复盘问题，同时允许用户新增、编辑、启停、排序和删除
自定义问题。系统问题不可直接改写或删除；用户可通过“自定义”创建自己的副本。
新记录使用当前启用问题，旧记录始终显示保存时的问题快照。草稿可由用户确认后
应用最新问题，已完成记录需先明确重新编辑。

问题配置与动态回答支持现有手动跨端同步和显式冲突恢复，不触发自动同步。
`futureAi` 仅为未来来源预留；任何 AI 问题都必须先由用户查看、接受并启用，
Sprint 12C 不包含真实 AI。详见 `docs/38_JOURNAL_PROMPT_SYSTEM.md`。

# 二十一、Settings 与同步中心体验

普通用户通过 Settings 进入账号、同步中心、个人数据与隐私、Journal 问题和
关于。Alpha 开发账号、Endpoint 和设备诊断只存在于受构建配置控制的开发者
选项，不再与普通设置混排。

同步中心提供 Profile、Plan、Today、Journal、Health 五个手动同步入口和一个
“同步全部”入口。用户无需理解 Push/Pull、cursor、serverVersion 或 Journal
Prompt Configuration。同步全部固定顺序执行并允许模块级失败或冲突后继续；
账号、连接、所有权或设备前置条件失败时停止后续模块。所有失败都保留本地数据，
冲突必须由用户选择版本。

Sprint 12D 不包含生产认证、微信登录、自动同步、AI 或 Growth Sync。生产认证
基础属于 Sprint 13A。

## 22. Authentication Foundation

Sprint 13A.1 establishes the authentication protocol beneath the future public
account experience. It supports username/password identities, secure sessions,
refresh rotation, logout revocation, development-account credential attachment,
and secure client credential persistence.

This is not yet the public login product. Registration/login screens, account
recovery, MFA, WeChat login, automatic synchronization, and session management UI
remain deferred. Existing local-first data and the five manual sync modules retain
their current product semantics.

Sprint 13A.1 manual acceptance recorded 67 PASS, 0 FAIL, and 12 NOT EXECUTED.
Public username/password registration and login, production hiding of development
authentication, and the remaining public authentication gates continue in Sprint
13A.2. Password recovery, MFA, and WeChat authentication remain deferred.

## 23. Public Username/Password Login

Sprint 13A.2 makes public username/password authentication the normal Windows and
Android entry. Signed-out users may log in or register; successful authentication
restores or creates only the CloudUser-bound local space. Devices with unresolved
legacy data continue to the existing ownership review and never assign data
silently.

Production shows no Developer Login, Alpha badge, endpoint, Dev Key, or internal
identifier. Alpha may expose a clearly marked low-priority developer route while
keeping public login primary. Offline use is allowed only for an existing trusted
binding and unexpired session metadata. Rejected or unknown refresh outcomes return
to public login while preserving local data.

This Sprint does not add account recovery, email/SMS verification, MFA, passkeys,
biometrics, WeChat, session management, account deletion, or automatic sync.
User acceptance on 2026-07-30 recorded 107 PASS, 0 FAIL, and 7 NOT EXECUTED.
H1-H7 remain NOT EXECUTED because no safe unbound-legacy-data fixture was
available. The public login, authentication protocol, password credential
security, and secure client storage gates are accepted; see
`docs/manual_tests/41_public_username_password_login.md`.

## 24. Full Personal Data Export and Backup Foundation

Settings 的“个人数据与隐私”区域提供“导出全部个人数据”。用户必须先看到导出
范围、明文敏感数据和当前不能恢复的说明，再显式确认并通过 Windows 或 Android
系统保存界面选择位置。

首版导出当前登录账号的 Profile、Plan 层级、Today、Journal 动态问题快照与历史
兼容事实、Journal Prompt Configuration、Health 敏感字段和备注，以及 AI Report
当前聚合、生命周期、正文和不可变版本历史。文件使用版本化 UTF-8 JSON、模块
manifest、记录计数和可重复校验的 SHA-256。Growth 和 Personal Data Aggregation
由源事实重算，不作为独立记录复制。

导出不能包含密码、Token、Secure Storage、Cloud/Auth/Device 标识、Endpoint、
Provider 请求或 Prompt、AI Ledger、sync/cursor/conflict/remote snapshot、内部路径或
日志。导出不修改任何业务或同步状态，不联网、不生成 AI、不启动同步。账号切换、
退出或 SessionRejected 必须在系统保存界面打开前停止操作。

Sprint 15A 只提供明文导出与未来恢复格式基础，不提供 Import、Restore、Merge、
加密、自动备份或云备份。完整合同见
`docs/50_FULL_PERSONAL_DATA_EXPORT_AND_BACKUP.md`。

## 25. Prompt Governance and Quality Evaluation

Daily Insight 与 Weekly Report 的系统 Prompt 必须由 Server 唯一 Registry 管理。
用户不能查看、编辑、选择或激活系统 Prompt；Flutter 只消费 Capabilities 中公开的
active 合同。Prompt 内容变化必须创建新版本，candidate 在离线质量 Gate、可选的
真实 Provider 评估和人工评审完成前不能成为 active。

质量 Gate 分开报告 Contract、Grounding、Safety、Coach Quality 与 Operational，
严重事实虚构、安全失败、注入服从或系统 Prompt 泄漏不能由平均分抵消。普通 CI
只使用仓库内合成输入和人工编写的合成输出，不调用 Provider、不产生费用，也不把
Fake Provider 结果描述为真实模型质量。完整合同见
`docs/52_PROMPT_GOVERNANCE_AND_QUALITY_EVALUATION.md`。

## 26. AI Coach MVP Product Experience

AI Coach 必须是 Windows 与 Android 的稳定一级入口，而不是只能从 Settings 发现。
首页至少提供今日洞察、每周回顾、最近报告和 AI 可用/额度状态。用户应从自然任务
进入数据选择、查看“本次使用的数据”、最终确认、受控生成与 canonical 报告详情。

普通流程不得要求理解 Prompt Version、Input Hash、Request Binding、Payload 或
Gateway。已有报告优先查看和复用；复用不能增加调用、额度、报告或版本。未授权、无
数据、服务关闭、额度耗尽、网络不确定和处理中必须各有诚实且可操作的状态。Sprint
16A 不增加 AI 能力、报告类型、自动生成或自动同步。完整要求见
`docs/53_AI_COACH_MVP_PRODUCT_EXPERIENCE.md`。
