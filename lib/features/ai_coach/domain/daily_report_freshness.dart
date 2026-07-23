import 'ai_data_scope.dart';

enum DailyReportFreshness { current, stale, unavailable }

enum DailyReportFreshnessReason {
  currentHashMatch,
  currentHashMismatch,
  notDailyReport,
  reportNotCompleted,
  missingRebuildMetadata,
  missingStoredHash,
  invalidStoredHash,
  unsupportedReportVersion,
  bundleBuildFailed,
}

final class DailyReportFreshnessResult {
  DailyReportFreshnessResult({
    required this.status,
    required this.reason,
    this.storedInputHash,
    this.currentInputHash,
    this.targetDate,
    Set<AiDataScope>? selectedScopes,
  }) : selectedScopes = selectedScopes == null
           ? null
           : Set<AiDataScope>.unmodifiable(selectedScopes);

  final DailyReportFreshness status;
  final DailyReportFreshnessReason reason;
  final String? storedInputHash;
  final String? currentInputHash;
  final String? targetDate;
  final Set<AiDataScope>? selectedScopes;

  bool get canRebuildPreview =>
      targetDate != null && (selectedScopes?.isNotEmpty ?? false);
}
