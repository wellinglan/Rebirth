import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/sync/application/sync_coordinator.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';

void main() {
  late _FakeAdapter adapter;
  late _FakeRemoteDataSource remote;
  late _MemoryCursorStore cursorStore;
  late _MemorySessionStore sessionStore;
  late SyncCoordinator coordinator;
  late bool endpointAvailable;
  late Object? accountScopeError;
  late int accountScopeChecks;

  setUp(() {
    adapter = _FakeAdapter();
    remote = _FakeRemoteDataSource();
    cursorStore = _MemoryCursorStore();
    sessionStore = _MemorySessionStore(_registeredSession);
    endpointAvailable = true;
    accountScopeError = null;
    accountScopeChecks = 0;
    coordinator = SyncCoordinator(
      endpoint: _endpoint,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      adapterRegistry: SyncEntityAdapterRegistry([adapter]),
      endpointProbe: (_) async {
        if (!endpointAvailable) {
          throw const ApiException(message: 'offline', isNetworkError: true);
        }
      },
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2030, 1, 2, 3, 4, 5),
      ),
      accountScopeGuard: ({required endpoint, required cloudUserId}) async {
        accountScopeChecks += 1;
        if (accountScopeError case final error?) throw error;
      },
    );
  });

  test('registry rejects an entity without a registered adapter', () {
    final registry = SyncEntityAdapterRegistry([adapter]);

    expect(registry.registeredTypes, [SyncEntityType.profile]);
    expect(
      () => registry.adapterFor(SyncEntityType.plan),
      throwsA(isA<SyncUnsupportedEntityException>()),
    );
  });

  test(
    'cloud user scope mismatch blocks push before local collection',
    () async {
      adapter.pending = [_pushItem()];
      accountScopeError = const AccountScopeMismatchException(
        'cloud user mismatch',
      );

      final result = await coordinator.run(direction: SyncRunDirection.twoWay);

      expect(result.failure?.reason, SyncFailureReason.accountScopeMismatch);
      expect(result.failure?.phase, SyncRunPhase.accountScopeCheck);
      expect(result.failure?.message, 'cloud user mismatch');
      expect(accountScopeChecks, 1);
      expect(adapter.collectCalls, 0);
      expect(remote.pushCalls, 0);
      expect(remote.pullCalls, 0);
      expect(cursorStore.readCalls, 0);
      expect(cursorStore.writeCalls, 0);
      expect(adapter.acknowledgeCalls, 0);
    },
  );

  test(
    'binding endpoint mismatch creates no cursor or conflict work',
    () async {
      accountScopeError = const AccountScopeMismatchException(
        'endpoint binding mismatch',
      );

      final result = await coordinator.run(direction: SyncRunDirection.pull);

      expect(result.failure?.reason, SyncFailureReason.accountScopeMismatch);
      expect(result.failure?.message, 'endpoint binding mismatch');
      expect(accountScopeChecks, 1);
      expect(remote.pullCalls, 0);
      expect(cursorStore.readCalls, 0);
      expect(adapter.applyCalls, 0);
    },
  );

  test(
    'coordinator rejects an unregistered entity before network work',
    () async {
      final result = await coordinator.run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.plan],
      );

      expect(result.failure?.reason, SyncFailureReason.unsupportedEntity);
      expect(remote.pullCalls, 0);
      expect(remote.pushCalls, 0);
    },
  );

  test('unavailable endpoint stops before session and sync requests', () async {
    endpointAvailable = false;

    final result = await coordinator.run(direction: SyncRunDirection.twoWay);

    expect(result.failure?.reason, SyncFailureReason.endpointUnavailable);
    expect(sessionStore.readCalls, 0);
    expect(remote.pullCalls, 0);
    expect(remote.pushCalls, 0);
  });

  test('missing session rejects sync without a request', () async {
    sessionStore.session = null;

    final result = await coordinator.run(direction: SyncRunDirection.twoWay);

    expect(result.failure?.reason, SyncFailureReason.authenticationRequired);
    expect(remote.pullCalls, 0);
    expect(remote.pushCalls, 0);
  });

  test('endpoint-bound session mismatch requires authentication', () async {
    sessionStore.session = _registeredSession.copyWith(
      serverBaseUrl: 'http://other-server:8000',
    );

    final result = await coordinator.run(direction: SyncRunDirection.pull);

    expect(result.failure?.reason, SyncFailureReason.authenticationRequired);
    expect(remote.pullCalls, 0);
  });

  test('missing device registration stops before collect or network', () async {
    sessionStore.session = _sessionWithoutDevice;

    final result = await coordinator.run(direction: SyncRunDirection.twoWay);

    expect(
      result.failure?.reason,
      SyncFailureReason.deviceRegistrationRequired,
    );
    expect(adapter.collectCalls, 0);
    expect(remote.pullCalls, 0);
  });

  test('no pending data still pulls and advances cursor after apply', () async {
    cursorStore.value = 3;
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 5,
      items: const [],
    );

    final result = await coordinator.run(direction: SyncRunDirection.twoWay);

    expect(result.isSuccessful, isTrue);
    expect(remote.pushCalls, 0);
    expect(remote.pullCalls, 1);
    expect(adapter.applyCalls, 1);
    expect(cursorStore.value, 5);
    expect(
      result.phases,
      containsAllInOrder([
        SyncRunPhase.collectPending,
        SyncRunPhase.cursorRead,
        SyncRunPhase.pull,
        SyncRunPhase.apply,
        SyncRunPhase.cursorAdvance,
      ]),
    );
  });

  test('two-way run acknowledges push before pull', () async {
    adapter.pending = [_pushItem()];
    remote.pushResponse = SyncPushResponseDto(
      accepted: [
        SyncedRecord(
          tableName: 'user_profiles',
          recordId: 'profile',
          serverVersion: 4,
        ),
      ],
      conflicts: const [],
    );
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 4,
      items: const [],
    );

    final result = await coordinator.run(direction: SyncRunDirection.twoWay);

    expect(result.isSuccessful, isTrue);
    expect(remote.pushCalls, 1);
    expect(adapter.acknowledgeCalls, 1);
    expect(remote.pullCalls, 1);
    expect(
      result.phases,
      containsAllInOrder([
        SyncRunPhase.push,
        SyncRunPhase.acknowledgePush,
        SyncRunPhase.pull,
      ]),
    );
  });

  test(
    'push failure is structured and prevents pull for that entity',
    () async {
      adapter.pending = [_pushItem()];
      remote.pushError = const ApiException(
        message: 'push unavailable',
        isNetworkError: true,
      );

      final result = await coordinator.run(direction: SyncRunDirection.twoWay);

      expect(result.failure?.reason, SyncFailureReason.pushFailed);
      expect(
        result.resultFor(SyncEntityType.profile)?.status,
        SyncEntityStatus.failed,
      );
      expect(result.failure?.message, '数据上传失败，本地记录未受影响。');
      expect(remote.pullCalls, 0);
      expect(cursorStore.writeCalls, 0);
    },
  );

  test(
    'pull failure preserves a successful push as partial progress',
    () async {
      adapter.pending = [_pushItem()];
      remote.pushResponse = SyncPushResponseDto(
        accepted: [
          SyncedRecord(
            tableName: 'user_profiles',
            recordId: 'profile',
            serverVersion: 4,
          ),
        ],
        conflicts: const [],
      );
      remote.pullError = const ApiException(
        message: 'pull unavailable',
        isNetworkError: true,
      );

      final result = await coordinator.run(direction: SyncRunDirection.twoWay);
      final profileResult = result.resultFor(SyncEntityType.profile)!;

      expect(result.failure?.reason, SyncFailureReason.pullFailed);
      expect(result.isPartialSuccess, isTrue);
      expect(profileResult.status, SyncEntityStatus.failed);
      expect(profileResult.pushedCount, 1);
      expect(cursorStore.writeCalls, 0);
    },
  );

  test('invalid local operation is rejected before push', () async {
    adapter.pending = const [
      SyncPushItem(
        entityType: SyncEntityType.profile,
        operation: SyncOperation.delete,
        recordId: 'profile',
        payload: null,
        updatedAt: 100,
        deletedAt: null,
        originDeviceId: 'installation',
        clientVersion: 0,
      ),
    ];

    final result = await coordinator.run(direction: SyncRunDirection.push);

    expect(result.failure?.reason, SyncFailureReason.payloadInvalid);
    expect(remote.pushCalls, 0);
  });

  test('pull failure never advances cursor', () async {
    cursorStore.value = 6;
    remote.pullError = const ApiException(
      message: 'pull unavailable',
      isNetworkError: true,
    );

    final result = await coordinator.run(direction: SyncRunDirection.pull);

    expect(result.failure?.reason, SyncFailureReason.pullFailed);
    expect(cursorStore.value, 6);
    expect(cursorStore.writeCalls, 0);
  });

  test('apply failure never advances cursor', () async {
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 7,
      items: [_pulledItem(serverVersion: 7)],
    );
    adapter.applyError = StateError('write failed');

    final result = await coordinator.run(direction: SyncRunDirection.pull);

    expect(result.failure?.reason, SyncFailureReason.applyFailed);
    expect(cursorStore.value, 0);
    expect(cursorStore.writeCalls, 0);
  });

  test('conflict is explicit and never advances cursor', () async {
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 7,
      items: [_pulledItem(serverVersion: 7)],
    );
    adapter.applyResult = const SyncEntityResult(
      entityType: SyncEntityType.profile,
      status: SyncEntityStatus.conflict,
      message: 'conflict',
      conflictCount: 1,
      serverVersion: 7,
    );

    final result = await coordinator.run(direction: SyncRunDirection.pull);

    expect(result.failure?.reason, SyncFailureReason.conflict);
    expect(cursorStore.writeCalls, 0);
  });

  test('negative cursor fails before pull and is never overwritten', () async {
    cursorStore.value = -1;

    final result = await coordinator.run(direction: SyncRunDirection.pull);

    expect(result.failure?.reason, SyncFailureReason.cursorFailed);
    expect(result.failure?.phase, SyncRunPhase.cursorRead);
    expect(result.failure?.message, '本地同步游标读取失败，已停止拉取。');
    expect(cursorStore.readCalls, 1);
    expect(remote.pullCalls, 0);
    expect(cursorStore.writeCalls, 0);
    expect(cursorStore.value, -1);
  });

  test('identical overlapping runs reuse one future and one pull', () async {
    remote.pullCompleter = Completer<SyncPullResponseDto>();

    final first = coordinator.run(direction: SyncRunDirection.pull);
    final second = coordinator.run(direction: SyncRunDirection.pull);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(remote.pullCalls, 1);

    remote.pullCompleter!.complete(
      SyncPullResponseDto(serverVersion: 0, items: const []),
    );
    final results = await Future.wait([first, second]);

    expect(identical(results.first, results.last), isTrue);
    expect(coordinator.isRunning, isFalse);
  });

  test('entity order does not change an active request identity', () async {
    final planAdapter = _FakeAdapter(entityType: SyncEntityType.plan);
    coordinator = SyncCoordinator(
      endpoint: _endpoint,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      adapterRegistry: SyncEntityAdapterRegistry([adapter, planAdapter]),
      endpointProbe: (_) async {},
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2030, 1, 2, 3, 4, 5),
      ),
      accountScopeGuard: ({required endpoint, required cloudUserId}) async {},
    );
    remote.pullCompleter = Completer<SyncPullResponseDto>();

    final first = coordinator.run(
      direction: SyncRunDirection.pull,
      entityTypes: const [SyncEntityType.profile, SyncEntityType.plan],
    );
    final second = coordinator.run(
      direction: SyncRunDirection.pull,
      entityTypes: const [SyncEntityType.plan, SyncEntityType.profile],
    );

    expect(identical(first, second), isTrue);
    await _waitUntil(() => remote.pullCalls == 1);
    remote.pullCompleter!.complete(
      SyncPullResponseDto(serverVersion: 0, items: const []),
    );
    await Future.wait([first, second]);

    expect(remote.pullCalls, 2);
    expect(adapter.applyCalls, 1);
    expect(planAdapter.applyCalls, 1);
  });

  test('duplicate entity types execute one adapter and one pull', () async {
    final result = await coordinator.run(
      direction: SyncRunDirection.pull,
      entityTypes: const [SyncEntityType.profile, SyncEntityType.profile],
    );

    expect(result.isSuccessful, isTrue);
    expect(result.entityResults, hasLength(1));
    expect(remote.pullCalls, 1);
    expect(adapter.applyCalls, 1);
    expect(cursorStore.readCalls, 1);
  });

  test('pull requested during push returns syncInProgress only', () async {
    adapter.pending = [_pushItem()];
    remote.pushCompleter = Completer<SyncPushResponseDto>();

    final push = coordinator.run(direction: SyncRunDirection.push);
    await _waitUntil(() => remote.pushCalls == 1);
    final pull = coordinator.run(direction: SyncRunDirection.pull);
    final rejected = await pull;

    expect(identical(push, pull), isFalse);
    expect(rejected.failure?.reason, SyncFailureReason.syncInProgress);
    expect(rejected.failure?.message, '已有同步任务正在进行，请稍后重试。');
    expect(remote.pushCalls, 1);
    expect(remote.pullCalls, 0);
    expect(cursorStore.readCalls, 0);
    expect(adapter.applyCalls, 0);

    remote.pushCompleter!.complete(
      SyncPushResponseDto(
        accepted: [
          SyncedRecord(
            tableName: 'user_profiles',
            recordId: 'profile',
            serverVersion: 1,
          ),
        ],
        conflicts: const [],
      ),
    );
    expect((await push).isSuccessful, isTrue);
  });

  test('push requested during pull returns syncInProgress only', () async {
    remote.pullCompleter = Completer<SyncPullResponseDto>();

    final pull = coordinator.run(direction: SyncRunDirection.pull);
    await _waitUntil(() => remote.pullCalls == 1);
    final push = coordinator.run(direction: SyncRunDirection.push);
    final rejected = await push;

    expect(identical(pull, push), isFalse);
    expect(rejected.failure?.reason, SyncFailureReason.syncInProgress);
    expect(remote.pullCalls, 1);
    expect(remote.pushCalls, 0);
    expect(cursorStore.readCalls, 1);
    expect(adapter.collectCalls, 0);

    remote.pullCompleter!.complete(
      SyncPullResponseDto(serverVersion: 0, items: const []),
    );
    expect((await pull).isSuccessful, isTrue);
  });

  test('different entity scope is rejected without extra work', () async {
    final planAdapter = _FakeAdapter(entityType: SyncEntityType.plan);
    coordinator = SyncCoordinator(
      endpoint: _endpoint,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      adapterRegistry: SyncEntityAdapterRegistry([adapter, planAdapter]),
      endpointProbe: (_) async {},
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2030, 1, 2, 3, 4, 5),
      ),
      accountScopeGuard: ({required endpoint, required cloudUserId}) async {},
    );
    remote.pullCompleter = Completer<SyncPullResponseDto>();

    final active = coordinator.run(
      direction: SyncRunDirection.pull,
      entityTypes: const [SyncEntityType.profile],
    );
    await _waitUntil(() => remote.pullCalls == 1);
    final rejected = await coordinator.run(
      direction: SyncRunDirection.pull,
      entityTypes: const [SyncEntityType.profile, SyncEntityType.plan],
    );

    expect(rejected.failure?.reason, SyncFailureReason.syncInProgress);
    expect(remote.pullCalls, 1);
    expect(cursorStore.readCalls, 1);
    expect(planAdapter.applyCalls, 0);

    remote.pullCompleter!.complete(
      SyncPullResponseDto(serverVersion: 0, items: const []),
    );
    expect((await active).isSuccessful, isTrue);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

SyncPushItem _pushItem() {
  return const SyncPushItem(
    entityType: SyncEntityType.profile,
    operation: SyncOperation.upsert,
    recordId: 'profile',
    payload: _TestPayload('local'),
    updatedAt: 100,
    deletedAt: null,
    originDeviceId: 'installation',
    clientVersion: 0,
  );
}

PulledSyncItemDto _pulledItem({required int serverVersion}) {
  return PulledSyncItemDto(
    tableName: 'user_profiles',
    recordId: 'profile',
    payload: const {'value': 'remote'},
    updatedAt: 200,
    deletedAt: null,
    originDeviceId: 'remote-installation',
    serverVersion: serverVersion,
  );
}

const _endpoint = 'http://127.0.0.1:8000';
const _user = AuthUser(id: 'cloud-user', displayName: 'Dev user');
const _sessionWithoutDevice = AuthSession(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: _user,
  serverBaseUrl: _endpoint,
);
const _registeredSession = AuthSession(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: _user,
  serverBaseUrl: _endpoint,
  deviceRegistration: DeviceRegistration(deviceId: 'device-id', serverTime: 1),
);

final class _TestPayload implements SyncEntityPayload {
  const _TestPayload(this.value);

  final String value;
}

final class _FakeAdapter implements SyncEntityAdapter {
  _FakeAdapter({this.entityType = SyncEntityType.profile});

  List<SyncPushItem> pending = const [];
  Object? applyError;
  SyncEntityResult applyResult = const SyncEntityResult(
    entityType: SyncEntityType.profile,
    status: SyncEntityStatus.noChanges,
    message: 'no changes',
  );
  int collectCalls = 0;
  int acknowledgeCalls = 0;
  int applyCalls = 0;

  @override
  final SyncEntityType entityType;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    collectCalls += 1;
    return pending;
  }

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) {
    return {'value': (payload as _TestPayload).value};
  }

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) {
    return SyncChange(
      entityType: entityType,
      operation: deletedAt == null
          ? SyncOperation.upsert
          : SyncOperation.delete,
      recordId: recordId,
      payload: _TestPayload(payload['value']! as String),
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      originDeviceId: originDeviceId,
      serverVersion: serverVersion,
    );
  }

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) async {
    acknowledgeCalls += 1;
    return SyncEntityResult(
      entityType: entityType,
      status: SyncEntityStatus.succeeded,
      message: 'pushed',
      pushedCount: accepted.length,
      serverVersion: accepted.first.serverVersion,
    );
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
  }) async {
    applyCalls += 1;
    if (applyError case final error?) throw error;
    return applyResult;
  }
}

final class _FakeRemoteDataSource implements SyncRemoteDataSource {
  SyncPushResponseDto pushResponse = SyncPushResponseDto(
    accepted: const [],
    conflicts: const [],
  );
  SyncPullResponseDto pullResponse = SyncPullResponseDto(
    serverVersion: 0,
    items: const [],
  );
  Object? pushError;
  Object? pullError;
  Completer<SyncPushResponseDto>? pushCompleter;
  Completer<SyncPullResponseDto>? pullCompleter;
  int pushCalls = 0;
  int pullCalls = 0;

  @override
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  }) async {
    pushCalls += 1;
    if (pushError case final error?) throw error;
    final completer = pushCompleter;
    return completer == null ? pushResponse : completer.future;
  }

  @override
  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  }) async {
    pullCalls += 1;
    if (pullError case final error?) throw error;
    final completer = pullCompleter;
    return completer == null ? pullResponse : completer.future;
  }
}

final class _MemoryCursorStore implements SyncCursorStore {
  int value = 0;
  int readCalls = 0;
  int writeCalls = 0;

  @override
  Future<int> read({
    required String endpoint,
    required String cloudUserId,
    required String scope,
  }) async {
    readCalls += 1;
    return value;
  }

  @override
  Future<void> write({
    required String endpoint,
    required String cloudUserId,
    required String scope,
    required int serverVersion,
  }) async {
    writeCalls += 1;
    value = serverVersion;
  }

  @override
  Future<void> clear({
    required String endpoint,
    required String cloudUserId,
    String? scope,
  }) async {
    value = 0;
  }
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;
  int readCalls = 0;

  @override
  Future<AuthSession?> read() async {
    readCalls += 1;
    return session;
  }

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
