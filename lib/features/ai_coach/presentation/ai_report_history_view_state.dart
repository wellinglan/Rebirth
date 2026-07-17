import 'models/ai_report_presentation_models.dart';

final class AiReportHistoryViewState {
  AiReportHistoryViewState({
    required List<AiReportListItemModel> reports,
    Set<String> deletingReportIds = const {},
    this.isRefreshing = false,
    this.operationError,
  }) : reports = List<AiReportListItemModel>.unmodifiable(reports),
       deletingReportIds = Set<String>.unmodifiable(deletingReportIds);

  final List<AiReportListItemModel> reports;
  final Set<String> deletingReportIds;
  final bool isRefreshing;
  final String? operationError;

  AiReportHistoryViewState copyWith({
    List<AiReportListItemModel>? reports,
    Set<String>? deletingReportIds,
    bool? isRefreshing,
    String? operationError,
    bool clearOperationError = false,
  }) {
    return AiReportHistoryViewState(
      reports: reports ?? this.reports,
      deletingReportIds: deletingReportIds ?? this.deletingReportIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      operationError: clearOperationError
          ? null
          : operationError ?? this.operationError,
    );
  }
}
