import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final class AiInsightRequestContext {
  const AiInsightRequestContext({
    required this.reportType,
    this.targetDate,
    this.initialScopes = const {},
  });

  const AiInsightRequestContext.weekly()
    : reportType = AiReportType.weeklyReport,
      targetDate = null,
      initialScopes = const {};

  const AiInsightRequestContext.daily(
    this.targetDate, {
    this.initialScopes = const {},
  }) : reportType = AiReportType.dailyInsight;

  final AiReportType reportType;
  final String? targetDate;
  final Set<AiDataScope> initialScopes;

  bool get isDaily => reportType == AiReportType.dailyInsight;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AiInsightRequestContext &&
            reportType == other.reportType &&
            targetDate == other.targetDate &&
            _sameScopes(initialScopes, other.initialScopes);
  }

  @override
  int get hashCode {
    final scopes = initialScopes.map((scope) => scope.contractValue).toList()
      ..sort();
    return Object.hash(reportType, targetDate, Object.hashAll(scopes));
  }

  static bool _sameScopes(Set<AiDataScope> left, Set<AiDataScope> right) =>
      left.length == right.length && left.containsAll(right);
}
