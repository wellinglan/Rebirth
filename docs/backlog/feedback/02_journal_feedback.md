# Journal Feedback

## 模板

- 问题：
- 触发场景：
- 原因分析：
- 短期方案：
- 长期方案：
- 状态：

## Journal 历史详情问答层级不清晰

- 问题：最近复盘点开后，问题与回答的字体、大小、粗细过于接近，阅读层级不清楚。
- 触发场景：点击 Journal 最近复盘历史记录，打开详情 Dialog。
- 原因分析：问题 label 与回答正文使用相同或近似 TextStyle。
- 短期方案：问题使用 titleSmall / w600，回答使用 bodyMedium / w400，并增加垂直间距。
- 长期方案：后续可设计统一 readonly detail section 组件。
- 状态：Sprint UI-1B 实现。
