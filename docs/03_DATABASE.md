# Rebirth 数据库设计文档

> 文档版本：v1.0  
> 项目版本：Rebirth v0.1.0-alpha  
> 文档状态：Draft  
> 最后更新：2026-07  
> 适用阶段：Sprint 1.5 / Database Foundation  
> 实现状态：仅数据库设计，不包含 Drift 或 Dart 实现

---

## 1. 文档目的

本文档定义 Rebirth v1.0 本地数据库的数据原则、核心表结构、表间关系、约束、索引、迁移、删除和未来云同步策略。

本文档是后续 Drift 表、DAO、Repository 和数据迁移实现的设计基线。实际编码前如需调整字段，应先更新本文档，并重新检查与以下文档的一致性：

- `docs/00_AI_CONTEXT.md`
- `docs/01_PRD.md`
- `docs/02_ARCHITECTURE.md`

当前阶段只完成设计，不创建数据库类，不实现 Drift，不修改 Flutter 业务代码。

---

## 2. 数据库总体原则

### 2.1 服务于成长，而不是堆积数据

数据库只保存能够支持记录、回顾、趋势分析或 AI Coach 长期理解的数据。字段必须能回答明确问题，不为未来可能出现的需求提前收集无意义信息。

### 2.2 本地优先

SQLite 是 Rebirth v1.0 核心数据的默认事实来源。Today、Journal、Plan、Health 和已生成的 AI Report 在离线状态下仍应可读取；除 AI 生成等明确需要网络的能力外，核心记录流程不得依赖云端。

### 2.3 单一事实来源

同一指标只由一张表负责持久化，避免多处保存后产生不一致：

- 心情、精力、科研时间、学习时间属于 `today_records`；
- 睡眠、体重、饮水、运动和身体状态属于 `health_records`；
- 结构化复盘文本属于 `journal_entries`；
- AI 输出属于 `ai_reports`。

Today 页面可以聚合展示 `today_records` 与同日 `health_records`，但不重复存储健康字段。

### 2.4 明确区分“未记录”和“零”

可选数值字段使用 `NULL` 表示用户没有记录，使用 `0` 表示用户明确记录为零。例如：

- `research_minutes = NULL`：当天未填写科研时间；
- `research_minutes = 0`：当天明确没有进行科研。

趋势分析与 AI Coach 不得把 `NULL` 自动当作 `0`。

### 2.5 数据访问边界

后续实现必须遵循以下数据流，不允许 Widget 直接访问 SQLite：

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
Drift / SQLite
```

### 2.6 命名约定

- SQLite 表名和列名使用 `snake_case`；
- Dart 类型和字段使用英文 `PascalCase` / `camelCase`；
- 主键统一命名为 `id`；
- 外键统一使用 `<entity>_id`；
- 日期字段以 `_date` 结尾；
- UTC 时间戳字段以 `_at` 结尾；
- 时长字段明确单位，例如 `_minutes`；
- JSON 字段以 `_json` 结尾，仅用于不参与常规筛选的结构化快照或元数据。

---

## 3. 本地优先与隐私原则

### 3.1 默认仅保存在本地

v1.0 的用户资料、日常记录、复盘、目标、健康记录和 AI 报告默认只保存在本地 SQLite。没有用户明确同意时，不得上传到云端或第三方 AI 服务。

### 3.2 AI 数据授权

AI Coach 发起远程分析前必须满足：

1. 用户已明确开启 AI 数据共享；
2. 界面清楚说明将使用哪些时间范围和数据类型；
3. 只发送生成本次报告所需的最小数据；
4. 不发送本地数据库路径、设备信息或与分析无关的设置；
5. 关闭授权后停止新的上传，不影响本地记录和历史报告阅读。

授权状态保存在 `app_settings.ai_data_sharing_enabled`，授权时间保存在 `app_settings.ai_data_sharing_consent_at`。

### 3.3 云同步授权

未来云同步默认关闭。只有用户主动开启 `cloud_sync_enabled` 后，数据层才能创建同步任务。AI 数据共享与云同步是两个独立授权，不能互相代替。

### 3.4 本地加密边界

普通 SQLite 文件本身不等同于加密存储。v1.0 应依赖操作系统账户和应用目录权限保护数据库；如未来引入数据库加密、平台安全存储或加密备份，需要单独完成安全设计和迁移方案。API Key 不得存入以下业务表，也不得提交到版本库。

### 3.5 导出与备份

数据导出、备份和恢复必须由用户主动触发，并明确目标位置。导出内容不得默认包含内部错误、设备标识或不必要的 AI 请求元数据。

---

## 4. 日期与时间字段规范

### 4.1 自然日字段

Today、Journal 和 Health 都是按用户本地自然日理解的数据，其日期使用 SQLite `TEXT`，格式固定为：

```text
YYYY-MM-DD
```

例如：`2026-07-10`。

自然日字段包括：

- `today_records.record_date`
- `journal_entries.entry_date`
- `health_records.record_date`
- `goals.start_date`
- `goals.target_date`
- `ai_reports.period_start_date`
- `ai_reports.period_end_date`

禁止使用本地化字符串，如 `2026年7月10日`；禁止仅依赖 UTC 时间戳反推历史自然日。

### 4.2 UTC 时间戳

创建、更新、删除、生成和同步时间使用 SQLite `INTEGER`，保存 UTC Unix Epoch 毫秒：

```text
millisecondsSinceEpoch (UTC)
```

应用显示时再转换为用户当前时区。所有 `_at` 字段均遵循这一规则。

### 4.3 时区偏移

按自然日记录的表保存 `timezone_offset_minutes`，表示创建该自然日记录时相对于 UTC 的偏移分钟数。例如 UTC+08:00 保存为 `480`。

该字段用于解释跨时区旅行或夏令时变化下的历史记录，不用于代替 `user_profiles.timezone_id`。应用创建记录时必须显式写入，不依赖数据库默认值。

### 4.4 周与月范围

- 默认一周从星期一开始；
- 周报和月报均使用闭区间：`period_start_date` 与 `period_end_date` 都包含在统计范围内；
- 日报的开始日期与结束日期相同；
- 跨时区后，已经保存的历史 `record_date` 不自动重写。

### 4.5 时长和评分

- 时长统一保存为整数分钟，不使用小时小数；
- 饮水量统一为整数毫升；
- 体重统一为千克 `REAL`；
- 心情、精力和主观身体状态统一为 `1-5` 整数；
- 评分方向统一为数值越高状态越好：`1` 表示很低或很差，`3` 表示一般，`5` 表示很好；
- `NULL` 表示未记录，不能参与平均值分母。

---

## 5. 主键、通用字段与同步状态

### 5.1 主键策略

所有用户数据表使用应用生成的 UUID 字符串作为 `TEXT` 主键。UUID 应在写入 SQLite 前生成，从而支持离线创建和未来多设备合并。

v1.0 不使用依赖单机顺序的自增整数作为跨设备身份。由于本地主键已全局唯一，未来服务端原则上继续使用同一个 `id`，不额外引入第二套远端主键。

### 5.2 通用审计字段

除特殊说明外，核心内容表包含：

- `created_at`：首次创建时间；
- `updated_at`：最后一次内容更新时间；
- `deleted_at`：软删除时间，未删除时为 `NULL`。

`updated_at` 必须在同一事务内随内容变更更新。单纯读取数据不得修改该字段。

### 5.3 云同步预留字段

需要未来同步的表预留：

- `sync_status`：`local_only`、`pending`、`synced` 或 `conflict`；
- `server_version`：服务端记录版本，尚未同步时为 `NULL`；
- `last_synced_at`：最近成功同步时间；
- `origin_device_id`：首次创建记录的设备标识，未启用同步时可为 `NULL`。

v1.0 默认 `sync_status = local_only`。云同步启用后，本地新增、修改或软删除应将其改为 `pending`；成功后改为 `synced`。冲突不得静默覆盖，应保留本地数据并标记为 `conflict`。

### 5.4 布尔值与枚举

- SQLite 布尔值使用 `INTEGER`，只允许 `0` 或 `1`；
- 枚举使用可读的英文 `TEXT` 值；
- 后续 Drift 使用 Dart enum 与 TypeConverter 映射；
- 未识别的枚举值应进入可诊断状态，不得擅自转换为另一个业务含义。

---

## 6. 核心表关系

```text
user_profiles
  ├── 1:N today_records
  ├── 1:N journal_entries
  ├── 1:N goals
  ├── 1:N health_records
  ├── 1:N ai_reports
  └── 1:1 app_settings

today_records
  ├── 0..1 journal_entries（同一用户、同一自然日）
  ├── 0..1 health_records（同一用户、同一自然日）
  └── 0..3 goals（今日三件事可分别关联目标）

goals
  └── 0..N child goals（通过 parent_goal_id 自关联）
```

v1.0 以单用户使用为主要场景，但所有业务表仍保留 `user_id`，避免未来登录、导入或多资料迁移时重构整个数据库。

---

## 7. `user_profiles`

### 7.1 表职责

保存用户长期资料和解释历史日期所需的基础偏好。只收集服务于成长体验和数据解释的信息，不保存不必要的身份信息。

### 7.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `display_name` | `TEXT` | 否 | `NULL` | 用户希望在应用中使用的称呼 |
| `growth_focus` | `TEXT` | 否 | `NULL` | 当前成长关注方向，供用户资料和未来 AI 上下文使用 |
| `timezone_id` | `TEXT` | 是 | 应用写入当前时区 | IANA 时区标识，如 `Asia/Shanghai` |
| `is_active` | `INTEGER` | 是 | `1` | 当前使用的本地资料，取值 `0/1` |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 7.3 约束与索引

- `id` 为主键；
- `is_active` 只允许 `0` 或 `1`；
- 建立唯一部分索引，保证最多只有一个未删除且 `is_active = 1` 的资料；
- 不在 v1.0 收集真实姓名、手机号、邮箱或精确地址。

---

## 8. `today_records`

### 8.1 表职责

保存某个自然日的重点、主观状态、科研与学习投入以及一句话记录。它是 Today 模块的核心表，但不重复保存 Health 模块负责的睡眠、运动等指标。

### 8.2 详细字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id` |
| `record_date` | `TEXT` | 是 | 应用写入本地日期 | 自然日，格式 `YYYY-MM-DD` |
| `timezone_offset_minutes` | `INTEGER` | 是 | 应用显式写入 | 创建该日记录时的 UTC 偏移分钟数 |
| `priority_1` | `TEXT` | 否 | `NULL` | 今日第一件重要事项 |
| `priority_1_completed` | `INTEGER` | 是 | `0` | 第一件事项是否完成，取值 `0/1` |
| `priority_1_goal_id` | `TEXT` | 否 | `NULL` | 第一件事项关联的目标 |
| `priority_2` | `TEXT` | 否 | `NULL` | 今日第二件重要事项 |
| `priority_2_completed` | `INTEGER` | 是 | `0` | 第二件事项是否完成，取值 `0/1` |
| `priority_2_goal_id` | `TEXT` | 否 | `NULL` | 第二件事项关联的目标 |
| `priority_3` | `TEXT` | 否 | `NULL` | 今日第三件重要事项 |
| `priority_3_completed` | `INTEGER` | 是 | `0` | 第三件事项是否完成，取值 `0/1` |
| `priority_3_goal_id` | `TEXT` | 否 | `NULL` | 第三件事项关联的目标 |
| `mood_score` | `INTEGER` | 否 | `NULL` | 心情评分，范围 `1-5` |
| `energy_score` | `INTEGER` | 否 | `NULL` | 精力评分，范围 `1-5` |
| `research_minutes` | `INTEGER` | 否 | `NULL` | 科研投入分钟数，必须大于等于 `0` |
| `learning_minutes` | `INTEGER` | 否 | `NULL` | 学习投入分钟数，必须大于等于 `0` |
| `daily_note` | `TEXT` | 否 | `NULL` | 今日一句话，保持轻量 |
| `record_status` | `TEXT` | 是 | `draft` | 记录状态：`draft` 或 `completed`，不代表用户成功或失败 |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 8.3 业务约束

- 同一用户、同一自然日最多存在一条未删除记录；
- 三件事均可为空，以支持渐进式填写；
- v1.0 的“今日三件事”数量固定，因此直接保存在 `today_records`，暂不拆分 `today_priorities` 表；
- 如果未来支持任意数量的事项、拖拽排序或子任务，再通过数据库迁移拆分为独立 `today_priorities` 表；
- 当某个 `priority_n` 为空时，对应的完成状态不参与统计；
- `mood_score`、`energy_score` 只允许 `1-5` 或 `NULL`；
- 时长只允许非负整数或 `NULL`；
- `record_status = completed` 仅表示用户完成了当天记录，不表示当天表现评价；
- Today 页面展示睡眠和运动时，从同日 `health_records` 读取，并在同一事务中分别保存两张表。

### 8.4 外键与索引

- `user_id -> user_profiles.id`，建议 `ON DELETE RESTRICT`；
- `priority_n_goal_id -> goals.id`，建议 `ON DELETE SET NULL`；
- 唯一部分索引：`(user_id, record_date) WHERE deleted_at IS NULL`；
- 趋势查询索引：`(user_id, record_date DESC)`；
- 同步查询索引：`(sync_status, updated_at)`。

---

## 9. `journal_entries`

### 9.1 表职责

保存按自然日组织的结构化复盘。v1.0 使用五个明确字段，而不是将回答放入无法稳定查询的通用 JSON。

### 9.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id` |
| `today_record_id` | `TEXT` | 否 | `NULL` | 可选关联同日 `today_records.id` |
| `entry_date` | `TEXT` | 是 | 应用写入本地日期 | 复盘对应自然日，格式 `YYYY-MM-DD` |
| `timezone_offset_minutes` | `INTEGER` | 是 | 应用显式写入 | 创建该日复盘时的 UTC 偏移分钟数 |
| `most_important_accomplishment` | `TEXT` | 否 | `NULL` | 今天最重要的完成是什么 |
| `most_draining_event` | `TEXT` | 否 | `NULL` | 今天最消耗我的事情是什么 |
| `emotion_source` | `TEXT` | 否 | `NULL` | 今天的情绪主要来自哪里 |
| `learning` | `TEXT` | 否 | `NULL` | 今天学到了什么 |
| `tomorrow_adjustment` | `TEXT` | 否 | `NULL` | 明天最应该调整的一件事 |
| `entry_status` | `TEXT` | 是 | `draft` | `draft` 或 `completed` |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 9.3 与日期及 Today 的关联

`entry_date` 是 Journal 的业务身份，`today_record_id` 是可选的直接引用：

- Journal 可以在 TodayRecord 尚未创建时独立保存；
- TodayRecord 后创建时，Repository 可按 `user_id + entry_date` 补充关联；
- 两者存在时，Repository 必须校验用户和日期一致；
- TodayRecord 被软删除时，Journal 仍保留；
- TodayRecord 被硬删除时，`today_record_id` 使用 `ON DELETE SET NULL`；
- 周报和连续记录统计以 `entry_date` 为准，不依赖 `today_record_id`。

### 9.4 约束与索引

- 同一用户、同一自然日最多存在一条未删除 Journal；
- 每个回答建议不超过 200 个字符，这是 UI 层降低记录压力的轻量输入提示，不是数据库层的强制长度限制；
- 保存时不得静默截断用户输入；如果未来引入硬性长度限制，UI 必须在保存前明确提示并允许用户调整；
- 唯一部分索引：`(user_id, entry_date) WHERE deleted_at IS NULL`；
- `today_record_id` 非空时建立唯一部分索引，确保一条 TodayRecord 最多关联一条未删除 Journal；
- 历史查询索引：`(user_id, entry_date DESC)`。

---

## 10. `goals`

### 10.1 表职责

保存人生、年度、季度、月、周和日六个层级的目标树。Goal 表只承担基础目标管理，不引入甘特图、复杂依赖、积分或游戏化进度。

### 10.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id` |
| `parent_goal_id` | `TEXT` | 否 | `NULL` | 父目标，自关联 `goals.id` |
| `title` | `TEXT` | 是 | 无 | 目标标题，去除首尾空白后不得为空 |
| `description` | `TEXT` | 否 | `NULL` | 可选说明 |
| `goal_level` | `TEXT` | 是 | 无 | `life`、`year`、`quarter`、`month`、`week`、`day` |
| `status` | `TEXT` | 是 | `not_started` | `not_started`、`in_progress`、`completed`、`paused`、`cancelled` |
| `start_date` | `TEXT` | 否 | `NULL` | 目标开始日期 |
| `target_date` | `TEXT` | 否 | `NULL` | 目标期望结束日期，不作为压力性硬截止判断 |
| `completed_at` | `INTEGER` | 否 | `NULL` | 标记完成的 UTC 时间 |
| `archived_at` | `INTEGER` | 否 | `NULL` | 归档时间；为空表示仍在普通目标列表中 |
| `sort_order` | `INTEGER` | 是 | `0` | 同级展示顺序，允许非连续整数 |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 10.3 层级结构规则

层级由高到低为：

```text
life → year → quarter → month → week → day
```

规则如下：

- `parent_goal_id = NULL` 表示根目标；
- 父目标和子目标必须属于同一用户；
- 父目标层级必须高于子目标层级，允许跨级关联，例如年度目标直接关联月目标；
- 禁止目标将自己或自己的后代设为父目标；
- 循环检测、同用户校验和层级校验由 Repository 在事务内完成；
- 数据库使用自关联外键防止引用不存在的目标，但不使用复杂触发器维护树；
- 日目标可以通过 `today_records.priority_n_goal_id` 与今日三件事关联，不新增多对多表。

### 10.4 状态语义

- `not_started`：尚未开始；
- `in_progress`：正在推进；
- `completed`：已完成；
- `paused`：暂时放下，允许以后恢复；
- `cancelled`：不再继续，但保留历史原因和关联。

状态只描述目标当前阶段，不对用户行为作价值判断。

### 10.5 约束与索引

- `parent_goal_id -> goals.id`，硬删除时建议 `ON DELETE SET NULL`；
- `sort_order >= 0`；
- `archived_at` 为空或为非负 UTC 毫秒时间戳；普通目标查询默认排除已归档目标；
- `target_date` 与 `start_date` 同时存在时，`target_date >= start_date`；
- 树查询索引：`(user_id, parent_goal_id, sort_order)`；
- 层级查询索引：`(user_id, goal_level, status)`；
- 日期查询索引：`(user_id, target_date)`。

---

## 11. `health_records`

### 11.1 表职责

保存按自然日汇总的基础身体状态，包括睡眠、体重、饮水、运动和主观身体状态。v1.0 每个用户每天最多一条汇总记录。

### 11.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id` |
| `today_record_id` | `TEXT` | 否 | `NULL` | 可选关联同日 `today_records.id` |
| `record_date` | `TEXT` | 是 | 应用写入本地日期 | 健康记录对应自然日 |
| `timezone_offset_minutes` | `INTEGER` | 是 | 应用显式写入 | 创建该日记录时的 UTC 偏移分钟数 |
| `sleep_duration_minutes` | `INTEGER` | 否 | `NULL` | 睡眠时长，非负整数分钟 |
| `weight_kg` | `REAL` | 否 | `NULL` | 体重，单位千克，必须大于 `0` |
| `water_intake_ml` | `INTEGER` | 否 | `NULL` | 饮水量，单位毫升，必须大于等于 `0` |
| `exercise_type` | `TEXT` | 否 | `NULL` | 当日主要运动类型，自由文本或受控选项值 |
| `exercise_duration_minutes` | `INTEGER` | 否 | `NULL` | 当日运动总时长，非负整数分钟 |
| `physical_state_score` | `INTEGER` | 否 | `NULL` | 主观身体状态，范围 `1-5` |
| `note` | `TEXT` | 否 | `NULL` | 简短健康备注 |
| `data_source` | `TEXT` | 是 | `manual` | `manual`、`health_connect`、`apple_health` 或未来来源 |
| `source_record_id` | `TEXT` | 否 | `NULL` | 外部来源记录标识，用于未来导入去重 |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 11.3 与 TodayRecord 的关系

- `health_records` 是睡眠和运动等健康指标的单一事实来源；
- Today 页面按 `user_id + record_date` 聚合同日 HealthRecord；
- HealthRecord 可以在 TodayRecord 尚未创建时独立存在；
- 两者都存在时，可设置 `today_record_id`，并校验用户与日期一致；
- TodayRecord 软删除不删除 HealthRecord；
- TodayRecord 硬删除时，`today_record_id` 使用 `ON DELETE SET NULL`；
- 保存 Today 页面中的普通状态和健康状态时，应通过一个 Repository 事务分别更新两张表，避免只保存一半。

### 11.4 约束与索引

- 同一用户、同一自然日最多存在一条未删除 HealthRecord；
- 唯一部分索引：`(user_id, record_date) WHERE deleted_at IS NULL`；
- `today_record_id` 非空时建立唯一部分索引，确保一条 TodayRecord 最多关联一条未删除 HealthRecord；
- 趋势查询索引：`(user_id, record_date DESC)`；
- 外部导入去重索引：`(data_source, source_record_id)`，其中 `source_record_id` 非空时生效；
- v1.0 如需记录同日多次运动，只保存当日汇总；独立运动明细表应在真实需求出现后另行设计。

---

## 12. `ai_reports`

### 12.1 表职责

保存 AI Coach 的生成请求状态、输入来源引用、模型元数据和最终输出。AI 输出不能只显示一次，必须可回顾、可去重并可解释其使用的数据范围。

### 12.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id` |
| `report_type` | `TEXT` | 是 | 无 | `daily_insight`、`weekly_report`、`monthly_reflection`、`tomorrow_suggestion`、`trend_explanation` |
| `period_start_date` | `TEXT` | 是 | 无 | 输入数据范围开始日期，闭区间 |
| `period_end_date` | `TEXT` | 是 | 无 | 输入数据范围结束日期，闭区间 |
| `input_sources_json` | `TEXT` | 是 | `[]` | 输入记录引用列表，保存表名、记录 ID 和对应 `updated_at` |
| `input_hash` | `TEXT` | 是 | 无 | 规范化输入的哈希，用于避免重复生成 |
| `input_snapshot_json` | `TEXT` | 否 | `NULL` | 可选最小输入快照，仅在复现确有需要且符合授权时保存 |
| `prompt_version` | `TEXT` | 是 | 无 | 生成时使用的 Prompt 版本 |
| `provider` | `TEXT` | 否 | `NULL` | AI 服务提供方；尚未发送或本地生成时可为空 |
| `model` | `TEXT` | 否 | `NULL` | 生成模型标识 |
| `generation_mode` | `TEXT` | 是 | `manual` | `manual` 或未来的 `automatic` |
| `report_status` | `TEXT` | 是 | `pending` | `pending`、`completed` 或 `failed` |
| `report_content` | `TEXT` | 否 | `NULL` | 面向用户展示的主要报告正文 |
| `structured_output_json` | `TEXT` | 否 | `NULL` | 可选结构化结果，如摘要或建议列表 |
| `error_code` | `TEXT` | 否 | `NULL` | 失败时的内部可分类错误码，不保存密钥或完整请求 |
| `requested_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 请求创建时间 |
| `generated_at` | `INTEGER` | 否 | `NULL` | 成功生成时间 |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 本地记录创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `deleted_at` | `INTEGER` | 否 | `NULL` | 软删除时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 12.3 输入来源

AIReport 可引用以下输入：

- `today_records`：重点、完成状态、心情、精力、科研和学习时间；
- `journal_entries`：结构化复盘；
- `health_records`：睡眠、运动、饮水和身体状态；
- `goals`：当前目标与层级关系；
- GrowthSummary：由本地查询临时计算的趋势摘要，不作为 v1.0 独立表。

`input_sources_json` 只保存来源引用和版本信息，推荐结构示例：

```json
[
  {
    "table": "today_records",
    "id": "record-uuid",
    "updated_at": 1783670400000
  }
]
```

### 12.4 输出保存方式

- 请求开始时先保存 `pending` 记录，避免进程中断后状态丢失；
- 成功后在事务内写入 `report_content`、可选结构化输出、模型信息和 `generated_at`，并设置为 `completed`；
- 失败时设置为 `failed` 并保存可分类的 `error_code`，不保存 API Key、Authorization Header 或完整底层异常；
- 相同用户、类型、日期范围、Prompt 版本和 `input_hash` 的已完成报告可以直接复用；
- 当来源记录更新后，新的 `input_hash` 会产生新报告，旧报告继续保留用于历史回顾；
- AI 输出属于分析结果，不覆盖用户原始记录。

### 12.5 约束与索引

- `period_end_date >= period_start_date`；
- `report_status = completed` 时，`report_content` 不应为空；
- 报告查询索引：`(user_id, report_type, period_end_date DESC)`；
- 去重查询索引：`(user_id, report_type, period_start_date, period_end_date, input_hash)`；
- 待处理查询索引：`(report_status, requested_at)`。

### 12.6 AI 输入哈希规范

`input_hash` 用于标识一次 AI 分析所使用的稳定输入，不用于标识模型、设备或用户身份。生成规则如下：

1. 哈希算法固定使用 SHA-256，结果保存为小写十六进制字符串；
2. 输入来源先按 `table` 升序排序，再按 `id` 升序排序；
3. 每条来源至少包含 `table`、`id` 和 `updated_at`，并只包含本次分析实际使用的数据；
4. 使用稳定 JSON 编码：对象键按字典序排列、数组顺序固定、使用 UTF-8 编码、不加入无意义格式化空白；
5. 参与哈希的顶层数据必须包含 `prompt_version`，确保 Prompt 语义变化后生成新的哈希；
6. `model` 和 `provider` 不参与 `input_hash`，它们属于生成元数据，不属于输入内容；
7. 排除 `sync_status`、`server_version`、`last_synced_at`、`origin_device_id` 等同步元数据，避免一次纯同步操作触发重复生成；
8. 对稳定 JSON 的 UTF-8 字节执行 SHA-256，不对数据库原始行或非确定性对象字符串直接计算哈希。

推荐的规范化输入外层结构如下：

```json
{
  "prompt_version": "daily-insight-v1",
  "sources": [
    {
      "id": "record-uuid",
      "table": "today_records",
      "updated_at": 1783670400000
    }
  ]
}
```

如果实际发送给 AI 的输入包含来源字段值，这些值也必须以稳定、最小化的结构加入对应来源对象后再计算哈希。相同业务输入和 Prompt 版本必须得到相同哈希；仅更换模型不得改变 `input_hash`。

---

## 13. `app_settings`

### 13.1 表职责

保存应用级和当前用户级的明确设置。v1.0 使用类型明确的列，不采用任意 key-value JSON，以保证可发现性、类型安全和迁移可控。

### 13.2 字段设计

| 字段 | SQLite 类型 | 必填 | 默认值 | 说明 |
|---|---|---:|---|---|
| `id` | `TEXT` | 是 | 应用生成 UUID | 主键 |
| `user_id` | `TEXT` | 是 | 无 | 关联 `user_profiles.id`，v1.0 每个用户一条 |
| `local_installation_id` | `TEXT` | 是 | App 首次启动时生成 UUID | 本地安装标识，用于填充业务记录的 `origin_device_id` |
| `theme_mode` | `TEXT` | 是 | `system` | `system`、`light` 或 `dark` |
| `locale` | `TEXT` | 是 | `zh_CN` | UI 语言标识 |
| `first_day_of_week` | `INTEGER` | 是 | `1` | ISO 星期值，`1` 表示星期一 |
| `onboarding_completed` | `INTEGER` | 是 | `0` | 是否完成初始设置，取值 `0/1` |
| `ai_data_sharing_enabled` | `INTEGER` | 是 | `0` | 是否明确允许 App 在用户主动操作时准备所选 AI 输入；不等于自动发送 |
| `ai_data_sharing_consent_at` | `INTEGER` | 否 | `NULL` | 最近一次开启 AI 数据共享的时间 |
| `cloud_sync_enabled` | `INTEGER` | 是 | `0` | 未来云同步开关，v1.0 保持关闭 |
| `created_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 创建时间 |
| `updated_at` | `INTEGER` | 是 | 应用写入当前 UTC 时间 | 最后更新时间 |
| `sync_status` | `TEXT` | 是 | `local_only` | 设置自身的同步状态 |
| `server_version` | `INTEGER` | 否 | `NULL` | 服务端版本 |
| `last_synced_at` | `INTEGER` | 否 | `NULL` | 最近同步时间 |
| `origin_device_id` | `TEXT` | 否 | `NULL` | 初始创建设备标识 |

### 13.3 约束与索引

- `user_id` 建立唯一索引，每个用户一条设置；
- `local_installation_id` 在当前安装生命周期内保持稳定，新建业务记录时将其复制到 `origin_device_id`；
- `local_installation_id` 不等同于用户身份，不用于登录、分析、广告、跨安装关联或用户追踪；
- 云端恢复其他设备的数据时，不得用远端值覆盖当前安装的 `local_installation_id`；
- 所有布尔字段只允许 `0/1`；
- `first_day_of_week` 只允许 `1-7`；
- 关闭 AI 数据共享时保留最近一次 `ai_data_sharing_consent_at`，不删除本地历史报告或原始记录，并阻止新的 AI 输入准备和 pending 报告创建；
- `app_settings` 不进行常规软删除，重置应用时按明确流程硬删除并重新创建默认设置。

---

## 14. App Bootstrap 初始化流程

App 完成数据库打开和 schema migration 后，必须先执行 Bootstrap，再允许业务模块创建记录。初始化流程如下：

1. 在事务内查询满足 `is_active = 1 AND deleted_at IS NULL` 的 `user_profiles`；
2. 如果不存在 active UserProfile，则创建默认 UserProfile，并生成其 UUID；
3. 在同一事务中创建与该 UserProfile 关联的 `app_settings`，同时生成 `local_installation_id` UUID；
4. 如果恰好存在一个 active UserProfile，则使用它，并检查关联的 `app_settings` 是否存在；缺失时在事务中补建，不修改已有用户内容；
5. Bootstrap 成功后，后续业务记录默认使用该 active UserProfile 的 `id` 作为 `user_id`；
6. 创建业务记录时，从 active UserProfile 对应的 `app_settings.local_installation_id` 填充 `origin_device_id`；
7. 如果发现多个未删除的 active UserProfile，App 必须进入可诊断状态，停止默认业务写入，不得随机选择、按查询顺序选择或静默停用其中任意资料。

默认 UserProfile 与 AppSettings 的创建必须原子完成：任一步骤失败时回滚整个事务，避免出现“有用户但无设置”或安装标识缺失的半初始化状态。

`local_installation_id` 只表示当前本地安装。它不作为用户认证凭据，不进入 AI 输入，不用于统计或追踪用户；应用重新安装或用户明确清除全部本地数据后可以生成新的值。

---

## 15. Drift 表设计建议

本节只定义后续实现方向，不在 Sprint 1.5 创建任何 Dart 代码。

### 15.1 文件组织

建议遵循现有架构：

```text
lib/core/database/
  app_database.dart
  tables/
    user_profiles_table.dart
    today_records_table.dart
    journal_entries_table.dart
    goals_table.dart
    health_records_table.dart
    ai_reports_table.dart
    app_settings_table.dart
  daos/
```

Feature 通过 Repository 使用 DAO，不直接依赖 Drift 表类。

### 15.2 类型映射

| 业务类型 | SQLite | Drift 建议 |
|---|---|---|
| UUID / 文本 | `TEXT` | `text()` |
| 自然日 | `TEXT` | `text()`，Repository 转换为日期值对象 |
| UTC 毫秒时间戳 | `INTEGER` | `integer()`，统一转换为 UTC `DateTime` |
| 布尔值 | `INTEGER` | `boolean()` |
| 分钟、毫升、评分 | `INTEGER` | `integer()` |
| 千克 | `REAL` | `real()` |
| 枚举 | `TEXT` | `text()` + TypeConverter |
| JSON | `TEXT` | `text()` + 明确 DTO/Converter |

### 15.3 实现约束

- 启用 SQLite foreign keys；
- 对评分、布尔、非负时长和日期范围增加 `CHECK` 约束；
- 使用复合索引支持 7 天、30 天、周和月查询；
- 对“未删除记录唯一”使用 SQLite 部分唯一索引；如 Drift 声明能力不足，在 migration 中执行受版本控制的自定义 SQL；
- TodayRecord 与 HealthRecord 联合保存、Goal 树修改、AIReport 状态更新使用事务；
- DAO 返回明确实体或数据模型，不把 Drift 生成类型直接泄漏到 Presentation；
- 对日期查询、软删除过滤和同步状态查询提供统一 DAO 方法；
- JSON 仅用于 AI 输入引用和输出元数据，不用于替代可查询的核心字段；
- Windows 和 Android 使用同一 schemaVersion 与迁移链，平台差异只放在数据库连接创建层。

### 15.4 建议优先测试

- 同一用户同一日期的唯一约束；
- `NULL` 与 `0` 的统计差异；
- Today、Journal、Health 按日期关联；
- Goal 循环和跨用户父子关系拒绝；
- Today 删除后 Journal、Health 保留；
- AIReport pending、completed、failed 状态转换；
- 软删除记录不出现在普通查询中；
- 每一版数据库迁移前后数据一致。

---

## 16. 数据迁移策略

### 16.1 版本管理

- 首次实现时 `schemaVersion` 从 `1` 开始；
- 每次表结构或数据语义变化都递增版本；
- 迁移按相邻版本编写，例如 `v1 -> v2`、`v2 -> v3`；
- 禁止通过删除数据库解决正式用户迁移问题；
- 不在应用启动时自动执行未测试的破坏性迁移。

### 16.2 迁移原则

优先使用可回滚、可验证的增量变化：

1. 新增可空列或带安全默认值的列；
2. 回填旧数据；
3. 校验回填结果；
4. 再启用新的业务约束；
5. 最后清理废弃字段，并至少跨一个稳定版本保留兼容读取。

字段改名应通过“新增列、复制数据、验证、删除旧列”的方式处理，不依赖隐式重命名。复杂 SQLite 表重建必须在单个事务中完成。

### 16.3 数据语义迁移

如果评分范围、枚举含义、时区规则或单位发生变化，迁移必须同时转换历史数据，不能只改变 Dart enum。例如将小时小数改为分钟时，应明确舍入规则并测试边界值。

### 16.4 测试与备份

- 为至少前两个 schemaVersion 保留迁移测试数据库；
- 测试空库、正常数据、软删除数据、异常边界值；
- 迁移前确保数据库文件可恢复；
- 迁移完成后校验表数量、关键记录数量、外键和唯一索引；
- 迁移失败时保留原始文件并给出克制、可恢复的提示，不进入部分迁移状态。

### 16.5 降级策略

v1.0 不支持自动数据库降级。旧版本应用遇到更高 schemaVersion 时应停止写入并提示升级，不能尝试删除未知列或重建数据库。

---

## 17. 删除与软删除策略

### 17.1 默认软删除

以下用户内容默认软删除：

- `user_profiles`
- `today_records`
- `journal_entries`
- `goals`
- `health_records`
- `ai_reports`

软删除时设置 `deleted_at` 和 `updated_at`。启用云同步后还应设置 `sync_status = pending`，使删除作为 tombstone 同步到其他设备。

### 17.2 普通查询规则

- 所有普通列表、统计和 AI 输入查询默认添加 `deleted_at IS NULL`；
- 回收或恢复流程显式查询已删除数据；
- 恢复前重新检查日期唯一约束，避免与新建记录冲突；
- 软删除记录不参与 Journal 连续性、趋势平均值和 AI 分析。

### 17.3 关联删除规则

- 删除 TodayRecord 不级联删除同日 Journal 或 HealthRecord；
- 删除 Journal 不影响 TodayRecord；
- 删除 HealthRecord 不影响 TodayRecord；
- 删除 Goal 时，v1.0 默认在确认后于同一事务软删除其后代，避免产生无法理解的孤立分支；
- Goal 被删除后，TodayRecord 中的历史目标引用可保留 ID 供恢复，普通 UI 不展示已删除目标；
- 删除 AIReport 不影响任何原始输入记录。

### 17.4 硬删除

硬删除仅用于：

- 用户明确执行“清除全部数据”；
- 测试环境重置；
- 云同步确认所有设备已接收 tombstone 后的长期清理；
- 法律或隐私请求要求彻底移除数据。

硬删除必须在事务中按外键顺序执行。不得把硬删除作为普通编辑失败后的恢复手段。

`app_settings` 不参与常规软删除；应用重置时硬删除并重新创建。

---

## 18. 未来云同步策略

### 18.1 同步单位

以单条记录为同步单位，使用 UUID `id`、`updated_at`、`deleted_at`、`server_version` 和 `sync_status` 判断变化。Goal 树可以按记录同步，但父子关系落库前必须保证引用可解析。

### 18.2 冲突处理

- 不采用无提示的“最后写入覆盖一切”；
- 字段级自动合并只用于能够证明安全的字段；
- Journal、Daily Note 和 AI Report 等文本冲突应保留双方版本；
- 同一日期的 Today 或 Health 冲突应进入 `conflict`，由 Repository 生成可恢复的解决流程；
- 删除与更新冲突不得立即物理删除记录。

### 18.3 设备与服务端版本

- `origin_device_id` 只用于同步诊断和冲突来源，不用于用户追踪；
- `server_version` 由服务端单调递增或采用服务端定义的版本令牌；
- 服务端时间不能替代本地 `record_date`；
- 设备时钟不可靠时，服务端可记录接收时间，但不得静默改写用户自然日。

### 18.4 同步范围

云同步启用后也应允许用户选择同步范围。敏感 Journal 和 Health 数据未来可以拥有独立同步开关；在该能力设计完成前，不应默认上传所有表。

---

## 19. v1.0 实现顺序建议

后续进入数据库实现 Sprint 时，建议按以下顺序推进：

1. 建立 Drift 数据库与 `user_profiles`、`app_settings`；
2. 实现 `today_records` 及日期唯一约束；
3. 实现 `journal_entries` 与日期关联；
4. 实现 `goals` 自关联和树约束；
5. 实现 `health_records` 与 Today 聚合；
6. 实现 `ai_reports` 状态和输入引用；
7. 补齐迁移、软删除、事务和跨平台测试。

每一步都应保持数据库可迁移、应用可运行，并先验证数据安全再扩展 UI。

---

## 20. 总结

Rebirth 的数据库不是为了记录更多，而是为了长期保存有意义、可解释、可关联的数据。

v1.0 的设计重点是：

- 本地优先和明确授权；
- 自然日语义稳定；
- 同一指标只有一个事实来源；
- 原始记录与 AI 输出彼此独立；
- 删除可恢复，迁移可验证；
- 为未来同步预留能力，但不提前引入云端复杂度。

> 数据设计的价值，不在于字段数量，而在于多年以后仍能准确理解用户经历了什么。
