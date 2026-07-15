import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/profile/data/profile_repository_impl.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';

void main() {
  late AppDatabase database;
  late ProfileRepositoryImpl repository;
  late DateTime currentTime;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime.utc(2030, 1, 2, 3, 4, 5);
    repository = ProfileRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
  });

  tearDown(() => database.close());

  test('getActiveProfile returns the bootstrap active user', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();

    final profile = await repository.getActiveProfile();

    expect(profile.id, bootstrap.activeUserId);
    expect(profile.timezoneId, 'Etc/UTC');
    expect(await database.select(database.userProfiles).get(), hasLength(1));
  });

  test('saveProfile updates allowed fields and explicit updatedAt', () async {
    final before = await repository.getActiveProfile();
    final expectedTimestamp = currentTime.millisecondsSinceEpoch;

    final saved = await repository.saveProfile(
      ProfileSaveData(displayName: '  Chinami  ', growthFocus: '  稳定成长  '),
    );

    expect(saved.id, before.id);
    expect(saved.displayName, 'Chinami');
    expect(saved.growthFocus, '稳定成长');
    expect(saved.timezoneId, before.timezoneId);
    expect(saved.updatedAt, expectedTimestamp);
    final stored = await database.select(database.userProfiles).getSingle();
    expect(stored.syncStatus, 'pending');
    expect(await database.select(database.userProfiles).get(), hasLength(1));
  });

  test('blank profile input is stored as null', () async {
    final saved = await repository.saveProfile(
      ProfileSaveData(displayName: '   ', growthFocus: '\n '),
    );

    expect(saved.displayName, isNull);
    expect(saved.growthFocus, isNull);
  });

  test('saved profile is readable through a new repository instance', () async {
    await repository.saveProfile(ProfileSaveData(displayName: '持久化昵称'));
    final reopenedRepository = ProfileRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );

    final reopened = await reopenedRepository.getActiveProfile();

    expect(reopened.displayName, '持久化昵称');
    expect(await database.select(database.userProfiles).get(), hasLength(1));
  });

  test(
    'getDeviceStatus reads bootstrap installation and active user IDs',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap();

      final status = await repository.getDeviceStatus();

      expect(status.localInstallationId, bootstrap.localInstallationId);
      expect(status.activeUserId, bootstrap.activeUserId);
      expect(status.isLocalMode, isTrue);
      expect(status.syncEnabled, isFalse);
    },
  );

  test('save only changes the bootstrap active user', () async {
    const otherUserId = '00000000-0000-4000-8000-000000000002';
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: const Value(otherUserId),
            displayName: const Value('Other user'),
            timezoneId: 'Etc/UTC',
            isActive: const Value(false),
          ),
        );

    final saved = await repository.saveProfile(
      ProfileSaveData(displayName: 'Active user'),
    );
    final other = await (database.select(
      database.userProfiles,
    )..where((row) => row.id.equals(otherUserId))).getSingle();

    expect(saved.id, isNot(otherUserId));
    expect(saved.displayName, 'Active user');
    expect(other.displayName, 'Other user');
    expect(other.isActive, isFalse);
  });

  test('schemaVersion remains 3', () {
    expect(database.schemaVersion, 3);
  });
}
