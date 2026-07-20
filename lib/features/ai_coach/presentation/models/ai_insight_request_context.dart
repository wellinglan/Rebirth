import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final class AiInsightRequestContext {
  const AiInsightRequestContext({required this.reportType, this.targetDate});

  const AiInsightRequestContext.weekly()
    : reportType = AiReportType.weeklyReport,
      targetDate = null;

  const AiInsightRequestContext.daily(this.targetDate)
    : reportType = AiReportType.dailyInsight;

  final AiReportType reportType;
  final String? targetDate;

  bool get isDaily => reportType == AiReportType.dailyInsight;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AiInsightRequestContext &&
            reportType == other.reportType &&
            targetDate == other.targetDate;
  }

  @override
  int get hashCode => Object.hash(reportType, targetDate);
}
