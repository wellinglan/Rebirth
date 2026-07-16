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
import 'package:rebirth/features/profile/data/profile_sync_repository_impl.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';

void main() {
  late AppDatabase database;
  late _MemorySessionStore sessionStore;
  late _FakeSyncRemoteDataSource remote;
  late _MemorySyncCursorStore cursorStore;
  late DateTime now;
  late ProfileSyncRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sessionStore = _MemorySessionStore(session: _registeredSession);
    remote = _FakeSyncRemoteDataSource();
    cursorStore = _MemorySyncCursorStore();
    now = DateTime.utc(2030, 1, 2, 3, 4, 5);
    repository = ProfileSyncRepositoryImpl(
      database: database,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      dateTimeService: DateTimeService(now: () => now),
      cursorStore: cursorStore,
      endpoint: 'http://127.0.0.1:8000',
    );
    await database.bootstrapDao.bootstrap();
  });

  tearDown(() => database.close());

  test('pushProfile reads the active profile and creates a Profile item', () async {
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
  });

  test('pushProfile success writes all local sync metadata', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
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

  test('pushProfile conflict is explicit and keeps the local version', () async {
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
  });

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

  test('pullProfile no update uses and advances the independent cursor', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    await ProfileLocalDataSource(database).updateSyncMetadata(
      userId: bootstrap.activeUserId,
      syncStatus: 'synced',
      serverVersion: 5,
      lastSyncedAt: 100,
      originDeviceId: bootstrap.localInstallationId,
    );
    remote.pullResponse = SyncPullResponseDto(serverVersion: 5, items: const []);
    cursorStore.value = 3;

    final result = await repository.pullProfile();

    expect(result.success, isTrue);
    expect(result.pulled, isFalse);
    expect(result.message, '没有新的 Profile 更新');
    expect(remote.lastPullRequest?.sinceServerVersion, 3);
    expect(remote.lastPullRequest?.tables, ['user_profiles']);
    expect(cursorStore.value, 5);
  });

  test('pullProfile applies the newest cloud Profile to the local UUID', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
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
  });

  test('pullProfile detects local pending changes and never overwrites them', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
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

    await expectLater(repository.pullProfile(), throwsA(isA<ApiException>()));
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

  test('schemaVersion remains 3', () {
    expect(database.schemaVersion, 3);
  });
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
const _user = AuthUser(id: 'cloud-user', displayName: 'Dev user');
const _sessionWithoutDevice = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: _user,
);
const _registeredSession = AuthSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: _user,
  deviceRegistration: DeviceRegistration(deviceId: _deviceId, serverTime: 1),
);

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
  SyncPushRequestDto? lastPushRequest;
  SyncPullRequestDto? lastPullRequest;

  @override
  Future<SyncPushResponseDto> push(
    SyncPushRequestDto request, {
    required String accessToken,
  }) async {
    if (error case final value?) throw value;
    lastPushRequest = request;
    return pushResponse;
  }

  @override
  Future<SyncPullResponseDto> pull(
    SyncPullRequestDto request, {
    required String accessToken,
  }) async {
    if (error case final value?) throw value;
    lastPullRequest = request;
    return pullResponse;
  }
}

final class _MemorySyncCursorStore implements SyncCursorStore {
  int value = 0;

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
