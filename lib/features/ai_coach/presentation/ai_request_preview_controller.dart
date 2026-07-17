import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';

import 'ai_request_preview_mapper.dart';
import 'ai_request_preview_view_state.dart';

final aiRequestPreviewMapperProvider = Provider<AiRequestPreviewMapper>((ref) {
  return const AiRequestPreviewMapper();
});

final aiRequestPreviewControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiRequestPreviewController,
      AiRequestPreviewViewState
    >(AiRequestPreviewController.new);

enum AiScopeToggleResult { updated, journalConfirmationRequired, ignored }

class AiRequestPreviewController
    extends AsyncNotifier<AiRequestPreviewViewState> {
  int _requestSequence = 0;

  @override
  Future<AiRequestPreviewViewState> build() async {
    final authorization = await ref.read(aiConsentRepositoryProvider).read();
    return _initialState(authorization);
  }

  AiScopeToggleResult toggleScope(AiDataScope scope, {required bool selected}) {
    final current = state.asData?.value;
    if (current == null || !scope.supported) return AiScopeToggleResult.ignored;
    if (scope == AiDataScope.journalReflections &&
        selected &&
        !current.journalSelectionConfirmed) {
      return AiScopeToggleResult.journalConfirmationRequired;
    }
    _setScope(current, scope, selected: selected);
    return AiScopeToggleResult.updated;
  }

  void confirmJournalScope() {
    final current = state.asData?.value;
    if (current == null) return;
    final scopes = {...current.selectedScopes, AiDataScope.journalReflections};
    _invalidateRequests();
    state = AsyncData(
      current.copyWith(
        selectedScopes: scopes,
        journalSelectionConfirmed: true,
        clearPreview: true,
        clearReusableReport: true,
        clearBuildError: true,
        isBuilding: false,
      ),
    );
  }

  void cancelJournalScope() {
    final current = state.asData?.value;
    if (current == null) return;
    final scopes = {...current.selectedScopes}
      ..remove(AiDataScope.journalReflections);
    _invalidateRequests();
    state = AsyncData(
      current.copyWith(
        selectedScopes: scopes,
        journalSelectionConfirmed: false,
        clearPreview: true,
        clearReusableReport: true,
        clearBuildError: true,
        isBuilding: false,
      ),
    );
  }

  void clearPreview() {
    final current = state.asData?.value;
    if (current == null) return;
    _invalidateRequests();
    state = AsyncData(
      current.copyWith(
        clearPreview: true,
        clearReusableReport: true,
        clearBuildError: true,
        isBuilding: false,
      ),
    );
  }

  Future<void> reloadAuthorization() async {
    final current = state.asData?.value;
    if (current == null) {
      state = const AsyncLoading<AiRequestPreviewViewState>();
      state = await AsyncValue.guard(build);
      return;
    }
    try {
      final authorization = await ref.read(aiConsentRepositoryProvider).read();
      if (!ref.mounted) return;
      if (!authorization.enabled) {
        _invalidateRequests();
        state = AsyncData(_initialState(authorization));
        return;
      }
      state = AsyncData(current.copyWith(authorization: authorization));
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
    }
  }

  Future<bool> buildPreview() async {
    final current = state.asData?.value;
    if (current == null ||
        !current.authorization.enabled ||
        current.selectedScopes.isEmpty) {
      return false;
    }
    final request = ++_requestSequence;
    final selectedScopes = Set<AiDataScope>.of(current.selectedScopes);
    state = AsyncData(
      current.copyWith(
        isBuilding: true,
        clearPreview: true,
        clearReusableReport: true,
        clearBuildError: true,
      ),
    );

    try {
      final selection = AiDataSelection(
        scopes: selectedScopes,
        persistInputSnapshot: false,
      );
      final bundle = await ref
          .read(aiCoachInputAssemblerProvider)
          .buildWeeklyReport(selection: selection);
      final preview = ref.read(aiRequestPreviewMapperProvider).map(bundle);
      final reusable = await ref
          .read(aiReportRepositoryProvider)
          .findReusableCompleted(
            reportType: bundle.reportType,
            periodStartDate: bundle.periodStartDate,
            periodEndDate: bundle.periodEndDate,
            promptVersion: bundle.promptVersion,
            inputHash: bundle.inputHash,
          );
      final authorization = await ref.read(aiConsentRepositoryProvider).read();
      if (!ref.mounted || request != _requestSequence) return false;
      if (!authorization.enabled) {
        state = AsyncData(_initialState(authorization));
        return false;
      }
      final latest = state.asData?.value;
      if (latest == null ||
          !_sameScopes(latest.selectedScopes, selectedScopes)) {
        return false;
      }
      state = AsyncData(
        latest.copyWith(
          authorization: authorization,
          periodStartDate: bundle.periodStartDate,
          periodEndDate: bundle.periodEndDate,
          promptVersion: bundle.promptVersion,
          bundle: bundle,
          preview: preview,
          reusableCompletedReport: reusable,
          clearReusableReport: reusable == null,
          isBuilding: false,
          clearBuildError: true,
        ),
      );
      return true;
    } catch (_) {
      if (!ref.mounted || request != _requestSequence) return false;
      final latest = state.asData?.value;
      if (latest == null) return false;
      state = AsyncData(
        latest.copyWith(
          isBuilding: false,
          buildError: '暂时无法构建本地预览，请重试。',
          clearPreview: true,
          clearReusableReport: true,
        ),
      );
      return false;
    }
  }

  void _setScope(
    AiRequestPreviewViewState current,
    AiDataScope scope, {
    required bool selected,
  }) {
    final scopes = {...current.selectedScopes};
    selected ? scopes.add(scope) : scopes.remove(scope);
    _invalidateRequests();
    state = AsyncData(
      current.copyWith(
        selectedScopes: scopes,
        journalSelectionConfirmed: scope == AiDataScope.journalReflections
            ? selected && current.journalSelectionConfirmed
            : current.journalSelectionConfirmed,
        clearPreview: true,
        clearReusableReport: true,
        clearBuildError: true,
        isBuilding: false,
      ),
    );
  }

  AiRequestPreviewViewState _initialState(AiDataAuthorization authorization) {
    final dateTimeService = ref.read(dateTimeServiceProvider);
    final now = dateTimeService.currentSnapshot().now;
    final dates = dateTimeService.recentLocalDateRange(
      AiInputContract.weeklyPeriodDays,
      endingAt: now,
    );
    return AiRequestPreviewViewState(
      authorization: authorization,
      selectedScopes: const {},
      periodStartDate: dates.first,
      periodEndDate: dates.last,
      promptVersion: AiInputContract.weeklyPromptVersion,
    );
  }

  void _invalidateRequests() => _requestSequence += 1;

  bool _sameScopes(Set<AiDataScope> left, Set<AiDataScope> right) {
    return left.length == right.length && left.containsAll(right);
  }
}
