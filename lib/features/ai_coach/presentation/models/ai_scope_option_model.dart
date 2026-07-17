import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

final class AiScopeOptionModel {
  const AiScopeOptionModel({
    required this.scope,
    required this.title,
    required this.description,
    required this.includedFields,
    required this.textBoundary,
    required this.accessibilityLabel,
  });

  final AiDataScope scope;
  final String title;
  final String description;
  final String includedFields;
  final String textBoundary;
  final String accessibilityLabel;
}

abstract final class AiScopeCatalog {
  static const options = <AiScopeOptionModel>[
    AiScopeOptionModel(
      scope: AiDataScope.growthSummary,
      title: '成长趋势汇总',
      description: '聚合最近 7 天的时间、评分和记录天数。',
      includedFields: '科研、学习、运动、睡眠、Mood、Energy 与 Journal 记录天数',
      textBoundary: '不包含 Journal 原文',
      accessibilityLabel: '成长趋势汇总，不包含 Journal 原文',
    ),
    AiScopeOptionModel(
      scope: AiDataScope.todayMetrics,
      title: '每日状态指标',
      description: '按日期展示科研、学习、Mood、Energy 和完成数量。',
      includedFields: '时间、评分、Priority 填写数和完成数',
      textBoundary: '不包含 Daily Note 和 Priority 文本',
      accessibilityLabel: '每日状态指标，不包含 Daily Note 和 Priority 文本',
    ),
    AiScopeOptionModel(
      scope: AiDataScope.healthMetrics,
      title: '健康指标',
      description: '按日期展示睡眠、运动、饮水、体重和身体评分。',
      includedFields: '睡眠、运动、饮水、体重和身体评分',
      textBoundary: '不包含 Health Note 和外部来源标识',
      accessibilityLabel: '健康指标，不包含 Health Note 和外部来源标识',
    ),
    AiScopeOptionModel(
      scope: AiDataScope.journalReflections,
      title: 'Journal 复盘内容',
      description: '读取最近 7 天的五项结构化复盘回答。',
      includedFields: '完成、消耗、情绪来源、学习和明日调整',
      textBoundary: '可能包含私人情绪、关系和个人经历，开启时需要单次确认',
      accessibilityLabel: 'Journal 复盘内容，可能包含私人情绪、关系和个人经历，需要单次确认',
    ),
  ];

  static String titleFor(AiDataScope scope) {
    return options.firstWhere((option) => option.scope == scope).title;
  }
}
