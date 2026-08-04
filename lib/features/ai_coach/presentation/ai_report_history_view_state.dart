import 'models/ai_report_presentation_models.dart';
import 'ai_pending_recovery_controller.dart';

final class AiReportHistoryViewState {
  AiReportHistoryViewState({
    required List<AiReportListItemModel> reports,
    Set<String> deletingReportIds = const {},
    Set<String> archivingReportIds = const {},
    this.isRefreshing = false,
    this.operationError,
    Map<String, AiPendingRecoveryState> pendingRecoveryStates = const {},
  }) : reports = List<AiReportListItemModel>.unmodifiable(reports),
       deletingReportIds = Set<String>.unmodifiable(deletingReportIds),
       archivingReportIds = Set<String>.unmodifiable(archivingReportIds),
       pendingRecoveryStates = Map.unmodifiable(pendingRecoveryStates);

  final List<AiReportListItemModel> reports;
  final Set<String> deletingReportIds;
  final Set<String> archivingReportIds;
  final bool isRefreshing;
  final String? operationError;
  final Map<String, AiPendingRecoveryState> pendingRecoveryStates;

  AiReportHistoryViewState copyWith({
    List<AiReportListItemModel>? reports,
    Set<String>? deletingReportIds,
    Set<String>? archivingReportIds,
    bool? isRefreshing,
    String? operationError,
    bool clearOperationError = false,
    Map<String, AiPendingRecoveryState>? pendingRecoveryStates,
  }) {
    return AiReportHistoryViewState(
      reports: reports ?? this.reports,
      deletingReportIds: deletingReportIds ?? this.deletingReportIds,
      archivingReportIds: archivingReportIds ?? this.archivingReportIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      operationError: clearOperationError
          ? null
          : operationError ?? this.operationError,
      pendingRecoveryStates:
          pendingRecoveryStates ?? this.pendingRecoveryStates,
    );
  }
}
