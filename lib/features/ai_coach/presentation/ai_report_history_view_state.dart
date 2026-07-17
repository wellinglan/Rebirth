import 'models/ai_report_presentation_models.dart';
import 'ai_pending_recovery_controller.dart';

final class AiReportHistoryViewState {
  AiReportHistoryViewState({
    required List<AiReportListItemModel> reports,
    Set<String> deletingReportIds = const {},
    this.isRefreshing = false,
    this.operationError,
    Map<String, AiPendingRecoveryState> pendingRecoveryStates = const {},
  }) : reports = List<AiReportListItemModel>.unmodifiable(reports),
       deletingReportIds = Set<String>.unmodifiable(deletingReportIds),
       pendingRecoveryStates = Map.unmodifiable(pendingRecoveryStates);

  final List<AiReportListItemModel> reports;
  final Set<String> deletingReportIds;
  final bool isRefreshing;
  final String? operationError;
  final Map<String, AiPendingRecoveryState> pendingRecoveryStates;

  AiReportHistoryViewState copyWith({
    List<AiReportListItemModel>? reports,
    Set<String>? deletingReportIds,
    bool? isRefreshing,
    String? operationError,
    bool clearOperationError = false,
    Map<String, AiPendingRecoveryState>? pendingRecoveryStates,
  }) {
    return AiReportHistoryViewState(
      reports: reports ?? this.reports,
      deletingReportIds: deletingReportIds ?? this.deletingReportIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      operationError: clearOperationError
          ? null
          : operationError ?? this.operationError,
      pendingRecoveryStates:
          pendingRecoveryStates ?? this.pendingRecoveryStates,
    );
  }
}
