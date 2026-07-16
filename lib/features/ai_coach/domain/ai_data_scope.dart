enum AiDataScope {
  growthSummary('growth_summary', supported: true),
  todayMetrics('today_metrics', supported: true),
  healthMetrics('health_metrics', supported: true),
  journalReflections('journal_reflections', supported: true),
  activeGoals('active_goals', supported: false);

  const AiDataScope(this.contractValue, {required this.supported});

  final String contractValue;
  final bool supported;
}
