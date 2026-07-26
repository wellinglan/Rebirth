import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';

import 'app_auth_controller.dart';

enum LegacyDataResolutionAction {
  idle,
  bindingLegacy,
  creatingFreshSpace,
  signingOut,
  failed,
}

final class LegacyDataResolutionState {
  const LegacyDataResolutionState({
    required this.summaries,
    this.action = LegacyDataResolutionAction.idle,
    this.message,
  });

  final List<LegacyLocalDataSpaceSummary> summaries;
  final LegacyDataResolutionAction action;
  final String? message;

  bool get isBusy =>
      action == LegacyDataResolutionAction.bindingLegacy ||
      action == LegacyDataResolutionAction.creatingFreshSpace ||
      action == LegacyDataResolutionAction.signingOut;

  LegacyDataResolutionState copyWith({
    LegacyDataResolutionAction? action,
    String? message,
    bool clearMessage = false,
  }) {
    return LegacyDataResolutionState(
      summaries: summaries,
      action: action ?? this.action,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final legacyDataResolutionControllerProvider =
    AsyncNotifierProvider<
      LegacyDataResolutionController,
      LegacyDataResolutionState
    >(LegacyDataResolutionController.new);

class LegacyDataResolutionController
    extends AsyncNotifier<LegacyDataResolutionState> {
  final Map<String, String> _localUserIdsBySelectionKey = {};

  @override
  Future<LegacyDataResolutionState> build() async {
    final auth = ref.read(appAuthStateProvider).value;
    if (auth?.status != AppAuthStatus.bindingRequired) {
      return const LegacyDataResolutionState(summaries: []);
    }
    final candidates = await ref
        .read(accountBoundaryRepositoryProvider)
        .listLegacyDataSpaces();
    _localUserIdsBySelectionKey
      ..clear()
      ..addEntries(
        candidates.map(
          (candidate) =>
              MapEntry(candidate.summary.selectionKey, candidate.localUserId),
        ),
      );
    return LegacyDataResolutionState(
      summaries: List.unmodifiable(
        candidates.map((candidate) => candidate.summary),
      ),
    );
  }

  Future<bool> claim(String selectionKey) async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    final localUserId = _localUserIdsBySelectionKey[selectionKey];
    if (localUserId == null) {
      state = AsyncData(
        current.copyWith(
          action: LegacyDataResolutionAction.failed,
          message: '所选本地数据空间已变化，请刷新后重试。',
        ),
      );
      return false;
    }
    state = AsyncData(
      current.copyWith(
        action: LegacyDataResolutionAction.bindingLegacy,
        clearMessage: true,
      ),
    );
    try {
      await ref
          .read(appAuthControllerProvider.notifier)
          .claimLegacyDataSpace(localUserId);
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          action: LegacyDataResolutionAction.failed,
          message: _messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<bool> createFreshSpace() async {
    final current = state.value;
    if (current == null || current.isBusy) return false;
    state = AsyncData(
      current.copyWith(
        action: LegacyDataResolutionAction.creatingFreshSpace,
        clearMessage: true,
      ),
    );
    try {
      await ref.read(appAuthControllerProvider.notifier).createFreshDataSpace();
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          action: LegacyDataResolutionAction.failed,
          message: _messageFor(error),
        ),
      );
      return false;
    }
  }

  Future<void> logout() async {
    final current = state.value;
    if (current == null || current.isBusy) return;
    state = AsyncData(
      current.copyWith(
        action: LegacyDataResolutionAction.signingOut,
        clearMessage: true,
      ),
    );
    await ref.read(appAuthControllerProvider.notifier).logout();
  }

  Future<void> retry() async {
    state = const AsyncLoading<LegacyDataResolutionState>();
    state = await AsyncValue.guard(build);
  }

  String _messageFor(Object error) {
    if (error is AccountSessionRejectedException) return error.message;
    if (error is AccountScopeMismatchException) return error.message;
    return '本地数据归属操作未完成，任何数据都没有被删除。请重试。';
  }
}
