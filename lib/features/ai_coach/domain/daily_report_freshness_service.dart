import 'ai_coach_input_assembler.dart';
import 'ai_data_selection.dart';
import 'ai_input_contract.dart';
import 'ai_report.dart';
import 'ai_report_status.dart';
import 'ai_report_type.dart';
import 'daily_report_freshness.dart';

final class DailyReportFreshnessService {
  const DailyReportFreshnessService({required this.inputAssembler});

  static const supportedMetadataVersion = 1;

  final AiCoachInputAssembler inputAssembler;

  Future<DailyReportFreshnessResult> evaluate(AiReport report) async {
    if (report.reportType != AiReportType.dailyInsight) {
      return _unavailable(report, DailyReportFreshnessReason.notDailyReport);
    }
    if (report.status != AiReportStatus.completed) {
      return _unavailable(
        report,
        DailyReportFreshnessReason.reportNotCompleted,
      );
    }
    if (report.inputHash.trim().isEmpty) {
      return _unavailable(report, DailyReportFreshnessReason.missingStoredHash);
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(report.inputHash)) {
      return _unavailable(report, DailyReportFreshnessReason.invalidStoredHash);
    }
    if (report.inputMetadataVersion != supportedMetadataVersion ||
        report.inputSchemaVersion != AiInputContract.schemaVersion ||
        report.promptVersion != AiInputContract.dailyPromptVersion) {
      final missingMetadata =
          report.inputMetadataVersion == null ||
          report.inputSchemaVersion == null ||
          report.selectedScopes == null;
      return _unavailable(
        report,
        missingMetadata
            ? DailyReportFreshnessReason.missingRebuildMetadata
            : DailyReportFreshnessReason.unsupportedReportVersion,
      );
    }
    final scopes = report.selectedScopes!;
    if (scopes.isEmpty ||
        scopes.any(
          (scope) => !AiInputContract.supportedScopesFor(
            AiReportType.dailyInsight,
          ).contains(scope),
        )) {
      return _unavailable(
        report,
        DailyReportFreshnessReason.missingRebuildMetadata,
      );
    }

    try {
      final bundle = await inputAssembler.buildDailyInsight(
        targetDate: report.periodStartDate,
        selection: AiDataSelection(scopes: scopes),
      );
      if (bundle.reportType != AiReportType.dailyInsight ||
          bundle.periodStartDate != report.periodStartDate ||
          bundle.periodEndDate != report.periodEndDate ||
          bundle.promptVersion != report.promptVersion ||
          bundle.selection.scopes.length != scopes.length ||
          !bundle.selection.scopes.containsAll(scopes)) {
        return _unavailable(
          report,
          DailyReportFreshnessReason.unsupportedReportVersion,
        );
      }
      final matches = bundle.inputHash == report.inputHash;
      return DailyReportFreshnessResult(
        status: matches
            ? DailyReportFreshness.current
            : DailyReportFreshness.stale,
        reason: matches
            ? DailyReportFreshnessReason.currentHashMatch
            : DailyReportFreshnessReason.currentHashMismatch,
        storedInputHash: report.inputHash,
        currentInputHash: bundle.inputHash,
        targetDate: report.periodStartDate,
        selectedScopes: scopes,
      );
    } catch (_) {
      return _unavailable(report, DailyReportFreshnessReason.bundleBuildFailed);
    }
  }

  DailyReportFreshnessResult _unavailable(
    AiReport report,
    DailyReportFreshnessReason reason,
  ) {
    return DailyReportFreshnessResult(
      status: DailyReportFreshness.unavailable,
      reason: reason,
      storedInputHash: report.inputHash.trim().isEmpty
          ? null
          : report.inputHash,
      targetDate: report.reportType == AiReportType.dailyInsight
          ? report.periodStartDate
          : null,
      selectedScopes: report.selectedScopes,
    );
  }
}
