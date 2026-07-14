# Today / Journal Usage Feedback Backlog

## 1. Today 历史记录状态显示问题

问题：
Today 历史记录过了一天仍显示“草稿”，用户感知不自然。

原因：
recordStatus 是数据库状态，不会因为日期过去自动从 draft 变为 completed。
当前系统没有每日归档流程，也没有“完成今日记录”按钮。

短期方案：
不要自动修改数据库。
在 Today History presentation 层调整显示语义：
- 过去日期 + 有内容：显示“已记录”
- 今天：显示“今日记录”
- 底层 recordStatus 仍保持原样

长期方案：
后续设计“完成今日记录”或“每日归档”流程，再真正使用 completed 状态。

状态：
暂不实现。等实际使用几天后，结合其他 Today / Journal 使用问题统一进入 Usage Polish Sprint。

注意：
本 Sprint 只记录该问题，不修改 Today / Journal 代码。
