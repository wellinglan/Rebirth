# 02_ARCHITECTURE.md

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
- 后续可接入 FastAPI 后端。

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

### 7.2 Bottom Navigation

HomeShell 使用 Bottom Navigation 管理五个主入口：

1. Today
2. Journal
3. Plan
4. Growth
5. Profile

Health 与 AI Coach 初期可放入 Profile 内部入口，后续视重要程度调整。

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
