enum AiReportType {
  dailyInsight('daily_insight'),
  weeklyReport('weekly_report'),
  monthlyReflection('monthly_reflection'),
  tomorrowSuggestion('tomorrow_suggestion'),
  trendExplanation('trend_explanation');

  const AiReportType(this.databaseValue);

  final String databaseValue;

  static AiReportType fromDatabaseValue(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}
