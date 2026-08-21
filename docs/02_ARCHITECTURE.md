# 02_ARCHITECTURE.md

> Classification: **Partially current architecture foundation**
> The Sprint 0 metadata and future-server passages below are historical.
> Current architecture, versions, module registration, and deployment
> certainty are authoritative in `docs/CURRENT_BASELINE.md`.

# Rebirth 软件架构设计文档

> 文档版本：v1.0  
> 项目版本：Rebirth v0.1.0-alpha  
> 文档状态：Draft  
> 最后更新：2026-07  
> 适用阶段：Sprint 0 / 架构设计阶段  

---

## 1. 文档目的

本文档定义 Rebirth v1.0 的软件架构、技术栈、目录结构、模块边界、数据流、状态管理方案、路由方案、数据库接入方式和未来扩展原则。

本文档服务于三个目标：

1. 保证项目从第一天开始具备长期维护能力；
2. 让 Codex、ChatGPT 或其他 AI Agent 能够理解项目架构；
3. 避免随着功能增加导致代码失控。

---

## 2. 架构目标

Rebirth 是一个长期项目，而不是一次性 Demo。

因此架构设计优先级如下：

1. 可维护性；
2. 可扩展性；
3. 可测试性；
4. 跨平台能力；
5. 开发效率；
6. 性能优化。

性能重要，但不是 v1.0 的第一优先级。  
v1.0 的第一优先级是建立清晰、稳定、可持续演进的项目骨架。

---

## 3. 技术栈

### 3.1 前端框架

- Flutter
- Dart
- Material 3

选择原因：

- 支持 Windows、Android、iOS、Web 多平台；
- UI 迭代速度快；
- 适合个人长期产品；
- 可在 Windows 上高效开发与调试。

### 3.2 状态管理

- Riverpod

选择原因：

- 类型安全；
- 易测试；
- 适合中大型 Flutter 项目；
- 不依赖 BuildContext；
- 与 Feature First 架构适配良好。

### 3.3 路由

- GoRouter

选择原因：

- 官方推荐方向明确；
- 支持声明式路由；
- 支持嵌套路由；
- 未来可支持深链接与 Web。

### 3.4 本地数据库

- SQLite
- Drift ORM

选择原因：

- 离线优先；
- 类型安全；
- 支持复杂查询；
- 适合长期数据积累；
- 未来可平滑扩展同步逻辑。

### 3.5 网络请求

- Dio

选择原因：

- 拦截器机制成熟；
- 适合接入 AI API；
- 支持统一错误处理；
- 当前 Dio 已接入 FastAPI 后端；早期“后续接入”描述已被实现取代。

### 3.6 图表

- fl_chart

选择原因：

- Flutter 生态成熟；
- 支持折线图、柱状图等基础统计图；
- 足够满足 Growth v1.0 的需求。

---

## 4. 总体架构

Rebirth 采用：

> Feature First + Clean Architecture Lite

即按功能模块组织代码，同时保持 UI、业务逻辑、数据访问之间的边界。

整体结构：

```text
lib/
  main.dart

  core/
    app/
    router/
    theme/
    database/
    network/
    constants/
    utils/
    widgets/

  features/
    today/
    journal/
    plan/
    growth/
    health/
    ai_coach/
    settings/
    profile/

  shared/
    models/
    widgets/
    extensions/
```

---

## 5. 分层设计

每个 Feature 内部建议采用如下结构：

```text
features/
  today/
    data/
      today_local_data_source.dart
      today_repository_impl.dart

    domain/
      today_entity.dart
      today_repository.dart
      usecases/

    presentation/
      today_page.dart
      today_controller.dart
      widgets/
```

为了避免 v1.0 过度工程化，可根据模块复杂度适当简化。

### 5.1 Presentation Layer

负责：

- 页面；
- Widget；
- 用户交互；
- 状态展示；
- 表单输入。

不负责：

- 数据库操作；
- 网络请求；
- 复杂业务逻辑。

### 5.2 Domain Layer

负责：

- 实体定义；
- 业务规则；
- Repository 接口；
- UseCase。

简单模块可暂时省略 UseCase，但必须保留业务边界意识。

### 5.3 Data Layer

负责：

- Drift 数据库读写；
- API 请求；
- DTO 与 Entity 转换；
- Repository 实现。

---

## 6. 推荐目录结构

Sprint 1 阶段建议采用以下目录：

```text
lib/
  main.dart

  core/
    app/
      rebirth_app.dart

    router/
      app_router.dart
      route_names.dart

    theme/
      app_theme.dart
      app_colors.dart
      app_text_styles.dart

    database/
      app_database.dart
      tables/
      daos/

    network/
      dio_client.dart
      api_result.dart

    constants/
      app_constants.dart

    utils/
      date_utils.dart

    widgets/
      app_scaffold.dart
      section_card.dart

  features/
    today/
      data/
      domain/
      presentation/
        today_page.dart
        today_controller.dart
        widgets/

    journal/
      data/
      domain/
      presentation/

    plan/
      data/
      domain/
      presentation/

    growth/
      data/
      domain/
      presentation/

    health/
      data/
      domain/
      presentation/

    ai_coach/
      data/
      domain/
      presentation/

    settings/
      presentation/

    profile/
      presentation/

  shared/
    widgets/
    models/
    extensions/
```

---

## 7. 路由设计

### 7.1 顶层路由

```text
/
  SplashPage

/home
  HomeShell

/today
/journal
/plan
/growth
/profile
/settings
```

### 7.2 Responsive Primary Navigation

当前 HomeShell 管理六个一级入口：

1. Today
2. Journal
3. Plan
4. Health
5. Growth
6. AI Coach

紧凑宽度使用 Bottom Navigation；840px 起使用紧凑 NavigationRail；1200px
起在普通字号下使用带 `Rebirth` 品牌信号的展开 NavigationRail。Settings 是全局
AppBar 操作，不占用一级目的地。响应式切换不改变 GoRouter branch、业务状态或
数据加载行为。早期将 Health/AI Coach 放入 Profile 的设想已经失效。

### 7.3 路由原则

- 路由名称统一管理；
- 不在页面中硬编码路径；
- 页面跳转通过 GoRouter；
- 未来支持深链接时，不破坏现有结构。

---

## 8. 状态管理设计

### 8.1 Riverpod 使用原则

使用 Riverpod 管理：

- 页面状态；
- 数据加载状态；
- Repository 注入；
- Controller 注入；
- AppSettings 状态。

### 8.2 Provider 类型建议

| 场景 | 推荐 |
|---|---|
| 简单只读依赖 | Provider |
| 异步数据 | FutureProvider |
| 页面状态 | Notifier / AsyncNotifier |
| 数据库实例 | Provider |
| Repository | Provider |
| 表单状态 | Notifier |

### 8.3 状态模型

页面状态应显式表达：

- loading；
- data；
- empty；
- error。

不应通过多个 bool 隐式组合复杂状态。

---

## 9. 数据库架构

### 9.1 数据库原则

Rebirth v1.0 采用本地优先架构。

所有核心数据默认存储在本地 SQLite。

数据库访问统一通过 Drift DAO，不允许页面直接操作数据库。

### 9.2 核心表

V1.0 初始包括：

- user_profiles
- today_records
- journal_entries
- goals
- health_records
- ai_reports
- app_settings

详细字段见 `03_DATABASE.md`。

### 9.3 数据流

典型读取流程：

```text
Page
  ↓
Controller / Notifier
  ↓
Repository Interface
  ↓
Repository Implementation
  ↓
DAO
  ↓
SQLite
```

典型写入流程：

```text
User Input
  ↓
Form State
  ↓
Controller Validation
  ↓
Repository
  ↓
DAO
  ↓
SQLite
  ↓
UI Refresh
```

---

## 10. AI Coach 架构

### 10.1 设计原则

AI Coach 不直接嵌入 UI 逻辑。

AI 相关能力应抽象为独立服务：

```text
features/
  ai_coach/
    data/
      ai_coach_input_assembler_impl.dart
      canonical_json_encoder_impl.dart
      sha256_input_hash_service.dart
      local_ai_consent_repository.dart
      local_ai_report_repository.dart

    domain/
      ai_data_selection.dart
      ai_coach_input_bundle.dart
      ai_report.dart
      ai_report_repository.dart
```

Sprint 8A 不包含 AI API Client 或 AI Coach 页面。Settings 的授权入口通过 Controller 调用
`AiConsentRepository`，Widget 不访问 Drift。未来 Provider 必须消费
`AiCoachInputBundle`，不得直接读取或发送数据库行。

### 10.2 AI 输入

AI 分析输入来自本地结构化数据，例如：

- TodayRecord；
- JournalEntry；
- HealthRecord；
- Goal；
- GrowthSummary。

全局 Consent 与单次 `AiDataSelection` 相互独立。Consent 默认关闭；启用后也不会自动选择数据、
发送网络请求或生成报告。Weekly Report 输入只能由 Input Assembler 按显式 scope 最小化构建，
并在完整输入形成后生成 Canonical JSON 与 SHA-256 hash。

### 10.3 AI 输出

AI 输出应保存为 AIReport，而不是只显示一次。

原因：

- 便于回顾；
- 便于长期分析；
- 便于未来训练用户画像；
- 便于避免重复生成。

AIReport 与 Today、Journal、Health、Goal 和 Growth 原始事实分离。报告生命周期只能更新
`ai_reports`，AI 输出不得覆盖用户事实。Sprint 8A 只建立本地 pending、completed、failed
生命周期，不生成真实或模板伪造内容，也不进行云同步。

Sprint 14B 在同一聚合上新增 `ai_report_versions`。`ai_reports` 保存标题、当前状态和
最新版本投影，版本表保存不可变的终态正文或受控失败。Report 页面通过 Controller 和
Repository 只读访问；Widget 不接触 Drift。Growth、Personal Data Aggregation、Journal
和 Sync 均不依赖 Report。未来生成实现只能通过 `AiReportGenerationService` 边界追加
版本，不能覆盖历史版本。

Sprint 14C 将 Report 聚合及其不可变版本作为一个手动 Sync Protocol 2 实体接入现有
SyncCoordinator；版本不是独立同步实体。Sprint 14F 在统一报告库上增加只读导出：
Widget 通过 `AiReportExportController` 调用 `AiReportExportService`，服务将 Domain
对象映射为不含数据库与同步字段的 Export DTO，再交给平台文件 Adapter。导出前后都
必须保持报告、版本、同步状态和冲突状态不变；账号或会话在保存前变化时必须停止。

### 10.4 Prompt 管理

Prompt 不应散落在代码中。

未来应放入：

```text
assets/prompts/
```

或：

```text
docs/08_PROMPT_GUIDE.md
```

并在代码中集中管理。

---

## 11. UI 架构

### 11.1 设计语言

Rebirth UI 应遵循：

- 简洁；
- 克制；
- 平静；
- 低压；
- 高可读性。

界面不应制造紧张感。

### 11.2 组件化

常用组件应抽象到：

```text
core/widgets/
shared/widgets/
```

例如：

- SectionCard；
- MetricCard；
- EmptyState；
- AppScaffold；
- PrimaryButton；
- RebirthTextField。

### 11.3 页面原则

页面文件不应过长。

如果单个页面超过约 300 行，应考虑拆分 Widget。

---

## 12. 错误处理

### 12.1 本地错误

数据库错误、表单错误、数据缺失应统一处理。

页面不应直接显示底层异常。

### 12.2 网络错误

未来 AI API 失败时，应提供：

- 失败原因；
- 重试按钮；
- 不丢失本地输入；
- 不阻塞其他功能。

### 12.3 错误展示原则

错误提示应清晰、克制，不制造压力。

例如：

推荐：

> 暂时无法生成 AI 分析，请稍后重试。

不推荐：

> 请求失败！错误码 500！

---

## 13. 跨平台策略

### 13.1 v1.0 目标平台

优先支持：

- Windows
- Android

开发阶段优先 Windows。

移动端适配优先 Android。

### 13.2 响应式布局

UI 不应只为手机设计。

需要考虑：

- Windows 宽屏；
- Android 竖屏；
- 平板横屏可能性。

### 13.3 平台差异

平台相关代码必须隔离。

不得在业务逻辑中直接写平台判断。

---

## 14. 配置管理

### 14.1 App 常量

全局常量放入：

```text
core/constants/
```

### 14.2 环境配置

未来区分：

- dev；
- staging；
- production。

v1.0 初期可先不实现复杂环境系统，但应预留空间。

### 14.3 密钥管理

API Key 不得直接提交到 GitHub。

未来使用：

- `.env`
- 本地配置文件；
- 平台安全存储；
- 后端代理。

---

## 15. 测试策略

### 15.1 v1.0 测试重点

优先测试：

- 数据库写入；
- 数据库读取；
- Repository；
- Controller；
- 关键页面渲染。

### 15.2 测试类型

包括：

- Unit Test；
- Widget Test；
- Integration Test。

Sprint 初期可以先建立基础测试目录，逐步补充。

### 15.3 测试原则

任何与数据安全相关的逻辑都应优先测试。

例如：

- 删除记录；
- 更新记录；
- 日期查询；
- AIReport 保存。

---

## 16. Git 与版本策略

### 16.1 分支策略

当前只有一名开发者，初期使用：

```text
main
```

即可。

后续可增加：

```text
develop
feature/today
feature/journal
feature/ai-coach
```

### 16.2 Commit 规范

使用 Conventional Commits：

```text
feat: add today module
fix: repair database query
docs: update architecture
refactor: simplify repository layer
style: improve home layout
test: add today repository tests
```

### 16.3 版本号

采用语义化版本：

```text
v0.1.0-alpha
v0.2.0-alpha
v0.9.0-beta
v1.0.0
```

---

## 17. Codex 协作规范

Codex 或其他 AI Agent 在修改代码前必须阅读：

1. `docs/00_AI_CONTEXT.md`
2. `docs/01_PRD.md`
3. `docs/02_ARCHITECTURE.md`

开发时应遵循：

- 不破坏既有架构；
- 不跳过文档约定；
- 不引入无必要依赖；
- 不将业务逻辑写入 UI；
- 每次修改保持项目可运行。

---

## 18. 架构演进原则

Rebirth 的架构不是一次性完成的。

它应随着功能增加逐步演进。

但每次演进必须满足：

1. 解决真实复杂度；
2. 不为假想需求过度设计；
3. 不牺牲可读性；
4. 不破坏已有数据；
5. 有清晰迁移路径。

---

## 19. 当前 Sprint 架构目标

Sprint 0 / Sprint 1 的架构目标：

- 建立 docs；
- 建立基础目录；
- 接入 Riverpod；
- 接入 GoRouter；
- 建立主题系统；
- 建立 HomeShell；
- 预留数据库目录；
- 预留 Feature 结构；
- 保持 App 可运行。

暂不实现复杂业务逻辑。

---

## 20. 总结

Rebirth 的架构目标不是炫技，而是长期稳定。

本项目不追求一开始就完美，但必须从第一天开始保持方向正确。

> 架构的意义，不是让代码看起来复杂，而是让五年后的维护仍然清晰。

---

## 21. Sync Module Application Layer

Settings presentation no longer coordinates entity synchronization directly.
The application layer defines stable `SyncModuleId` values, immutable module
descriptors, a registry, runners, unified module results, and a sequential
Sync All orchestrator.

The product order is explicitly Profile, Plan, Today, Journal, Health and is
independent of entity enum order. Journal maps prompt configuration and entry
entities into one module. Runners reuse existing feature controllers and the
global single-flight `SyncCoordinator`; they do not duplicate API, OCC,
cursor, transaction, or account-scope logic.

`SyncCenterController` owns transient current-session state. Canonical pending
metadata, cursors, conflict rows, server versions, and per-record sync metadata
remain in existing storage. No module history table or restart queue exists.
See `docs/39_SETTINGS_INFORMATION_ARCHITECTURE_AND_SYNC_CENTER.md`.

## 22. Authentication Session Layer

Authentication is split across Server identity/credential/session services and a
Flutter `AuthSessionManager`. `CloudUser` owns data; `AuthIdentity` identifies a
login provider; `AuthCredential` stores Argon2id material; `AuthSession` and
`AuthRefreshToken` hold durable revocation and rotation state.

Flutter feature gateways never read persisted tokens directly. They request a
runtime access token through the manager, which owns secure-store recovery,
single-flight refresh, one-time authorized retry, endpoint binding, logout, and
definitive session rejection. The access token is memory-only. Sync adapters and
repositories remain unchanged below this authentication boundary.

See `docs/40_AUTHENTICATION_PROTOCOL_AND_SECURE_SESSION.md`.

## 23. Public Authentication Composition

`AppConfig.fromEnvironment()` is the normal composition root for production,
alpha, and development builds. Production requires a compile-time Server
endpoint and overrides every Dev Login request to false. Tests inject
`AppConfig.test()` and fake stores/services without platform environment or
network access.

The presentation/application flow is:

```text
PublicLoginPage / PublicRegisterPage
  -> AppAuthController
  -> PasswordAuthService
  -> AuthSessionManager
  -> ApiClient
```

Presentation owns only ephemeral field controllers. Application state contains
no password or token. `AuthSessionManager` retains exclusive ownership of
runtime access credentials and secure refresh persistence. After login or
registration, `AppAuthController` invokes the existing Account Boundary and
the shared account-scoped provider invalidator.

GoRouter treats login, registration, optional developer login, and bootstrap as
public. Every business, Settings, Sync, Conflict, Profile, Journal Prompt, and
Personal Data route remains protected. Production does not register developer
routes. Session rejection and unknown refresh results deactivate the active
scope and resolve to public login without rendering the old business shell.

No database or Server architecture changed. See
`docs/41_PUBLIC_USERNAME_PASSWORD_LOGIN.md`.

## 24. Full Personal Data Export Pipeline

Sprint 15A adds one local, read-only pipeline:

```text
FullPersonalDataExportPage
  -> FullPersonalDataExportController
  -> FullPersonalDataExportService
  -> immutable PersonalDataExportModuleRegistry
  -> typed account-scoped module exporters
  -> portable backup DTOs
  -> deterministic JSON encoder and SHA-256 verifier
  -> shared FileExportAdapter
  -> native Windows / Android save dialog
```

The Widget owns disclosure, confirmation, progress, and feedback only. It does
not access Drift, serialize JSON, or write files. Each typed exporter reads
through an audited account-scoped repository. All module reads occur inside one
Drift transaction; one module failure closes the whole operation. The service
checks that the authenticated local account is unchanged before, during, and
after assembly and immediately before the native picker.

Portable DTOs carry only stable business facts and relationships. They do not
reuse database rows, API models, or Sync Protocol payloads. Recursive object-key
ordering and stable record order produce canonical `data`; SHA-256 is verified
before the shared Sprint 14F file adapter receives UTF-8 bytes.

The pipeline has no API client, AI generation, token refresh, endpoint probe,
SyncCoordinator, or database mutation dependency. Growth and Personal Data
Aggregation remain recomputable projections. There is no import/restore,
encryption, scheduling, cloud backup, or second platform file stack. See
`docs/50_FULL_PERSONAL_DATA_EXPORT_AND_BACKUP.md`.

## 25. AI Report Generation Coordinator

Sprint 15B consolidates manual Daily and Weekly AI Report generation behind one
application-layer coordinator:

```text
Presentation controller
  -> preview integrity check
  -> AiReportGenerationCoordinator
  -> consent, auth session, reusable lookup, pending report, binding
  -> AiGenerationGateway
  -> terminal local report reconciliation or status-only recovery
```

Controllers no longer decide Provider retry, binding persistence, terminal
repository writes, or recovery strategy. Pending recovery uses the same
coordinator and only calls the request-status endpoint; it never resubmits a
generation POST.

The coordinator is account-, endpoint-, report-type-, period-, prompt-version-,
input-hash-, and scope-aware. It single-flights duplicate in-process requests,
requires endpoint-scoped reuse for new completed reports, and leaves uncertain
network outcomes pending rather than inventing a result. It does not change
Provider, Prompt, Server API, Sync Protocol, or automatic sync behavior. See
`docs/51_AI_REPORT_GENERATION_PIPELINE.md`.

## 26. Prompt Governance and Evaluation Architecture

Sprint 15C keeps runtime and evaluation behind one Server Registry:

```text
PromptRegistry
  -> explicit active Prompt -> AiGenerationService -> existing Provider/Ledgers
  -> all metadata/fingerprints -> read-only maintenance CLI
  -> synthetic fixtures -> Contract/Grounding/Safety/Coach/Operational Gates
```

Capabilities reads active definitions only. Generation resolves only the
explicit active pointer; Ledger replay may resolve any registered historical
version. Candidate versions are inaccessible to product generation until a
reviewed code change updates activation and compatible public contracts.

Level 1 and 2 are pure, database-free, network-free evaluation paths. Level 3
is a separate explicit exception that uses an existing evaluation CloudUser,
the real Provider adapter, Generation Ledger, Usage Ledger, quota, concurrency,
case/token bounds, and cost cap. It creates no local AI Report and never runs in
normal CI. See `docs/52_PROMPT_GOVERNANCE_AND_QUALITY_EVALUATION.md`.

## 27. AI Coach Product Composition

Sprint 16A adds no second AI application layer. The canonical composition is:

```text
HomeShell / AI Coach route
  -> consent + usage + recent-report presentation controllers
  -> Daily/Weekly preview controller families
  -> AiReportGenerationCoordinator
  -> canonical AiReportRepository / recovery / library / detail
```

The home reads status only. Generate remains behind explicit selection,
preview-integrity verification, confirmation, and the existing coordinator.
Account-scope invalidation includes consent, usage, preview families, manual
generation families, pending recovery, coordinator, and report history. The
navigation/routing change does not alter Drift schema, Server runtime, API,
Sync Protocol, Provider, Prompt activation, quota, or ledger architecture.

## 28. AI Report Feedback Aggregate

Sprint 16B keeps mutable quality observation separate from immutable report
history:

```text
Report/Version Detail
  -> AiReportFeedbackController
  -> AiReportFeedbackRepository
  -> local ai_report_feedback (schema 12)
  -> explicit AI Report manual sync, after report transport
  -> dedicated authenticated feedback API
  -> server ai_report_feedback (Alembic 20260812_0008)
```

The client writes locally first and never calls the Server from a Widget. The
Server derives account scope from JWT and verifies the referenced synced report
and completed version. Exact writes are idempotent; stale writes become an
explicit whole-aggregate OCC conflict. Feedback has independent pending,
remote-version, snapshot, and tombstone metadata and is not a new
`SyncEntityType`, so Sync Protocol remains 2.

The aggregate stores only helpfulness, allowlisted reasons, governed Prompt
identity, version identity, and lifecycle/sync metadata. It stores no report or
source body, Prompt text, input snapshot/hash, Provider response, token, or free
text. The read-only audit CLI aggregates these signals for human review and has
no path to Prompt activation or generation behavior. See
`docs/54_AI_COACH_FEEDBACK_AND_QUALITY_SIGNAL.md`.

## 29. Developer Experience Prototype Boundary

Sprint 17A.1 adds one route only when `AppConfig.enableDevLogin` is true:

```text
DeveloperOptionsPage
  -> ExperiencePreviewPage (ephemeral state)
  -> Home / Today / Health prototype widgets
  -> QuickIncrementControl + WaterCupIndicator + WellbeingRatingField
```

The nested route shares the existing Production developer-route denial. The
prototype reads time only through `DateTimeService`, uses local deterministic
quotes and bundled WebP assets, and keeps mutations in Widget state. It has no
Repository, Drift, network, AI, or sync dependency. Production HomeShell still
contains exactly six feature branches; `/home` behavior and all production
Today/Health application flows remain unchanged.

Prototype Revision 1 keeps Mood, Energy, and body-feeling scores plus their
optional descriptions in `ExperiencePreviewPage` Widget state. The reusable
rating field accepts `int?` from 1 through 10, uses native Slider focus and
Semantics with custom track/thumb painting, and emits callbacks only to that
ephemeral state. Compact and large-text layouts stack fields; ordinary wide
layouts may use two columns. No adapter maps these prototype values to the
production 1-5 domain, and no Repository, migration, API, or sync boundary is
added.

## 30. Production Home / Today / Health Integration

Sprint 17B promotes the accepted components without creating a second data or
sync path:

```text
authenticated /home
  -> homeOverviewProvider
  -> TodayRepository + HealthRepository (read only)
  -> account-scoped Drift facts

TodayForm / HealthForm
  -> existing controllers and repositories
  -> shared WellbeingRatingField / QuickIncrementControl
  -> existing SyncCoordinator adapters
```

Home has no direct Drift or implementation import and never creates an empty
record. It watches authenticated scope and the shared Today/Health revision so
saved data is re-read. Partial repository failure remains local to the missing
summary. Time and the stable local quote are derived through `DateTimeService`.

The data layer owns legacy scale normalization. Domain, presentation, Growth,
AI input, Personal Data, export, and conflict presentation see only normalized
1-10 values. Sync codecs accept an exact legacy key set (implicit scale 5) or
the current expanded key set (explicit scale plus descriptions). The existing
SyncCoordinator, OCC, cursor, tombstone, and conflict resolution paths remain
authoritative. Server request validation mirrors those two exact payload
shapes and keeps submitted JSON unchanged; this is validation at the existing
transport boundary, not a second sync path. API Version 1 and Sync Protocol 2
are unchanged.

## 31. Core Experience Consolidation and Metric Narratives

Sprint 17C-E continues to use the existing feature-first layers:

```text
TodayForm / HealthForm
  -> compact shared presentation widgets
  -> existing Controller
  -> existing Repository
  -> account-scoped Drift schema 14
  -> existing Today/Health Sync Adapter
  -> SyncCoordinator / Sync Protocol 2

Plan / Journal / Growth presentation
  -> existing Controllers and domain contracts
  -> presentation-only route and hierarchy changes
```

`CompactDurationEditor` keeps duration values as `int?` total minutes while
offering direct hour/minute input, a positive-add dialog, clear-to-null, and one
field-local undo. `CompactQuantityEditor` provides the corresponding behavior
for Water and direct-only Weight. `MetricDescriptionField` owns the collapsed
optional one-line editor. These widgets emit form state only; they never access
Repository, Drift, network, or synchronization and never save automatically.

Flutter schema 14 adds Research, Learning, Sleep, Weight, Water, and Exercise
narratives. Existing Mood, Energy, and Physical State narratives form the same
nine-field contract. Repository and export boundaries normalize blank text to
null, enforce 80 characters, preserve explicit numeric zero, retain hidden
fields, and treat description-only records as meaningful.

The Today/Health codecs recognize three exact payload generations: legacy
implicit 1-5, Sprint 17B explicit scale plus original descriptions, and Sprint
17C-E complete metric narratives. Current encoding includes every extension key
even when its value is null. Server Pydantic validation rejects partial sets and
keeps `extra="forbid"`; generic sync storage returns accepted JSON exactly.
There is no second adapter, entity type, cursor, conflict path, or automatic
sync. Server PostgreSQL and Alembic remain unchanged.

Plan changes remain under presentation and reuse existing goal actions and date
rules. Journal adds `/journal/history` but reuses its controller and edit flow;
the main page does not preload history. Growth adds `/growth/data-sources`,
reuses Projection/Coverage, preserves the selected period, and displays the
already normalized Mood/Energy domain on a fixed 1-10 chart without changing
aggregation.

All affected surfaces wrap at 320px and TextScaler 2.0. Icon-only actions retain
48px targets, Tooltip, keyboard activation, and readable Semantics. Metric
narrative contents are deliberately excluded from Semantics values, logs,
errors, statistics, and automatic Home/Growth summaries. See
`docs/58_PLAN_JOURNAL_GROWTH_AND_METRIC_NARRATIVES.md`.

## 32. AI Coach Conversational MVP

Sprint 18A extends the existing governed generation path instead of creating a
second AI stack:

```text
AiChatPage
  -> AiChatController
  -> AiChatCoordinator
      -> local AiChatRepository (Drift schema 15)
      -> AiChatInputAssembler (explicit context only)
      -> AiChatGateway
          -> authenticated POST /ai/chat/turns
              -> existing AI generation service
              -> Prompt Registry coach-chat-v1
              -> existing AiProvider / Usage / Generation Ledger
```

The reliable turn transaction writes a user message and pending assistant
placeholder before calling the network. A local write or request-binding
failure therefore cannot call the Provider. A known remote failure marks the
placeholder failed and permits only an explicit retry with a new request ID.
Network uncertainty marks `outcome_unknown`; the user may explicitly query the
existing request-status endpoint, but the client never automatically repeats
generation.

The Server accepts only `user` and `assistant` roles, bounds individual and
aggregate input, requires the final role to be `user`, inserts the system Prompt
itself, and derives account identity from JWT. `coach_chat` uses the existing
quota, request lease, idempotency, result retention, and ledger semantics. No
Chat thread/message table exists on PostgreSQL and no AI Report or Report
Version is created.

Chat context defaults to text-only. Growth, Today, Health, and Journal are read
through existing repositories only after explicit selection. Active Goals are
unsupported, and the six Sprint 17C-E metric narratives are not encoded into
Chat context. Selection changes do not call AI and reset on new thread/account.

Local threads and messages are strictly account-scoped and excluded from
`SyncEntityType`; there is no cursor, adapter, tombstone, or conflict surface
for Chat. The optional full-export module removes user, request, Provider,
credential, and recovery identifiers. Widgets depend on the controller/domain
models rather than Drift, AppDatabase, or gateway implementations. See
`docs/59_AI_COACH_CONVERSATIONAL_MVP.md`.
