import 'ai_data_scope.dart';
import 'ai_report_type.dart';

abstract final class AiInputContract {
  static const schemaVersion = 1;
  static const dailyPromptVersion = 'daily-insight-v1';
  static const weeklyPromptVersion = 'weekly-report-v1';
  static const weeklyPeriodDays = 7;

  static bool isSupportedReportType(AiReportType reportType) =>
      reportType == AiReportType.dailyInsight ||
      reportType == AiReportType.weeklyReport;

  static String promptVersionFor(AiReportType reportType) =>
      switch (reportType) {
        AiReportType.dailyInsight => dailyPromptVersion,
        AiReportType.weeklyReport => weeklyPromptVersion,
        _ => throw ArgumentError.value(reportType, 'reportType'),
      };

  static Set<AiDataScope> supportedScopesFor(AiReportType reportType) =>
      switch (reportType) {
        AiReportType.dailyInsight => const {
          AiDataScope.todayMetrics,
          AiDataScope.healthMetrics,
          AiDataScope.journalReflections,
        },
        AiReportType.weeklyReport => const {
          AiDataScope.growthSummary,
          AiDataScope.todayMetrics,
          AiDataScope.healthMetrics,
          AiDataScope.journalReflections,
        },
        _ => const {},
      };
}
