import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';

import 'models/ai_request_preview_model.dart';

final class AiRequestPreviewViewState {
  AiRequestPreviewViewState({
    required this.authorization,
    required Set<AiDataScope> selectedScopes,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.promptVersion,
    this.bundle,
    this.preview,
    this.reusableCompletedReport,
    this.isBuilding = false,
    this.buildError,
    this.journalSelectionConfirmed = false,
  }) : selectedScopes = Set<AiDataScope>.unmodifiable(selectedScopes);

  final AiDataAuthorization authorization;
  final Set<AiDataScope> selectedScopes;
  final String periodStartDate;
  final String periodEndDate;
  final String promptVersion;
  final AiCoachInputBundle? bundle;
  final AiRequestPreviewModel? preview;
  final AiReport? reusableCompletedReport;
  final bool isBuilding;
  final String? buildError;
  final bool journalSelectionConfirmed;

  bool get canBuild =>
      authorization.enabled && selectedScopes.isNotEmpty && !isBuilding;

  AiRequestPreviewViewState copyWith({
    AiDataAuthorization? authorization,
    Set<AiDataScope>? selectedScopes,
    String? periodStartDate,
    String? periodEndDate,
    String? promptVersion,
    AiCoachInputBundle? bundle,
    AiRequestPreviewModel? preview,
    AiReport? reusableCompletedReport,
    bool? isBuilding,
    String? buildError,
    bool? journalSelectionConfirmed,
    bool clearPreview = false,
    bool clearReusableReport = false,
    bool clearBuildError = false,
  }) {
    return AiRequestPreviewViewState(
      authorization: authorization ?? this.authorization,
      selectedScopes: selectedScopes ?? this.selectedScopes,
      periodStartDate: periodStartDate ?? this.periodStartDate,
      periodEndDate: periodEndDate ?? this.periodEndDate,
      promptVersion: promptVersion ?? this.promptVersion,
      bundle: clearPreview ? null : bundle ?? this.bundle,
      preview: clearPreview ? null : preview ?? this.preview,
      reusableCompletedReport: clearReusableReport
          ? null
          : reusableCompletedReport ?? this.reusableCompletedReport,
      isBuilding: isBuilding ?? this.isBuilding,
      buildError: clearBuildError ? null : buildError ?? this.buildError,
      journalSelectionConfirmed:
          journalSelectionConfirmed ?? this.journalSelectionConfirmed,
    );
  }
}
