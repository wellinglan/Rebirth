# Today Feedback

## 1. Today 历史记录状态显示问题

- 问题：Today 历史记录过了一天仍显示“草稿”，用户感知不自然。
- 触发场景：用户在第二天回看过去的 Today 历史记录。
- 原因分析：`recordStatus` 是数据库状态，不会因为日期过去自动从 `draft` 变为 `completed`。当前系统没有每日归档流程，也没有“完成今日记录”按钮。
- 短期方案：不自动修改数据库。在 Today History presentation 层调整显示语义：过去日期且有内容时显示“已记录”；今天显示“今日记录”；底层 `recordStatus` 仍保持原样。
- 长期方案：后续设计“完成今日记录”或“每日归档”流程，再真正使用 `completed` 状态。
- 状态：Sprint UI-1B 实现。

## Today 与 Health 数据同步延迟

- 问题：Today 修改健康相关字段并保存后，切换到 Health 页面不能立刻看到更新；反向也一样，需要重启 App 才能正常显示。
- 触发场景：Today 保存 sleep / exercise / physicalState 等健康字段后切换 Health；或 Health 保存后切换 Today。
- 原因分析：TodayController 与 HealthController 各自持有 state，跨模块保存后没有触发对方刷新。
- 短期方案：建立 shared health record revision / invalidation signal，Today 和 Health 保存 health_records 后通知对方刷新。
- 长期方案：后续可建立统一的数据变更事件总线或 repository watch stream。
- 状态：Sprint UI-1B 实现。

## Today 历史记录包含今天

- 问题：Today History 中包含今天，和 Today 主页面重复。
- 短期方案：Today 历史列表默认排除今天。
- 状态：Sprint UI-1B 实现。
