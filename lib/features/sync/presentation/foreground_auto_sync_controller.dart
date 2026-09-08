import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/sync/data/cloud_sync_preference_provider.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';

import '../application/foreground_auto_sync_state.dart';
import '../application/local_sync_mutation_signal.dart';
import '../application/sync_all_orchestrator.dart';
import '../application/sync_execution_gate.dart';
import '../application/sync_execution_providers.dart';
import '../domain/sync_module.dart';
import '../domain/sync_models.dart';
import 'sync_module_providers.dart';

typedef ForegroundAutoSyncBatchRunner =
    Future<SyncAllExecutionResult> Function(
      Iterable<SyncModuleId> moduleIds,
      SyncModuleProgressCallback? onProgress,
    );

final foregroundAutoSyncTimingProvider = Provider<ForegroundAutoSyncTiming>(
  (ref) => const ForegroundAutoSyncTiming(),
);

final foregroundAutoSyncBatchRunnerProvider =
    Provider<ForegroundAutoSyncBatchRunner>((ref) {
      return (moduleIds, onProgress) => ref
          .read(syncAllOrchestratorProvider)
          .run(moduleIds: moduleIds, onProgress: onProgress);
    });

final foregroundAutoSyncControllerProvider =
    NotifierProvider<ForegroundAutoSyncController, ForegroundAutoSyncState>(
      ForegroundAutoSyncController.new,
    );

class ForegroundAutoSyncController extends Notifier<ForegroundAutoSyncState> {
  Timer? _periodicTimer;
  Timer? _drainTimer;
  Timer? _retryTimer;
  AppAuthState? _authState;
  String? _scopeKey;
  String? _localUserId;
  bool _enabled = false;
  bool _isForeground = false;
  bool _isPreparing = false;
  bool _isRunning = false;
  bool _pendingFull = false;
  bool _waitingForGate = false;
  int _scopeGeneration = 0;
  int _retryAttempt = 0;
  int? _lastStartedAt;
  int? _automaticPauseUntil;
  int _sessionAutomaticallyReconciledCount = 0;
  ForegroundAutoSyncTrigger _pendingTrigger =
      ForegroundAutoSyncTrigger.sessionReady;
  final Set<SyncModuleId> _pendingModules = {};

  ForegroundAutoSyncTiming get _timing =>
      ref.read(foregroundAutoSyncTimingProvider);

  @override
  ForegroundAutoSyncState build() {
    final mutationSubscription = ref
        .read(localSyncMutationBusProvider)
        .events
        .listen(markLocalMutation);
    ref.onDispose(mutationSubscription.cancel);
    ref.onDispose(_dispose);
    return const ForegroundAutoSyncState();
  }

  Future<void> handleAuthState(AsyncValue<AppAuthState> authValue) async {
    final authState = authValue.value;
    if (authState == null) {
      _clearAccountScope(message: authValue.isLoading ? '正在确认登录状态' : '登录状态不可用');
      return;
    }

    final localUserId = authState.localUserId;
    final cloudUserId = authState.cloudUserId;
    final accountScope = authState.accountScope;
    if (localUserId == null ||
        cloudUserId == null ||
        accountScope == null ||
        !authState.canAccessBusiness) {
      _clearAccountScope(message: _accountStatusMessage(authState));
      return;
    }

    final scopeKey = '${accountScope.endpointKey}|$cloudUserId|$localUserId';
    _authState = authState;
    if (_scopeKey == scopeKey) {
      _updateSchedulingForEligibility(
        trigger: ForegroundAutoSyncTrigger.sessionReady,
      );
      return;
    }

    _scopeGeneration += 1;
    final generation = _scopeGeneration;
    _cancelScheduledWork(clearPending: true);
    _scopeKey = scopeKey;
    _localUserId = localUserId;
    _enabled = false;
    state = ForegroundAutoSyncState(
      status: ForegroundAutoSyncStatus.loadingPreference,
      isForeground: _isForeground,
      message: '正在读取此设备的自动同步设置',
    );

    try {
      final enabled = await ref
          .read(cloudSyncPreferenceRepositoryProvider)
          .readEnabled(localUserId);
      if (!ref.mounted ||
          generation != _scopeGeneration ||
          _scopeKey != scopeKey) {
        return;
      }
      _enabled = enabled;
      state = state.copyWith(
        status: enabled
            ? ForegroundAutoSyncStatus.idle
            : ForegroundAutoSyncStatus.disabled,
        enabled: enabled,
        clearMessage: true,
      );
      _updateSchedulingForEligibility(
        trigger: ForegroundAutoSyncTrigger.sessionReady,
      );
    } catch (_) {
      if (!ref.mounted ||
          generation != _scopeGeneration ||
          _scopeKey != scopeKey) {
        return;
      }
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.failed,
        enabled: false,
        message: '无法读取自动同步设置',
      );
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final localUserId = _localUserId;
    final scopeKey = _scopeKey;
    if (localUserId == null || scopeKey == null || state.isSavingPreference) {
      return false;
    }

    state = state.copyWith(isSavingPreference: true, clearMessage: true);
    try {
      await ref
          .read(cloudSyncPreferenceRepositoryProvider)
          .setEnabled(localUserId: localUserId, enabled: enabled);
      if (!ref.mounted || _scopeKey != scopeKey) return false;
      _enabled = enabled;
      state = state.copyWith(
        enabled: enabled,
        isSavingPreference: false,
        status: enabled
            ? ForegroundAutoSyncStatus.idle
            : ForegroundAutoSyncStatus.disabled,
        clearCurrentModule: true,
        clearRetryAt: true,
        clearMessage: true,
      );
      if (enabled) {
        _retryAttempt = 0;
        _automaticPauseUntil = null;
        _updateSchedulingForEligibility(
          trigger: ForegroundAutoSyncTrigger.enabled,
        );
      } else {
        _cancelScheduledWork(clearPending: true);
      }
      return true;
    } catch (_) {
      if (ref.mounted && _scopeKey == scopeKey) {
        state = state.copyWith(
          isSavingPreference: false,
          message: enabled ? '开启自动同步失败，请重试' : '关闭自动同步失败，请重试',
        );
      }
      return false;
    }
  }

  void handleLifecycleState(AppLifecycleState lifecycleState) {
    final wasForeground = _isForeground;
    _isForeground = lifecycleState == AppLifecycleState.resumed;
    state = state.copyWith(isForeground: _isForeground);

    if (!_isForeground) {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      _drainTimer?.cancel();
      _drainTimer = null;
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }

    _startPeriodicTimer();
    if (!wasForeground && _enabled) {
      final now = _now();
      final elapsed = _lastStartedAt == null ? null : now - _lastStartedAt!;
      final cooldown = _timing.resumeCooldown.inMilliseconds;
      final delay = elapsed == null || elapsed >= cooldown
          ? Duration.zero
          : Duration(milliseconds: cooldown - elapsed);
      _queueFull(ForegroundAutoSyncTrigger.resumed, delay: delay);
    } else if (_hasPendingWork) {
      _scheduleDrain(Duration.zero);
    }
  }

  void markLocalMutation(SyncModuleId moduleId) {
    if (!_enabled || _scopeKey == null) return;
    _pendingModules.add(moduleId);
    _pendingTrigger = ForegroundAutoSyncTrigger.localMutation;
    _publishPending();
    if (_isForeground && _canRunAutomatically && _retryTimer == null) {
      _scheduleDrain(_timing.mutationDebounce);
    }
  }

  void prepareForManualSync(Iterable<SyncModuleId> moduleIds) {
    final ids = moduleIds.toSet();
    if (_pendingFull) {
      _pendingFull = false;
      _pendingModules.addAll(
        ref
            .read(syncModuleRegistryProvider)
            .orderedModules
            .map((module) => module.moduleId)
            .where((moduleId) => !ids.contains(moduleId)),
      );
    }
    _pendingModules.removeAll(ids);
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _automaticPauseUntil = null;
    if (!_hasPendingWork) {
      _drainTimer?.cancel();
      _drainTimer = null;
      if (!_isRunning) _publishIdle();
    } else if (_enabled && _isForeground && _canRunAutomatically) {
      // The zero-delay drain yields to the caller so the manual run can claim
      // the shared gate first, then resumes any unrelated automatic work.
      _scheduleDrain(Duration.zero);
    }
  }

  void recordManualCompletion({
    required int conflictCount,
    int automaticallyReconciledCount = 0,
  }) {
    if (!_enabled || _scopeKey == null || _isRunning) return;
    _sessionAutomaticallyReconciledCount += automaticallyReconciledCount;
    state = state.copyWith(
      conflictCount: conflictCount,
      automaticallyReconciledCount: _sessionAutomaticallyReconciledCount,
      status: conflictCount > 0
          ? ForegroundAutoSyncStatus.needsAttention
          : ForegroundAutoSyncStatus.idle,
      message: conflictCount > 0 ? '部分数据需要你在待处理问题中选择版本' : null,
      clearMessage: conflictCount == 0,
    );
  }

  void _updateSchedulingForEligibility({
    required ForegroundAutoSyncTrigger trigger,
  }) {
    if (!_enabled) {
      _cancelScheduledWork(clearPending: true);
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.disabled,
        enabled: false,
        clearCurrentModule: true,
        clearRetryAt: true,
        clearMessage: true,
      );
      return;
    }
    if (!_canRunAutomatically) {
      _periodicTimer?.cancel();
      _periodicTimer = null;
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.waitingForAccount,
        enabled: true,
        message: _accountStatusMessage(_authState),
      );
      return;
    }
    _startPeriodicTimer();
    if (_isForeground) _queueFull(trigger);
  }

  bool get _canRunAutomatically {
    final authState = _authState;
    if (authState == null || !authState.canUseCloudSync) return false;
    final session = ref.read(authSessionManagerProvider).state.session;
    final scope = authState.accountScope;
    if (session == null ||
        scope == null ||
        session.user.id != authState.cloudUserId) {
      return false;
    }
    try {
      final sessionEndpoint = ref
          .read(serverEndpointValidatorProvider)
          .normalize(session.serverBaseUrl);
      return scope.cloudUserId == session.user.id &&
          scope.endpointKey == sessionEndpoint &&
          session.deviceRegistration?.isRegistered == true;
    } catch (_) {
      return false;
    }
  }

  bool get _hasPendingWork => _pendingFull || _pendingModules.isNotEmpty;

  void _queueFull(
    ForegroundAutoSyncTrigger trigger, {
    Duration delay = Duration.zero,
  }) {
    if (!_enabled || _scopeKey == null) return;
    _pendingFull = true;
    _pendingTrigger = trigger;
    _publishPending();
    if (_isForeground && _canRunAutomatically && _retryTimer == null) {
      _scheduleDrain(delay);
    }
  }

  void _scheduleDrain(Duration delay) {
    if (_isRunning || _isPreparing || !_hasPendingWork) return;
    _drainTimer?.cancel();
    _drainTimer = Timer(delay, () {
      _drainTimer = null;
      unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    if (_isRunning ||
        _isPreparing ||
        !_enabled ||
        !_isForeground ||
        !_canRunAutomatically ||
        !_hasPendingWork) {
      return;
    }
    final now = _now();
    final pauseUntil = _automaticPauseUntil;
    if (pauseUntil != null && now < pauseUntil) return;

    final gate = ref.read(syncExecutionGateProvider);
    if (gate.isRunning) {
      _waitForExecutionGate(gate);
      return;
    }

    _isPreparing = true;
    final generation = _scopeGeneration;
    final scopeKey = _scopeKey;
    try {
      final conflictPreflight = await _readConflictPreflight();
      final blockedModules = conflictPreflight.blockedModules;
      if (!ref.mounted ||
          generation != _scopeGeneration ||
          scopeKey != _scopeKey) {
        return;
      }

      final registry = ref.read(syncModuleRegistryProvider);
      final requested = _pendingFull
          ? registry.orderedModules.map((module) => module.moduleId).toSet()
          : _pendingModules.toSet();
      final selected = requested.difference(blockedModules);
      _pendingFull = false;
      _pendingModules.removeAll(requested);

      if (selected.isEmpty) {
        state = state.copyWith(
          status: blockedModules.isEmpty
              ? ForegroundAutoSyncStatus.idle
              : ForegroundAutoSyncStatus.needsAttention,
          pendingModuleCount: 0,
          conflictCount: conflictPreflight.manualConflictCount,
          automaticallyReconciledCount: _sessionAutomaticallyReconciledCount,
          message: blockedModules.isEmpty ? null : '部分数据需要你在待处理问题中选择版本',
          clearMessage: blockedModules.isEmpty,
        );
        return;
      }

      final trigger = _pendingTrigger;
      late Future<SyncAllExecutionResult> execution;
      try {
        execution = gate.run(
          origin: SyncExecutionOrigin.automatic,
          operation: () => ref.read(foregroundAutoSyncBatchRunnerProvider)(
            selected,
            _onProgress,
          ),
        );
      } on SyncExecutionInProgressException {
        _pendingModules.addAll(selected);
        _waitForExecutionGate(gate);
        return;
      }

      _isRunning = true;
      _lastStartedAt = _now();
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.syncing,
        pendingModuleCount: _pendingModules.length,
        lastTrigger: trigger,
        lastAttemptAt: _lastStartedAt,
        clearRetryAt: true,
        clearMessage: true,
      );

      try {
        final result = await execution;
        if (!ref.mounted ||
            generation != _scopeGeneration ||
            scopeKey != _scopeKey) {
          return;
        }
        _handleResult(
          result,
          selected,
          existingConflictCount: conflictPreflight.manualConflictCount,
        );
      } catch (_) {
        if (!ref.mounted ||
            generation != _scopeGeneration ||
            scopeKey != _scopeKey) {
          return;
        }
        _handleUnexpectedFailure(selected);
      } finally {
        _isRunning = false;
      }
    } finally {
      _isPreparing = false;
      if (_hasPendingWork &&
          _enabled &&
          _isForeground &&
          _canRunAutomatically &&
          _retryTimer == null) {
        _scheduleDrain(Duration.zero);
      }
    }
  }

  void _handleResult(
    SyncAllExecutionResult result,
    Set<SyncModuleId> requested, {
    required int existingConflictCount,
  }) {
    if (!_enabled || _scopeKey == null) {
      _publishIdle();
      return;
    }
    final conflictCount = result.moduleResults.fold<int>(
      existingConflictCount,
      (total, module) => total + module.conflictCount,
    );
    _sessionAutomaticallyReconciledCount += result.automaticallyReconciledCount;
    final queued = result.moduleResults
        .where(
          (module) => module.failureReason == SyncFailureReason.syncInProgress,
        )
        .map((module) => module.moduleId)
        .toSet();
    if (queued.isNotEmpty) {
      _pendingModules.addAll(queued);
      _pendingTrigger = ForegroundAutoSyncTrigger.localMutation;
      _publishPending();
      _scheduleDrain(_timing.mutationDebounce);
      return;
    }
    final retryable = result.moduleResults
        .where((module) => _isRetryable(module.failureReason))
        .map((module) => module.moduleId)
        .toSet();
    if (retryable.isNotEmpty &&
        result.moduleResults.any((m) => m.isGlobalFailure)) {
      retryable.addAll(requested);
    }

    if (retryable.isNotEmpty) {
      _scheduleRetry(retryable, conflictCount: conflictCount);
      return;
    }

    _retryAttempt = 0;
    _automaticPauseUntil = null;
    final hasFailure = result.hasFailure;
    final now = _now();
    state = state.copyWith(
      status: conflictCount > 0
          ? ForegroundAutoSyncStatus.needsAttention
          : hasFailure
          ? ForegroundAutoSyncStatus.failed
          : ForegroundAutoSyncStatus.idle,
      pendingModuleCount: _pendingModules.length,
      conflictCount: conflictCount,
      automaticallyReconciledCount: _sessionAutomaticallyReconciledCount,
      lastSuccessAt: !hasFailure && conflictCount == 0 ? now : null,
      clearCurrentModule: true,
      message: conflictCount > 0
          ? '部分数据需要你在待处理问题中选择版本'
          : hasFailure
          ? '自动同步未完全完成，本地数据已保留'
          : null,
      clearMessage: !hasFailure && conflictCount == 0,
    );
  }

  void _handleUnexpectedFailure(Set<SyncModuleId> requested) {
    if (!_enabled || _scopeKey == null) {
      _publishIdle();
      return;
    }
    _scheduleRetry(requested, conflictCount: state.conflictCount);
  }

  void _scheduleRetry(Set<SyncModuleId> modules, {required int conflictCount}) {
    _pendingModules.addAll(modules);
    if (_retryAttempt >= _timing.retryDelays.length) {
      final pause = _timing.retryDelays.isEmpty
          ? _timing.reconciliationInterval
          : _timing.retryDelays.last;
      _automaticPauseUntil = _now() + pause.inMilliseconds;
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.failed,
        pendingModuleCount: _pendingModules.length,
        conflictCount: conflictCount,
        clearCurrentModule: true,
        clearRetryAt: true,
        message: '自动同步暂时不可用，本地数据已保留；稍后将在前台重试',
      );
      return;
    }

    final delay = _timing.retryDelays[_retryAttempt];
    _retryAttempt += 1;
    final retryAt = _now() + delay.inMilliseconds;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _pendingTrigger = ForegroundAutoSyncTrigger.retry;
      _scheduleDrain(Duration.zero);
    });
    state = state.copyWith(
      status: ForegroundAutoSyncStatus.retryScheduled,
      pendingModuleCount: _pendingModules.length,
      conflictCount: conflictCount,
      retryAt: retryAt,
      clearCurrentModule: true,
      message: '网络暂不可用，本地数据已保留，将在前台重试',
    );
  }

  bool _isRetryable(SyncFailureReason? reason) {
    return switch (reason) {
      SyncFailureReason.endpointUnavailable ||
      SyncFailureReason.pushFailed ||
      SyncFailureReason.pullFailed ||
      SyncFailureReason.cursorFailed ||
      SyncFailureReason.unexpected => true,
      _ => false,
    };
  }

  Future<_ConflictPreflight> _readConflictPreflight() async {
    try {
      final scope = await ref.read(syncConflictScopeProvider.future);
      final conflicts = await ref.read(activeSyncConflictListProvider.future);
      final registry = ref.read(syncModuleRegistryProvider);
      if (scope == null) {
        return _ConflictPreflight(
          blockedModules: conflicts
              .map((item) => registry.moduleForEntity(item.entityType))
              .whereType<SyncModuleId>()
              .toSet(),
          manualConflictCount: conflicts.length,
        );
      }
      final blocked = <SyncModuleId>{};
      var manualCount = 0;
      final reconciler = ref.read(syncConflictReconciliationRunnerProvider);
      for (final conflict in conflicts) {
        final canAttempt = await reconciler.canAttemptAutomatically(
          scope,
          conflict,
        );
        if (canAttempt) continue;
        manualCount += 1;
        final module = registry.moduleForEntity(conflict.entityType);
        if (module != null) blocked.add(module);
      }
      return _ConflictPreflight(
        blockedModules: blocked,
        manualConflictCount: manualCount,
      );
    } catch (_) {
      final conflicts = await ref.read(activeSyncConflictListProvider.future);
      final registry = ref.read(syncModuleRegistryProvider);
      return _ConflictPreflight(
        blockedModules: conflicts
            .map((item) => registry.moduleForEntity(item.entityType))
            .whereType<SyncModuleId>()
            .toSet(),
        manualConflictCount: conflicts.length,
      );
    }
  }

  void _waitForExecutionGate(SyncExecutionGate gate) {
    if (_waitingForGate) return;
    _waitingForGate = true;
    unawaited(
      gate.whenIdle.whenComplete(() {
        if (!ref.mounted) return;
        _waitingForGate = false;
        if (_hasPendingWork && _enabled && _isForeground) {
          _scheduleDrain(Duration.zero);
        }
      }),
    );
  }

  void _onProgress(
    SyncModuleId currentModule,
    int completedModules,
    List<SyncModuleExecutionResult> results,
  ) {
    if (!_isRunning && !_isPreparing) return;
    state = state.copyWith(currentModule: currentModule);
  }

  void _startPeriodicTimer() {
    if (!_enabled || !_isForeground || !_canRunAutomatically) return;
    _periodicTimer ??= Timer.periodic(_timing.reconciliationInterval, (_) {
      final pauseUntil = _automaticPauseUntil;
      if (pauseUntil != null && _now() < pauseUntil) return;
      if (pauseUntil != null) {
        _automaticPauseUntil = null;
        _retryAttempt = 0;
      }
      _queueFull(ForegroundAutoSyncTrigger.periodic);
    });
  }

  void _publishPending() {
    if (!_isRunning) {
      state = state.copyWith(
        status: ForegroundAutoSyncStatus.pending,
        pendingModuleCount: _pendingFull
            ? ref.read(syncModuleRegistryProvider).orderedModules.length
            : _pendingModules.length,
        clearMessage: true,
      );
    }
  }

  void _publishIdle() {
    state = state.copyWith(
      status: _enabled
          ? ForegroundAutoSyncStatus.idle
          : ForegroundAutoSyncStatus.disabled,
      pendingModuleCount: 0,
      clearCurrentModule: true,
      clearRetryAt: true,
      clearMessage: true,
    );
  }

  void _clearAccountScope({required String message}) {
    _scopeGeneration += 1;
    _cancelScheduledWork(clearPending: true);
    _authState = null;
    _scopeKey = null;
    _localUserId = null;
    _enabled = false;
    _retryAttempt = 0;
    _automaticPauseUntil = null;
    _sessionAutomaticallyReconciledCount = 0;
    state = ForegroundAutoSyncState(
      status: ForegroundAutoSyncStatus.unavailable,
      isForeground: _isForeground,
      message: message,
    );
  }

  void _cancelScheduledWork({required bool clearPending}) {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _drainTimer?.cancel();
    _drainTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _waitingForGate = false;
    if (clearPending) {
      _pendingFull = false;
      _pendingModules.clear();
    }
  }

  void _dispose() {
    _scopeGeneration += 1;
    _cancelScheduledWork(clearPending: true);
  }

  int _now() =>
      ref.read(dateTimeServiceProvider).currentSnapshot().utcMilliseconds;

  String _accountStatusMessage(AppAuthState? authState) {
    if (authState == null) return '请先登录后使用自动同步';
    return switch (authState.status) {
      AppAuthStatus.bindingRequired => '请先确认本地数据归属',
      AppAuthStatus.sessionRejected ||
      AppAuthStatus.refreshOutcomeUnknown => '登录状态不可用，请重新登录',
      AppAuthStatus.authenticated || AppAuthStatus.authenticatedOffline
          when authState.syncEligibility != null &&
              !authState.canUseCloudSync =>
        '当前账号尚未完成云同步资格验证',
      AppAuthStatus.authenticated ||
      AppAuthStatus.authenticatedOffline => '请先注册当前设备',
      _ => '请先登录后使用自动同步',
    };
  }
}

final class _ConflictPreflight {
  const _ConflictPreflight({
    required this.blockedModules,
    required this.manualConflictCount,
  });

  final Set<SyncModuleId> blockedModules;
  final int manualConflictCount;
}
