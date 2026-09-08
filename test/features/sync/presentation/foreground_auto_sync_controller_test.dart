import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/sync/application/foreground_auto_sync_state.dart';
import 'package:rebirth/features/sync/application/local_sync_mutation_signal.dart';
import 'package:rebirth/features/sync/application/sync_execution_gate.dart';
import 'package:rebirth/features/sync/application/sync_execution_providers.dart';
import 'package:rebirth/features/sync/data/cloud_sync_preference_provider.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/cloud_sync_preference_repository.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';
import 'package:rebirth/features/sync/presentation/foreground_auto_sync_controller.dart';

const _endpoint = 'https://sync.example.test';

void main() {
  test(
    'defaults off, enabling runs all, and disabling stops new work',
    () async {
      final harness = await _Harness.create(enabled: false);
      addTearDown(harness.dispose);

      await harness.activate();
      expect(harness.state.status, ForegroundAutoSyncStatus.disabled);
      expect(harness.calls, isEmpty);

      expect(await harness.controller.setEnabled(true), isTrue);
      await _eventually(() => harness.calls.length == 1);
      expect(harness.preferences.values['local-a'], isTrue);
      expect(harness.calls, hasLength(1));
      expect(harness.calls.single, SyncModuleId.values);

      expect(await harness.controller.setEnabled(false), isTrue);
      harness.signal(SyncModuleId.today);
      await _wait(const Duration(milliseconds: 80));
      expect(harness.calls, hasLength(1));
      expect(harness.state.status, ForegroundAutoSyncStatus.disabled);
    },
  );

  test('local mutations debounce and coalesce by module', () async {
    final harness = await _Harness.create(enabled: true);
    addTearDown(harness.dispose);
    await harness.activate();
    harness.calls.clear();

    harness.signal(SyncModuleId.health);
    harness.signal(SyncModuleId.plan);
    harness.signal(SyncModuleId.plan);
    await _wait(const Duration(milliseconds: 10));
    expect(harness.calls, isEmpty);

    await _eventually(() => harness.calls.length == 1);
    expect(harness.calls, hasLength(1));
    expect(harness.calls.single.toSet(), {
      SyncModuleId.plan,
      SyncModuleId.health,
    });
  });

  test('dirty changes during a run produce one follow-up batch', () async {
    final held = Completer<SyncAllExecutionResult>();
    var postStartupCalls = 0;
    final harness = await _Harness.create(
      enabled: true,
      onRun: (modules, call) {
        if (call == 0) return Future.value(_success(modules));
        postStartupCalls += 1;
        if (postStartupCalls == 1) return held.future;
        return Future.value(_success(modules));
      },
    );
    addTearDown(harness.dispose);
    await harness.activate();
    harness.calls.clear();

    harness.signal(SyncModuleId.today);
    await _eventually(() => harness.calls.length == 1);
    expect(harness.calls, hasLength(1));

    harness.signal(SyncModuleId.today);
    harness.signal(SyncModuleId.health);
    harness.signal(SyncModuleId.health);
    held.complete(_success(const [SyncModuleId.today]));
    await _eventually(() => harness.calls.length == 2);

    expect(harness.calls, hasLength(2));
    expect(harness.calls.last.toSet(), {
      SyncModuleId.today,
      SyncModuleId.health,
    });
  });

  test('background pauses scheduling and resume reconciles once', () async {
    final harness = await _Harness.create(
      enabled: true,
      timing: const ForegroundAutoSyncTiming(
        mutationDebounce: Duration(milliseconds: 30),
        reconciliationInterval: Duration(milliseconds: 100),
        resumeCooldown: Duration.zero,
        retryDelays: [Duration(milliseconds: 30)],
      ),
    );
    addTearDown(harness.dispose);
    await harness.activate();
    harness.calls.clear();

    harness.controller.handleLifecycleState(AppLifecycleState.paused);
    harness.signal(SyncModuleId.today);
    await _wait(const Duration(milliseconds: 150));
    expect(harness.calls, isEmpty);

    harness.controller.handleLifecycleState(AppLifecycleState.resumed);
    await _eventually(() => harness.calls.length == 1);
    expect(harness.calls, hasLength(1));

    harness.calls.clear();
    await _eventually(() => harness.calls.length == 1);
    expect(harness.calls, hasLength(1));
  });

  test('transient failure retries once and success clears backoff', () async {
    final harness = await _Harness.create(
      enabled: true,
      onRun: (modules, call) => Future.value(
        call == 0
            ? _failure(modules, SyncFailureReason.endpointUnavailable)
            : _success(modules),
      ),
    );
    addTearDown(harness.dispose);

    harness.controller.handleLifecycleState(AppLifecycleState.resumed);
    await harness.controller.handleAuthState(AsyncData(harness.authState));
    await _eventually(
      () =>
          harness.calls.length == 1 &&
          harness.state.status == ForegroundAutoSyncStatus.retryScheduled,
    );
    expect(harness.state.status, ForegroundAutoSyncStatus.retryScheduled);

    await _eventually(
      () =>
          harness.calls.length == 2 &&
          harness.state.status == ForegroundAutoSyncStatus.idle,
    );
    expect(harness.calls, hasLength(2));
    expect(harness.state.status, ForegroundAutoSyncStatus.idle);
    expect(harness.state.lastSuccessAt, isNotNull);
  });

  test(
    'manual work takes priority then resumes unrelated retry work',
    () async {
      final harness = await _Harness.create(
        enabled: true,
        onRun: (modules, call) => Future.value(
          call == 0
              ? _failure(modules, SyncFailureReason.endpointUnavailable)
              : _success(modules),
        ),
      );
      addTearDown(harness.dispose);
      harness.controller.handleLifecycleState(AppLifecycleState.resumed);
      await harness.controller.handleAuthState(AsyncData(harness.authState));
      await _eventually(
        () => harness.state.status == ForegroundAutoSyncStatus.retryScheduled,
      );

      final manual = Completer<void>();
      harness.controller.prepareForManualSync([SyncModuleId.profile]);
      final manualRun = harness.container
          .read(syncExecutionGateProvider)
          .run(
            origin: SyncExecutionOrigin.manual,
            operation: () => manual.future,
          );
      await _wait(const Duration(milliseconds: 50));
      expect(harness.calls, hasLength(1));

      manual.complete();
      await manualRun;
      await _eventually(() => harness.calls.length == 2);
      expect(harness.calls.last, isNot(contains(SyncModuleId.profile)));
      expect(harness.calls.last, contains(SyncModuleId.today));
    },
  );

  test('apply failure is not retried automatically', () async {
    final harness = await _Harness.create(
      enabled: true,
      onRun: (modules, _) =>
          Future.value(_failure(modules, SyncFailureReason.applyFailed)),
    );
    addTearDown(harness.dispose);
    await harness.activate();

    expect(harness.state.status, ForegroundAutoSyncStatus.failed);
    await _wait(const Duration(milliseconds: 100));
    expect(harness.calls, hasLength(1));
  });

  test('an unresolved conflict blocks only its module', () async {
    final harness = await _Harness.create(
      enabled: true,
      conflicts: [_conflict(SyncEntityType.today)],
    );
    addTearDown(harness.dispose);
    await harness.activate();

    expect(harness.calls, hasLength(1));
    expect(harness.calls.single, isNot(contains(SyncModuleId.today)));
    expect(harness.calls.single, contains(SyncModuleId.health));
    expect(harness.state.status, ForegroundAutoSyncStatus.needsAttention);

    harness.signal(SyncModuleId.today);
    await _wait(const Duration(milliseconds: 80));
    expect(harness.calls, hasLength(1));
  });

  test('logout clears queued work before its debounce fires', () async {
    final harness = await _Harness.create(enabled: true);
    addTearDown(harness.dispose);
    await harness.activate();
    harness.calls.clear();

    harness.signal(SyncModuleId.plan);
    await harness.controller.handleAuthState(
      const AsyncData(AppAuthState.signedOut()),
    );
    await _wait(const Duration(milliseconds: 80));

    expect(harness.calls, isEmpty);
    expect(harness.state.enabled, isFalse);
    expect(harness.state.status, ForegroundAutoSyncStatus.unavailable);
  });

  test('legacy review and missing device never schedule a batch', () async {
    final legacy = await _Harness.create(enabled: true);
    addTearDown(legacy.dispose);
    legacy.controller.handleLifecycleState(AppLifecycleState.resumed);
    await legacy.controller.handleAuthState(
      AsyncData(
        legacy.authState.copyWithEligibility(
          AccountSyncEligibility.legacyReviewRequired,
        ),
      ),
    );
    await _wait(const Duration(milliseconds: 40));
    expect(legacy.calls, isEmpty);

    final unregistered = await _Harness.create(
      enabled: true,
      registered: false,
    );
    addTearDown(unregistered.dispose);
    await unregistered.activate();
    expect(unregistered.calls, isEmpty);
    expect(
      unregistered.state.status,
      ForegroundAutoSyncStatus.waitingForAccount,
    );
  });

  test(
    'account switch invalidates the old result and runs new scope',
    () async {
      final held = Completer<SyncAllExecutionResult>();
      final harness = await _Harness.create(
        enabled: true,
        preferenceValues: {'local-a': true, 'local-b': true},
        onRun: (modules, call) =>
            call == 0 ? held.future : Future.value(_success(modules)),
      );
      addTearDown(harness.dispose);
      harness.controller.handleLifecycleState(AppLifecycleState.resumed);
      await harness.controller.handleAuthState(AsyncData(harness.authState));
      await _eventually(() => harness.calls.length == 1);
      expect(harness.calls, hasLength(1));

      await harness.manager.updateSession(_session('cloud-b'));
      await harness.controller.handleAuthState(
        AsyncData(_readyAuth(localUserId: 'local-b', cloudUserId: 'cloud-b')),
      );
      held.complete(_success(SyncModuleId.values));
      await _eventually(
        () =>
            harness.calls.length == 2 &&
            harness.state.status == ForegroundAutoSyncStatus.idle,
      );

      expect(harness.calls, hasLength(2));
      expect(harness.state.status, ForegroundAutoSyncStatus.idle);
      expect(harness.state.lastSuccessAt, isNotNull);
    },
  );
}

typedef _RunHandler =
    Future<SyncAllExecutionResult> Function(
      List<SyncModuleId> modules,
      int call,
    );

final class _Harness {
  _Harness._({
    required this.container,
    required this.manager,
    required this.preferences,
    required this.calls,
  });

  final ProviderContainer container;
  final AuthSessionManager manager;
  final _MemoryPreferenceRepository preferences;
  final List<List<SyncModuleId>> calls;

  ForegroundAutoSyncController get controller =>
      container.read(foregroundAutoSyncControllerProvider.notifier);
  ForegroundAutoSyncState get state =>
      container.read(foregroundAutoSyncControllerProvider);
  LocalSyncMutationSignal get signal =>
      container.read(localSyncMutationSignalProvider);
  AppAuthState get authState => _readyAuth();

  static Future<_Harness> create({
    required bool enabled,
    bool registered = true,
    Map<String, bool>? preferenceValues,
    List<SyncConflictRecord> conflicts = const [],
    _RunHandler? onRun,
    ForegroundAutoSyncTiming timing = const ForegroundAutoSyncTiming(
      mutationDebounce: Duration(milliseconds: 30),
      reconciliationInterval: Duration(hours: 1),
      resumeCooldown: Duration.zero,
      retryDelays: [Duration(milliseconds: 30)],
    ),
  }) async {
    final sessionStore = _MemorySessionStore(
      _session('cloud-a', registered: registered),
    );
    final manager = AuthSessionManager.forTesting(sessionStore: sessionStore);
    await manager.initialize();
    final preferences = _MemoryPreferenceRepository({
      'local-a': enabled,
      ...?preferenceValues,
    });
    final calls = <List<SyncModuleId>>[];
    var runCount = 0;
    late final ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        authSessionManagerProvider.overrideWithValue(manager),
        cloudSyncPreferenceRepositoryProvider.overrideWithValue(preferences),
        foregroundAutoSyncTimingProvider.overrideWithValue(timing),
        activeSyncConflictListProvider.overrideWith((ref) async => conflicts),
        foregroundAutoSyncBatchRunnerProvider.overrideWithValue((
          moduleIds,
          onProgress,
        ) {
          final modules = moduleIds.toList(growable: false);
          final call = runCount;
          runCount += 1;
          calls.add(modules);
          return onRun?.call(modules, call) ?? Future.value(_success(modules));
        }),
      ],
    );
    container.read(foregroundAutoSyncControllerProvider);
    return _Harness._(
      container: container,
      manager: manager,
      preferences: preferences,
      calls: calls,
    );
  }

  Future<void> activate() async {
    controller.handleLifecycleState(AppLifecycleState.resumed);
    await controller.handleAuthState(AsyncData(authState));
    await _eventually(
      () => switch (state.status) {
        ForegroundAutoSyncStatus.loadingPreference ||
        ForegroundAutoSyncStatus.pending ||
        ForegroundAutoSyncStatus.syncing => false,
        _ => true,
      },
    );
  }

  void dispose() => container.dispose();
}

final class _MemoryPreferenceRepository
    implements CloudSyncPreferenceRepository {
  _MemoryPreferenceRepository(this.values);

  final Map<String, bool> values;

  @override
  Future<bool> readEnabled(String localUserId) async =>
      values[localUserId] ?? false;

  @override
  Future<bool> setEnabled({
    required String localUserId,
    required bool enabled,
  }) async {
    values[localUserId] = enabled;
    return enabled;
  }
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;
}

AppAuthState _readyAuth({
  String localUserId = 'local-a',
  String cloudUserId = 'cloud-a',
}) {
  return AppAuthState(
    status: AppAuthStatus.authenticated,
    localUserId: localUserId,
    cloudUserId: cloudUserId,
    accountScope: CloudAccountScope(
      endpointKey: _endpoint,
      cloudUserId: cloudUserId,
    ),
    syncEligibility: AccountSyncEligibility.ready,
    verificationStatus: AccountOwnershipVerificationStatus.verified,
  );
}

extension on AppAuthState {
  AppAuthState copyWithEligibility(AccountSyncEligibility eligibility) {
    return AppAuthState(
      status: status,
      localUserId: localUserId,
      cloudUserId: cloudUserId,
      accountScope: accountScope,
      syncEligibility: eligibility,
      verificationStatus: verificationStatus,
    );
  }
}

AuthSession _session(String cloudUserId, {bool registered = true}) {
  return AuthSession(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    user: AuthUser(id: cloudUserId, displayName: null),
    serverBaseUrl: _endpoint,
    deviceRegistration: registered
        ? const DeviceRegistration(deviceId: 'device-a', serverTime: 1)
        : null,
  );
}

SyncAllExecutionResult _success(Iterable<SyncModuleId> modules) {
  return SyncAllExecutionResult(
    moduleResults: [
      for (final module in modules)
        SyncModuleExecutionResult(
          moduleId: module,
          status: SyncModuleExecutionStatus.succeeded,
          startedAt: 1,
          completedAt: 2,
          entityResults: const [],
          userFacingMessage: '同步完成',
        ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

SyncAllExecutionResult _failure(
  Iterable<SyncModuleId> modules,
  SyncFailureReason reason,
) {
  final first = modules.first;
  return SyncAllExecutionResult(
    moduleResults: [
      SyncModuleExecutionResult(
        moduleId: first,
        status: SyncModuleExecutionStatus.failed,
        startedAt: 1,
        completedAt: 2,
        entityResults: const [],
        userFacingMessage: '同步失败',
        failureReason: reason,
      ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

SyncConflictRecord _conflict(SyncEntityType type) {
  const snapshot = SyncConflictSnapshot(
    payload: null,
    updatedAt: 1,
    deletedAt: null,
    serverVersion: 1,
    originDeviceId: 'device-a',
  );
  return SyncConflictRecord(
    id: 'conflict-${type.wireName}',
    scope: const SyncConflictScope(
      localUserId: 'local-a',
      endpointKey: _endpoint,
      cloudUserId: 'cloud-a',
    ),
    entityType: type,
    recordId: 'record-a',
    localSnapshot: snapshot,
    remoteSnapshot: snapshot,
    remoteOperation: SyncConflictOperation.upsert,
    detectedAt: 1,
    lastSeenAt: 1,
    resolutionStatus: SyncConflictResolutionStatus.unresolved,
    resolvedAt: null,
  );
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

Future<void> _eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out waiting for the automatic sync state to settle.');
    }
    await _wait(const Duration(milliseconds: 5));
  }
}
