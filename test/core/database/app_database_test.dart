import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/daos/bootstrap_dao.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('creates schema version 3 with all core tables', () async {
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final tableNames = rows.map((row) => row.read<String>('name')).toSet();

    expect(
      tableNames,
      containsAll(<String>{
        'user_profiles',
        'app_settings',
        'today_records',
        'journal_entries',
        'goals',
        'health_records',
        'ai_reports',
      }),
    );

    final versionRow = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(versionRow.read<int>('user_version'), 3);
  });

  test('bootstrap creates one default user and matching settings', () async {
    final result = await database.bootstrapDao.bootstrap(
      defaultTimezoneId: 'Asia/Shanghai',
    );

    expect(result.activeUser.isActive, isTrue);
    expect(result.activeUser.timezoneId, 'Asia/Shanghai');
    expect(result.localInstallationId, hasLength(36));
    expect(result.settings.userId, result.activeUserId);
    expect(await database.select(database.userProfiles).get(), hasLength(1));
    expect(await database.select(database.appSettings).get(), hasLength(1));
  });

  test('bootstrap is idempotent and keeps installation ID stable', () async {
    final first = await database.bootstrapDao.bootstrap();
    final second = await database.bootstrapDao.bootstrap();

    expect(second.activeUserId, first.activeUserId);
    expect(second.localInstallationId, first.localInstallationId);
    expect(await database.select(database.userProfiles).get(), hasLength(1));
    expect(await database.select(database.appSettings).get(), hasLength(1));
  });

  test(
    'bootstrap diagnoses multiple active users instead of choosing one',
    () async {
      await database.bootstrapDao.bootstrap();
      await database.customStatement('DROP INDEX user_profiles_one_active');
      await database
          .into(database.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: Value(uuid.v4()),
              timezoneId: 'Etc/UTC',
            ),
          );

      await expectLater(
        database.bootstrapDao.bootstrap(),
        throwsA(isA<MultipleActiveUserProfilesException>()),
      );
    },
  );

  test('rejects two active Today records for the same user and date', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final firstRecord = TodayRecordsCompanion.insert(
      userId: bootstrap.activeUserId,
      recordDate: '2026-07-10',
      timezoneOffsetMinutes: 480,
      originDeviceId: Value(bootstrap.localInstallationId),
    );
    final duplicateRecord = TodayRecordsCompanion.insert(
      userId: bootstrap.activeUserId,
      recordDate: '2026-07-10',
      timezoneOffsetMinutes: 480,
      originDeviceId: Value(bootstrap.localInstallationId),
    );

    await database.into(database.todayRecords).insert(firstRecord);

    await expectLater(
      database.into(database.todayRecords).insert(duplicateRecord),
      throwsA(isA<Exception>()),
    );
  });

  test('stores NULL and zero as different Today values', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();

    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            userId: bootstrap.activeUserId,
            recordDate: '2026-07-11',
            timezoneOffsetMinutes: 480,
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            userId: bootstrap.activeUserId,
            recordDate: '2026-07-12',
            timezoneOffsetMinutes: 480,
            originDeviceId: Value(bootstrap.localInstallationId),
            researchMinutes: const Value(0),
          ),
        );

    final records = await (database.select(
      database.todayRecords,
    )..orderBy([(row) => OrderingTerm.asc(row.recordDate)])).get();

    expect(records[0].researchMinutes, isNull);
    expect(records[1].researchMinutes, 0);
  });

  test('enables and enforces SQLite foreign keys', () async {
    final pragma = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(pragma.read<int>('foreign_keys'), 1);

    final invalidUserId = uuid.v4();
    await expectLater(
      database
          .into(database.todayRecords)
          .insert(
            TodayRecordsCompanion.insert(
              userId: invalidUserId,
              recordDate: '2026-07-13',
              timezoneOffsetMinutes: 480,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
