import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/data/local_cloud_sync_preference_repository.dart';

void main() {
  late AppDatabase database;
  late DateTime currentTime;
  late LocalCloudSyncPreferenceRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime.utc(2030, 1, 2, 3, 4, 5);
    repository = LocalCloudSyncPreferenceRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
  });

  tearDown(() => database.close());

  test(
    'preference defaults to disabled and persists without migration',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap();

      expect(await repository.readEnabled(bootstrap.activeUserId), isFalse);

      await repository.setEnabled(
        localUserId: bootstrap.activeUserId,
        enabled: true,
      );
      final recreated = LocalCloudSyncPreferenceRepository(
        database: database,
        dateTimeService: DateTimeService(now: () => currentTime),
      );

      expect(await recreated.readEnabled(bootstrap.activeUserId), isTrue);
      final settings = await database.select(database.appSettings).getSingle();
      expect(settings.updatedAt, currentTime.millisecondsSinceEpoch);
    },
  );

  test('preference is isolated by active local account', () async {
    final accountA = await database.bootstrapDao.bootstrap();
    await repository.setEnabled(
      localUserId: accountA.activeUserId,
      enabled: true,
    );
    await (database.update(database.userProfiles)
          ..where((row) => row.id.equals(accountA.activeUserId)))
        .write(const UserProfilesCompanion(isActive: Value(false)));

    const accountBId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: const Value(accountBId),
            timezoneId: 'Etc/UTC',
          ),
        );
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            userId: accountBId,
            localInstallationId: accountA.localInstallationId,
          ),
        );

    expect(await repository.readEnabled(accountBId), isFalse);
    expect(
      () => repository.readEnabled(accountA.activeUserId),
      throwsStateError,
    );

    await repository.setEnabled(localUserId: accountBId, enabled: true);
    expect(await repository.readEnabled(accountBId), isTrue);
  });

  test('separate device databases do not inherit the setting', () async {
    final first = await database.bootstrapDao.bootstrap();
    await repository.setEnabled(localUserId: first.activeUserId, enabled: true);

    await database.close();
    final otherDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    database = otherDatabase;
    final otherBootstrap = await otherDatabase.bootstrapDao.bootstrap();
    final otherRepository = LocalCloudSyncPreferenceRepository(
      database: otherDatabase,
      dateTimeService: DateTimeService(now: () => currentTime),
    );

    expect(
      await otherRepository.readEnabled(otherBootstrap.activeUserId),
      isFalse,
    );
  });
}
