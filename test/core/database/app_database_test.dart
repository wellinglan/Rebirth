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

  test('creates schema version 15 with local AI chat storage', () async {
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
        'ai_report_versions',
        'ai_report_feedback',
        'ai_chat_threads',
        'ai_chat_messages',
        'sync_conflicts',
        'installation_info',
        'cloud_account_bindings',
        'journal_prompt_configurations',
        'journal_prompt_definitions',
        'journal_entry_prompt_items',
      }),
    );

    final versionRow = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(versionRow.read<int>('user_version'), 15);
  });

  test(
    'active sync conflict is unique while resolved history remains',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final first = _conflict(
        localUserId: bootstrap.activeUserId,
        id: uuid.v4(),
      );
      await database.into(database.syncConflicts).insert(first);

      await expectLater(
        database
            .into(database.syncConflicts)
            .insert(
              _conflict(localUserId: bootstrap.activeUserId, id: uuid.v4()),
            ),
        throwsA(isA<Exception>()),
      );

      await (database.update(
        database.syncConflicts,
      )..where((row) => row.id.equals(first.id.value))).write(
        const SyncConflictsCompanion(
          resolutionStatus: Value('resolved_keep_local'),
          resolvedAt: Value(200),
        ),
      );
      await database
          .into(database.syncConflicts)
          .insert(
            _conflict(localUserId: bootstrap.activeUserId, id: uuid.v4()),
          );
      expect(await database.select(database.syncConflicts).get(), hasLength(2));
    },
  );

  test(
    'sync conflict constraints reject invalid operation and version',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await expectLater(
        database
            .into(database.syncConflicts)
            .insert(
              _conflict(
                localUserId: bootstrap.activeUserId,
                id: uuid.v4(),
                remoteOperation: 'invalid',
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database
            .into(database.syncConflicts)
            .insert(
              _conflict(
                localUserId: bootstrap.activeUserId,
                id: uuid.v4(),
                remoteServerVersion: -1,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('bootstrap refuses to create an anonymous profile by default', () async {
    await expectLater(
      database.bootstrapDao.bootstrap(createUnboundProfile: false),
      throwsA(isA<ActiveUserProfileRequiredException>()),
    );

    expect(await database.select(database.userProfiles).get(), isEmpty);
    expect(await database.select(database.appSettings).get(), isEmpty);
    expect(await database.select(database.installationInfo).get(), isEmpty);
  });

  test('explicit legacy bootstrap creates one unbound profile', () async {
    final result = await database.bootstrapDao.bootstrap(
      defaultTimezoneId: 'Asia/Shanghai',
      createUnboundProfile: true,
    );

    expect(result.activeUser.isActive, isTrue);
    expect(result.activeUser.timezoneId, 'Asia/Shanghai');
    expect(result.localInstallationId, hasLength(36));
    expect(result.settings.userId, result.activeUserId);
    expect(await database.select(database.userProfiles).get(), hasLength(1));
    expect(await database.select(database.appSettings).get(), hasLength(1));
    expect(await database.select(database.cloudAccountBindings).get(), isEmpty);
  });

  test('bootstrap is idempotent and keeps installation ID stable', () async {
    final first = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    final second = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

    expect(second.activeUserId, first.activeUserId);
    expect(second.localInstallationId, first.localInstallationId);
    expect(await database.select(database.userProfiles).get(), hasLength(1));
    expect(await database.select(database.appSettings).get(), hasLength(1));
  });

  test(
    'bootstrap diagnoses multiple active users instead of choosing one',
    () async {
      await database.bootstrapDao.bootstrap(createUnboundProfile: true);
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
        database.bootstrapDao.bootstrap(createUnboundProfile: true),
        throwsA(isA<MultipleActiveUserProfilesException>()),
      );
    },
  );

  test('rejects two active Today records for the same user and date', () async {
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
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
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

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

  test('metric narrative columns enforce the 80 character limit', () async {
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            userId: bootstrap.activeUserId,
            recordDate: '2026-07-20',
            timezoneOffsetMinutes: 480,
            researchDescription: Value('x' * 80),
          ),
        );
    await expectLater(
      database
          .into(database.healthRecords)
          .insert(
            HealthRecordsCompanion.insert(
              userId: bootstrap.activeUserId,
              recordDate: '2026-07-20',
              timezoneOffsetMinutes: 480,
              waterDescription: Value('x' * 81),
            ),
          ),
      throwsA(isA<Exception>()),
    );
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

SyncConflictsCompanion _conflict({
  required String localUserId,
  required String id,
  String remoteOperation = 'unknown_pending_pull',
  int remoteServerVersion = 1,
}) {
  return SyncConflictsCompanion.insert(
    id: Value(id),
    localUserId: localUserId,
    endpointKey: 'http://localhost:8000',
    cloudUserId: 'cloud-user',
    entityType: 'goals',
    recordId: '00000000-0000-4000-8000-000000000001',
    localUpdatedAt: 100,
    remoteOperation: remoteOperation,
    remoteServerVersion: remoteServerVersion,
    detectedAt: 100,
    lastSeenAt: 100,
    resolutionStatus: 'awaiting_remote_snapshot',
  );
}
