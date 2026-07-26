import 'dart:async';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/profile/data/profile_local_data_source.dart';
import 'package:rebirth/features/profile/data/profile_repository_impl.dart';
import 'package:rebirth/features/profile/data/profile_sync_adapter.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_impl.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/sync/application/sync_coordinator.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';

void main() {
  late AppDatabase database;
  late _MemorySessionStore sessionStore;
  late _FakeSyncRemoteDataSource remote;
  late _MemorySyncCursorStore cursorStore;
  late DateTime now;
  late ProfileSyncAdapter adapter;
  late SyncCoordinator coordinator;
  late ProfileSyncRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sessionStore = _MemorySessionStore(session: _registeredSession);
    remote = _FakeSyncRemoteDataSource();
    cursorStore = _MemorySyncCursorStore();
    now = DateTime.utc(2030, 1, 2, 3, 4, 5);
    adapter = ProfileSyncAdapter(database);
    coordinator = SyncCoordinator(
      endpoint: _endpoint,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      adapterRegistry: SyncEntityAdapterRegistry([adapter]),
      endpointProbe: (_) async {},
      dateTimeService: DateTimeService(now: () => now),
      accountScopeGuard: ({required endpoint, required cloudUserId}) async {},
    );
    repository = ProfileSyncRepositoryImpl(
      coordinator: coordinator,
      adapter: adapter,
    );
    await database.bootstrapDao.bootstrap(createUnboundProfile: true);
  });

  tearDown(() => database.close());

  test(
    'pushProfile reads the active profile and creates a Profile item',
    () async {
      final localRepository = ProfileRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => now),
      );
      final profile = await localRepository.saveProfile(
        ProfileSaveData(displayName: 'Local user', growthFocus: 'Research'),
      );
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

      await repository.pushProfile();

      final request = remote.lastPushRequest!;
      expect(request.deviceId, _deviceId);
      expect(request.items, hasLength(1));
      expect(request.items.single.tableName, 'user_profiles');
      expect(request.items.single.recordId, 'profile');
      expect(request.items.single.recordId, isNot(profile.id));
      expect(request.items.single.payload, {
        'display_name': 'Local user',
        'growth_focus': 'Research',
        'timezone_id': 'Etc/UTC',
        'updated_at': now.millisecondsSinceEpoch,
      });
      expect(request.items.single.updatedAt, now.millisecondsSinceEpoch);
      expect(request.items.single.deletedAt, isNull);
      expect(request.items.single.clientVersion, 0);
      expect(cursorStore.value, 0);
    },
  );

  test('pushProfile success writes all local sync metadata', () async {
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    remote.pushResponse = SyncPushResponseDto(
      accepted: [
        SyncedRecord(
          tableName: 'user_profiles',
          recordId: 'profile',
          serverVersion: 9,
        ),
      ],
      conflicts: const [],
    );

    final result = await repository.pushProfile();
    final stored = await database.select(database.userProfiles).getSingle();

    expect(result.pushed, isTrue);
    expect(result.serverVersion, 9);
    expect(stored.syncStatus, 'synced');
    expect(stored.serverVersion, 9);
    expect(stored.lastSyncedAt, now.millisecondsSinceEpoch);
    expect(stored.originDeviceId, bootstrap.localInstallationId);
  });

  test(
    'pushProfile conflict is explicit and keeps the local version',
    () async {
      remote.pushResponse = SyncPushResponseDto(
        accepted: const [],
        conflicts: [
          SyncConflict(
            tableName: 'user_profiles',
            recordId: 'profile',
            serverVersion: 6,
            reason: 'stale_client',
          ),
        ],
      );

      final result = await repository.pushProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(result.conflict, isTrue);
      expect(result.pushed, isFalse);
      expect(result.serverVersion, 6);
      expect(stored.syncStatus, 'conflict');
      expect(stored.serverVersion, isNull);
    },
  );

  test('pushProfile without login does not change the local Profile', () async {
    sessionStore.session = null;
    final before = await database.select(database.userProfiles).getSingle();

    await expectLater(
      repository.pushProfile(),
      throwsA(isA<SyncAuthenticationRequiredException>()),
    );
    final after = await database.select(database.userProfiles).getSingle();

    expect(after.displayName, before.displayName);
    expect(after.updatedAt, before.updatedAt);
    expect(after.syncStatus, before.syncStatus);
  });

  test('pushProfile requires a registered device', () async {
    sessionStore.session = _sessionWithoutDevice;

    expect(
      repository.pushProfile(),
      throwsA(isA<SyncDeviceRegistrationRequiredException>()),
    );
  });

  test(
    'pullProfile no update uses and advances the independent cursor',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await ProfileLocalDataSource(database).updateSyncMetadata(
        userId: bootstrap.activeUserId,
        syncStatus: 'synced',
        serverVersion: 5,
        lastSyncedAt: 100,
        originDeviceId: bootstrap.localInstallationId,
      );
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 5,
        items: const [],
      );
      cursorStore.value = 3;

      final result = await repository.pullProfile();

      expect(result.success, isTrue);
      expect(result.pulled, isFalse);
      expect(result.message, '没有新的 Profile 更新');
      expect(remote.lastPullRequest?.sinceServerVersion, 3);
      expect(remote.lastPullRequest?.tables, ['user_profiles']);
      expect(cursorStore.value, 5);
    },
  );

  test(
    'pullProfile applies the newest cloud Profile to the local UUID',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 8,
        items: [
          _pulledProfile(
            recordId: 'legacy-profile-id',
            serverVersion: 7,
            displayName: 'Older cloud name',
          ),
          _pulledProfile(
            recordId: 'profile',
            serverVersion: 8,
            displayName: 'Newest cloud name',
          ),
        ],
      );

      final result = await repository.pullProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(result.pulled, isTrue);
      expect(stored.id, bootstrap.activeUserId);
      expect(stored.id, isNot('profile'));
      expect(stored.displayName, 'Newest cloud name');
      expect(stored.growthFocus, 'Cloud focus');
      expect(stored.timezoneId, 'Asia/Shanghai');
      expect(stored.updatedAt, 800);
      expect(stored.syncStatus, 'synced');
      expect(stored.serverVersion, 8);
      expect(stored.lastSyncedAt, now.millisecondsSinceEpoch);
      expect(cursorStore.value, 8);
    },
  );

  test(
    'pullProfile detects local pending changes and never overwrites them',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final localDataSource = ProfileLocalDataSource(database);
      await localDataSource.updateSyncMetadata(
        userId: bootstrap.activeUserId,
        syncStatus: 'synced',
        serverVersion: 1,
        lastSyncedAt: 100,
        originDeviceId: bootstrap.localInstallationId,
      );
      await ProfileRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => now),
      ).saveProfile(ProfileSaveData(displayName: 'Unsynced local name'));
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 2,
        items: [_pulledProfile(serverVersion: 2, displayName: 'Cloud name')],
      );

      final result = await repository.pullProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(result.conflict, isTrue);
      expect(result.pulled, isFalse);
      expect(stored.displayName, 'Unsynced local name');
      expect(stored.syncStatus, 'conflict');
      expect(stored.serverVersion, 1);
      expect(cursorStore.value, 0);
    },
  );

  for (final scenario in const [
    (
      name: 'pending with equal updatedAt and lastSyncedAt',
      status: 'pending',
      updatedAt: 100,
      lastSyncedAt: 100,
    ),
    (
      name: 'pending with an updatedAt clock rollback',
      status: 'pending',
      updatedAt: 50,
      lastSyncedAt: 100,
    ),
    (
      name: 'conflict with an older updatedAt',
      status: 'conflict',
      updatedAt: 50,
      lastSyncedAt: 100,
    ),
  ]) {
    test('${scenario.name} always protects local Profile', () async {
      await _setLocalProfileSyncState(
        database,
        displayName: 'Protected local name',
        growthFocus: 'Protected local focus',
        syncStatus: scenario.status,
        updatedAt: scenario.updatedAt,
        lastSyncedAt: scenario.lastSyncedAt,
      );
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 2,
        items: [_pulledProfile(serverVersion: 2, displayName: 'Cloud name')],
      );

      final result = await repository.pullProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(result.conflict, isTrue);
      expect(stored.displayName, 'Protected local name');
      expect(stored.growthFocus, 'Protected local focus');
      expect(stored.syncStatus, 'conflict');
      expect(cursorStore.value, 0);
      expect(cursorStore.writeCalls, 0);
    });
  }

  test('blank local_only Profile accepts the first remote Profile', () async {
    await _setLocalProfileSyncState(
      database,
      displayName: null,
      growthFocus: null,
      syncStatus: 'local_only',
      updatedAt: 50,
      lastSyncedAt: 100,
    );
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 2,
      items: [_pulledProfile(serverVersion: 2, displayName: 'Cloud name')],
    );

    final result = await repository.pullProfile();
    final stored = await database.select(database.userProfiles).getSingle();

    expect(result.pulled, isTrue);
    expect(stored.displayName, 'Cloud name');
    expect(stored.syncStatus, 'synced');
    expect(cursorStore.value, 2);
  });

  test('local_only Profile with content is not silently overwritten', () async {
    await _setLocalProfileSyncState(
      database,
      displayName: 'Imported local name',
      growthFocus: 'Imported local focus',
      syncStatus: 'local_only',
      updatedAt: 50,
      lastSyncedAt: 100,
    );
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 2,
      items: [_pulledProfile(serverVersion: 2, displayName: 'Cloud name')],
    );

    final result = await repository.pullProfile();
    final stored = await database.select(database.userProfiles).getSingle();

    expect(result.conflict, isTrue);
    expect(stored.displayName, 'Imported local name');
    expect(stored.growthFocus, 'Imported local focus');
    expect(stored.syncStatus, 'conflict');
    expect(cursorStore.value, 0);
    expect(cursorStore.writeCalls, 0);
  });

  test('network failure leaves the complete local Profile untouched', () async {
    final localRepository = ProfileRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => now),
    );
    await localRepository.saveProfile(
      ProfileSaveData(displayName: 'Safe local name', growthFocus: 'Local'),
    );
    final before = await database.select(database.userProfiles).getSingle();
    remote.error = const ApiException(
      message: '无法连接开发后端',
      isNetworkError: true,
    );

    await expectLater(repository.pullProfile(), throwsA(isA<SyncException>()));
    final after = await database.select(database.userProfiles).getSingle();

    expect(after.id, before.id);
    expect(after.displayName, before.displayName);
    expect(after.growthFocus, before.growthFocus);
    expect(after.updatedAt, before.updatedAt);
    expect(after.syncStatus, before.syncStatus);
    expect(cursorStore.value, 0);
  });

  test('invalid canonical payload does not advance pull cursor', () async {
    remote.pullResponse = SyncPullResponseDto(
      serverVersion: 4,
      items: [
        PulledSyncItemDto(
          tableName: 'user_profiles',
          recordId: 'profile',
          payload: const {
            'display_name': 'Invalid cloud value',
            'timezone_id': 123,
            'updated_at': 400,
          },
          updatedAt: 400,
          deletedAt: null,
          originDeviceId: '22222222-2222-4222-8222-222222222222',
          serverVersion: 4,
        ),
      ],
    );

    await expectLater(repository.pullProfile(), throwsA(isA<SyncException>()));

    expect(cursorStore.value, 0);
  });

  test(
    'replayed server version is ignored without changing local content',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await ProfileLocalDataSource(database).applyRemoteProfile(
        userId: bootstrap.activeUserId,
        displayName: 'Newer local copy',
        growthFocus: 'Current focus',
        timezoneId: 'Asia/Shanghai',
        updatedAt: 900,
        serverVersion: 9,
        lastSyncedAt: 900,
        originDeviceId: bootstrap.localInstallationId,
      );
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 9,
        items: [
          _pulledProfile(serverVersion: 9, displayName: 'Replayed cloud copy'),
        ],
      );

      final result = await repository.pullProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(result.success, isTrue);
      expect(result.pulled, isFalse);
      expect(stored.displayName, 'Newer local copy');
      expect(stored.updatedAt, 900);
      expect(cursorStore.value, 9);
    },
  );

  test(
    'older server version cannot overwrite a newer synced Profile',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await ProfileLocalDataSource(database).applyRemoteProfile(
        userId: bootstrap.activeUserId,
        displayName: 'Version ten',
        growthFocus: 'Current focus',
        timezoneId: 'Asia/Shanghai',
        updatedAt: 1000,
        serverVersion: 10,
        lastSyncedAt: 1000,
        originDeviceId: bootstrap.localInstallationId,
      );
      remote.pullResponse = SyncPullResponseDto(
        serverVersion: 10,
        items: [_pulledProfile(serverVersion: 8, displayName: 'Version eight')],
      );

      await repository.pullProfile();
      final stored = await database.select(database.userProfiles).getSingle();

      expect(stored.displayName, 'Version ten');
      expect(stored.serverVersion, 10);
      expect(cursorStore.value, 10);
    },
  );

  test(
    'repeated push with no local change does not create another request',
    () async {
      remote.pushResponse = SyncPushResponseDto(
        accepted: [
          SyncedRecord(
            tableName: 'user_profiles',
            recordId: 'profile',
            serverVersion: 1,
          ),
        ],
        conflicts: const [],
      );

      await repository.pushProfile();
      final repeated = await repository.pushProfile();

      expect(remote.pushCalls, 1);
      expect(repeated.pushed, isFalse);
      expect(repeated.message, '没有待上传的 Profile 更新');
    },
  );

  test('repository maps a different active request to SyncException', () async {
    remote.pushCompleter = Completer<SyncPushResponseDto>();

    final activePush = repository.pushProfile();
    await _waitFor(() => remote.pushCalls == 1);

    await expectLater(
      repository.pullProfile(),
      throwsA(
        isA<SyncException>().having(
          (error) => error.message,
          'message',
          '已有同步任务正在进行，请稍后重试。',
        ),
      ),
    );
    expect(remote.pullCalls, 0);

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
    expect((await activePush).pushed, isTrue);
  });

  test('schemaVersion is 5', () {
    expect(database.schemaVersion, 5);
  });

  test(
    'Windows and Android semantics complete a canonical Profile round trip',
    () async {
      final previousWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final windowsDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final androidDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final cloud = _CanonicalProfileCloudDataSource();
      var sharedNow = DateTime.utc(2031, 2, 3, 4, 5, 6);
      addTearDown(() async {
        await windowsDatabase.close();
        await androidDatabase.close();
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarningSetting;
      });
      final windowsBootstrap = await windowsDatabase.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final androidBootstrap = await androidDatabase.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final windowsAdapter = ProfileSyncAdapter(windowsDatabase);
      final androidAdapter = ProfileSyncAdapter(androidDatabase);
      final windowsRepository = ProfileSyncRepositoryImpl(
        coordinator: SyncCoordinator(
          endpoint: _endpoint,
          sessionStore: _MemorySessionStore(
            session: _registeredSessionFor('windows-device'),
          ),
          remoteDataSource: cloud,
          cursorStore: _MemorySyncCursorStore(),
          adapterRegistry: SyncEntityAdapterRegistry([windowsAdapter]),
          endpointProbe: (_) async {},
          dateTimeService: DateTimeService(now: () => sharedNow),
          accountScopeGuard:
              ({required endpoint, required cloudUserId}) async {},
        ),
        adapter: windowsAdapter,
      );
      final androidRepository = ProfileSyncRepositoryImpl(
        coordinator: SyncCoordinator(
          endpoint: _endpoint,
          sessionStore: _MemorySessionStore(
            session: _registeredSessionFor('android-device'),
          ),
          remoteDataSource: cloud,
          cursorStore: _MemorySyncCursorStore(),
          adapterRegistry: SyncEntityAdapterRegistry([androidAdapter]),
          endpointProbe: (_) async {},
          dateTimeService: DateTimeService(now: () => sharedNow),
          accountScopeGuard:
              ({required endpoint, required cloudUserId}) async {},
        ),
        adapter: androidAdapter,
      );
      await ProfileRepositoryImpl(
        database: windowsDatabase,
        dateTimeService: DateTimeService(now: () => sharedNow),
      ).saveProfile(
        ProfileSaveData(
          displayName: 'Windows profile',
          growthFocus: 'Research',
        ),
      );

      await windowsRepository.pushProfile();
      final androidPull = await androidRepository.pullProfile();
      sharedNow = sharedNow.add(const Duration(minutes: 1));
      await ProfileRepositoryImpl(
        database: androidDatabase,
        dateTimeService: DateTimeService(now: () => sharedNow),
      ).saveProfile(
        ProfileSaveData(
          displayName: 'Android profile',
          growthFocus: 'Learning',
        ),
      );
      await androidRepository.pushProfile();
      final windowsPull = await windowsRepository.pullProfile();

      expect(androidPull.updatedProfile?.displayName, 'Windows profile');
      expect(windowsPull.updatedProfile?.displayName, 'Android profile');
      expect(windowsPull.updatedProfile?.growthFocus, 'Learning');
      expect(
        windowsBootstrap.activeUserId,
        isNot(androidBootstrap.activeUserId),
      );
      expect(cloud.recordId, 'profile');
      expect(cloud.pushDeviceIds, ['windows-device', 'android-device']);
    },
  );
}

Future<void> _setLocalProfileSyncState(
  AppDatabase database, {
  required String? displayName,
  required String? growthFocus,
  required String syncStatus,
  required int updatedAt,
  required int lastSyncedAt,
}) async {
  final bootstrap = await database.bootstrapDao.bootstrap(
    createUnboundProfile: true,
  );
  await (database.update(
    database.userProfiles,
  )..where((row) => row.id.equals(bootstrap.activeUserId))).write(
    UserProfilesCompanion(
      displayName: Value(displayName),
      growthFocus: Value(growthFocus),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      serverVersion: const Value(1),
      lastSyncedAt: Value(lastSyncedAt),
      originDeviceId: Value(bootstrap.localInstallationId),
    ),
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

PulledSyncItemDto _pulledProfile({
  String recordId = 'profile',
  required int serverVersion,
  required String displayName,
}) {
  return PulledSyncItemDto(
    tableName: 'user_profiles',
    recordId: recordId,
    payload: {
      'display_name': displayName,
      'growth_focus': 'Cloud focus',
      'timezone_id': 'Asia/Shanghai',
      'updated_at': serverVersion * 100,
    },
    updatedAt: serverVersion * 100,
    deletedAt: null,
    originDeviceId: '22222222-2222-4222-8222-222222222222',
    serverVersion: serverVersion,
  );
}

const _deviceId = '11111111-1111-4111-8111-111111111111';
const _endpoint = 'http://127.0.0.1:8000';
const _user = AuthUser(id: 'cloud-user', displayName: 'Dev user');
const _sessionWithoutDevice = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: _user,
  serverBaseUrl: _endpoint,
);
const _registeredSession = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: _user,
  serverBaseUrl: _endpoint,
  deviceRegistration: DeviceRegistration(deviceId: _deviceId, serverTime: 1),
);

AuthSession _registeredSessionFor(String deviceId) {
  return AuthSession(
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    user: _user,
    serverBaseUrl: _endpoint,
    deviceRegistration: DeviceRegistration(deviceId: deviceId, serverTime: 1),
  );
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore({this.session});

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

final class _FakeSyncRemoteDataSource implements SyncRemoteDataSource {
  SyncPushResponseDto pushResponse = SyncPushResponseDto(
    accepted: const [],
    conflicts: const [],
  );
  SyncPullResponseDto pullResponse = SyncPullResponseDto(
    serverVersion: 0,
    items: const [],
  );
  Object? error;
  Completer<SyncPushResponseDto>? pushCompleter;
  SyncPushRequestDto? lastPushRequest;
  SyncPullRequestDto? lastPullRequest;
  int pushCalls = 0;
  int pullCalls = 0;

  @override
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  }) async {
    pushCalls += 1;
    if (error case final value?) throw value;
    lastPushRequest = request;
    final completer = pushCompleter;
    return completer == null ? pushResponse : completer.future;
  }

  @override
  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  }) async {
    pullCalls += 1;
    if (error case final value?) throw value;
    lastPullRequest = request;
    return pullResponse;
  }
}

final class _CanonicalProfileCloudDataSource implements SyncRemoteDataSource {
  int _serverVersion = 0;
  PulledSyncItemDto? _profile;
  final List<String> pushDeviceIds = [];

  String? get recordId => _profile?.recordId;

  @override
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  }) async {
    final item = request.items.single;
    _serverVersion += 1;
    pushDeviceIds.add(request.deviceId);
    _profile = PulledSyncItemDto(
      tableName: 'user_profiles',
      recordId: 'profile',
      payload: item.payload,
      updatedAt: item.updatedAt,
      deletedAt: item.deletedAt,
      originDeviceId: item.originDeviceId,
      serverVersion: _serverVersion,
    );
    return SyncPushResponseDto(
      accepted: [
        SyncedRecord(
          tableName: 'user_profiles',
          recordId: 'profile',
          serverVersion: _serverVersion,
        ),
      ],
      conflicts: const [],
    );
  }

  @override
  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  }) async {
    final profile = _profile;
    return SyncPullResponseDto(
      serverVersion: _serverVersion,
      items:
          profile != null && profile.serverVersion > request.sinceServerVersion
          ? [profile]
          : const [],
    );
  }
}

final class _MemorySyncCursorStore implements SyncCursorStore {
  int value = 0;
  int writeCalls = 0;

  @override
  Future<int> read({
    required String endpoint,
    required String cloudUserId,
    required String scope,
  }) async => value;

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
