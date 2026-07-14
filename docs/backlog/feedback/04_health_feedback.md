# Health Feedback

## 模板

- 问题：
- 触发场景：
- 原因分析：
- 短期方案：
- 长期方案：
- 状态：

## 当前记录

## Health 与 Today 数据同步延迟

- 问题：Health 保存后 Today 不能立刻看到更新；Today 保存后 Health 不能立刻看到更新。
- 原因分析：跨模块 controller state 没有统一刷新信号。
- 短期方案：建立 shared health record revision / invalidation signal。
- 状态：Sprint UI-1B 实现。

## Health 历史记录包含今天

- 问题：Health 历史中包含今天，与今日健康表单重复。
- 短期方案：Health 历史列表默认排除今天。
- 状态：Sprint UI-1B 实现。
