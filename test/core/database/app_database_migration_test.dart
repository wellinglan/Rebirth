import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';

void main() {
  test('v2 to v7 preserves goals and adds account boundary tables', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(original.close);
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000001'),
            userId: bootstrap.activeUserId,
            title: '迁移前目标',
            goalLevel: 'month',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await _replaceGoalsWithVersionTwoDefinition(original);
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 7);

    final goal =
        await (migrated.select(migrated.goals)..where(
              (row) => row.id.equals('00000000-0000-4000-8000-000000000001'),
            ))
            .getSingle();
    expect(goal.title, '迁移前目标');
    expect(goal.archivedAt, isNull);
    await _expectCoreTableSet(migrated);
  });

  test('v1 migration chain still preserves custom support and indexes', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(original.close);
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000011'),
            userId: bootstrap.activeUserId,
            title: 'v1 普通目标',
            goalLevel: 'year',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await _replaceGoalsWithVersionOneDefinition(original);
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    expect(migrated.schemaVersion, 7);
    final existing = await migrated.select(migrated.goals).getSingle();
    expect(existing.title, 'v1 普通目标');
    expect(existing.archivedAt, isNull);

    await migrated
        .into(migrated.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000012'),
            userId: bootstrap.activeUserId,
            title: '自定义目标',
            goalLevel: 'custom',
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    final indexes = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'goals'",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>{
        'goals_user_parent_sort_order',
        'goals_user_level_status',
        'goals_user_target_date',
      }),
    );
  });

  test('v3 to v7 preserves goals and creates conflict indexes', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    final bootstrap = await original.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    await original
        .into(original.goals)
        .insert(
          GoalsCompanion.insert(
            id: const Value('00000000-0000-4000-8000-000000000021'),
            userId: bootstrap.activeUserId,
            title: '已有冲突目标',
            goalLevel: 'month',
            syncStatus: const Value('conflict'),
            serverVersion: const Value(4),
            originDeviceId: Value(bootstrap.localInstallationId),
          ),
        );
    await original.customStatement('DROP TABLE sync_conflicts');
    await original.customStatement('PRAGMA user_version = 3');
    await original.close();

    final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(migrated.close);
    final version = await migrated
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 7);
    final goal = await migrated.select(migrated.goals).getSingle();
    expect(goal.id, '00000000-0000-4000-8000-000000000021');
    expect(goal.syncStatus, 'conflict');
    expect(goal.serverVersion, 4);
    expect(await migrated.select(migrated.syncConflicts).get(), isEmpty);

    final indexes = await migrated
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND tbl_name = 'sync_conflicts'",
        )
        .get();
    expect(
      indexes.map((row) => row.read<String>('name')).toSet(),
      containsAll(<String>{
        'sync_conflicts_user_status_detected',
        'sync_conflicts_endpoint_user_entity',
        'sync_conflicts_entity_record',
        'sync_conflicts_one_active',
      }),
    );
  });

  test(
    'v4 to v7 preserves data and supersedes unhydrated legacy conflicts',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const goalId = '00000000-0000-4000-8000-000000000031';
      await original
          .into(original.goals)
          .insert(
            GoalsCompanion.insert(
              id: const Value(goalId),
              userId: bootstrap.activeUserId,
              title: 'v4 账号隔离迁移目标',
              goalLevel: 'month',
              syncStatus: const Value('conflict'),
              serverVersion: const Value(7),
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      await original
          .into(original.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: const Value('00000000-0000-4000-8000-000000000032'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'cloud-user-b',
              entityType: 'goals',
              recordId: goalId,
              localUpdatedAt: 100,
              localDeletedAt: const Value(100),
              localServerVersion: const Value(7),
              remoteOperation: 'unknown_pending_pull',
              remoteServerVersion: 0,
              detectedAt: 110,
              lastSeenAt: 120,
              resolutionStatus: 'awaiting_remote_snapshot',
            ),
          );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement('DROP TABLE installation_info');
      await original.customStatement('PRAGMA user_version = 4');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      expect(migrated.schemaVersion, 7);
      expect(await migrated.select(migrated.goals).get(), hasLength(1));
      expect(await migrated.select(migrated.userProfiles).get(), hasLength(1));
      expect(await migrated.select(migrated.appSettings).get(), hasLength(1));
      expect(
        await migrated.select(migrated.cloudAccountBindings).get(),
        isEmpty,
      );
      final installation = await migrated
          .select(migrated.installationInfo)
          .getSingle();
      expect(installation.installationId, bootstrap.localInstallationId);
      final conflict = await migrated
          .select(migrated.syncConflicts)
          .getSingle();
      expect(
        conflict.resolutionStatus,
        'superseded_by_account_isolation_migration',
      );
      expect(conflict.resolvedAt, 120);
      expect(conflict.localServerVersion, 7);
    },
  );

  test(
    'v5 to v7 backfills existing binding without claiming legacy data',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await original
          .into(original.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              id: const Value('70000000-0000-4000-8000-000000000001'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'existing-cloud-user',
              createdAt: 100,
              lastUsedAt: 200,
              verificationTime: const Value(100),
              verificationMethod: const Value('account_space_creation'),
              verificationReason: const Value(
                'all_evidence_matches_current_user',
              ),
            ),
          );
      await original.customStatement(
        'DROP INDEX cloud_account_bindings_status_last_used',
      );
      await original.customStatement('''
CREATE TABLE cloud_account_bindings_v5 (
  id TEXT NOT NULL PRIMARY KEY,
  local_user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
  endpoint_key TEXT NOT NULL,
  cloud_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  UNIQUE(endpoint_key, cloud_user_id),
  UNIQUE(local_user_id),
  CHECK (length(trim(endpoint_key)) > 0),
  CHECK (length(trim(cloud_user_id)) > 0),
  CHECK (created_at >= 0),
  CHECK (last_used_at >= created_at),
  CHECK (status IN ('active', 'disabled'))
)
''');
      await original.customStatement(
        'INSERT INTO cloud_account_bindings_v5 '
        '(id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status) '
        'SELECT id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status FROM cloud_account_bindings',
      );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement(
        'ALTER TABLE cloud_account_bindings_v5 RENAME TO cloud_account_bindings',
      );
      await original.customStatement('PRAGMA user_version = 5');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      final binding = await migrated
          .select(migrated.cloudAccountBindings)
          .getSingle();
      expect(binding.bindingOrigin, 'clean_first_login');
      expect(binding.syncEligibilityStatus, 'ready');
      expect(binding.ownershipConfirmedAt, 100);
      expect(binding.verificationStatus, 'verified');
      expect(binding.verificationTime, 100);
      expect(binding.verificationMethod, 'account_space_creation');
      expect(binding.verificationReason, 'all_evidence_matches_current_user');
      expect(binding.localUserId, bootstrap.activeUserId);
      expect(await migrated.select(migrated.userProfiles).get(), hasLength(1));
      expect(
        await migrated.select(migrated.installationInfo).get(),
        hasLength(1),
      );

      await expectLater(
        migrated.customStatement(
          "UPDATE cloud_account_bindings SET binding_origin = 'invalid'",
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'v6 to v7 preserves legacy quarantine and business sync metadata',
    () async {
      final fixture = await _createDatabaseFixture();
      addTearDown(fixture.dispose);
      final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
      final bootstrap = await original.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      await (original.update(
        original.userProfiles,
      )..where((row) => row.id.equals(bootstrap.activeUserId))).write(
        const UserProfilesCompanion(
          syncStatus: Value('conflict'),
          serverVersion: Value(17),
          lastSyncedAt: Value(900),
        ),
      );
      await original
          .into(original.cloudAccountBindings)
          .insert(
            CloudAccountBindingsCompanion.insert(
              id: const Value('70000000-0000-4000-8000-000000000006'),
              localUserId: bootstrap.activeUserId,
              endpointKey: 'https://alpha.example.test',
              cloudUserId: 'legacy-cloud-user',
              createdAt: 100,
              lastUsedAt: 200,
              bindingOrigin: const Value('legacy_claim'),
              syncEligibilityStatus: const Value('legacy_review_required'),
              ownershipConfirmedAt: const Value(100),
              verificationStatus: const Value('not_verified'),
            ),
          );
      await original.customStatement(
        'DROP INDEX cloud_account_bindings_status_last_used',
      );
      await original.customStatement('''
CREATE TABLE cloud_account_bindings_v6 (
  id TEXT NOT NULL PRIMARY KEY,
  local_user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE RESTRICT,
  endpoint_key TEXT NOT NULL,
  cloud_user_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  binding_origin TEXT NOT NULL DEFAULT 'clean_first_login',
  sync_eligibility_status TEXT NOT NULL DEFAULT 'ready',
  ownership_confirmed_at INTEGER,
  UNIQUE(endpoint_key, cloud_user_id),
  UNIQUE(local_user_id)
)
''');
      await original.customStatement(
        'INSERT INTO cloud_account_bindings_v6 '
        '(id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status, binding_origin, sync_eligibility_status, '
        'ownership_confirmed_at) '
        'SELECT id, local_user_id, endpoint_key, cloud_user_id, created_at, '
        'last_used_at, status, binding_origin, sync_eligibility_status, '
        'ownership_confirmed_at FROM cloud_account_bindings',
      );
      await original.customStatement('DROP TABLE cloud_account_bindings');
      await original.customStatement(
        'ALTER TABLE cloud_account_bindings_v6 '
        'RENAME TO cloud_account_bindings',
      );
      await original.customStatement('PRAGMA user_version = 6');
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(fixture.file));
      addTearDown(migrated.close);
      final binding = await migrated
          .select(migrated.cloudAccountBindings)
          .getSingle();
      final profile = await migrated.select(migrated.userProfiles).getSingle();
      expect(migrated.schemaVersion, 7);
      expect(binding.syncEligibilityStatus, 'legacy_review_required');
      expect(binding.verificationStatus, 'not_verified');
      expect(binding.verificationTime, isNull);
      expect(binding.verificationMethod, isNull);
      expect(binding.verificationReason, isNull);
      expect(profile.serverVersion, 17);
      expect(profile.lastSyncedAt, 900);
      expect(profile.syncStatus, 'conflict');
    },
  );
}

Future<void> _replaceGoalsWithVersionTwoDefinition(AppDatabase database) {
  return _rebuildGoals(database: database, version: 2, removeCustom: false);
}

Future<void> _replaceGoalsWithVersionOneDefinition(AppDatabase database) {
  return _rebuildGoals(database: database, version: 1, removeCustom: true);
}

Future<void> _rebuildGoals({
  required AppDatabase database,
  required int version,
  required bool removeCustom,
}) async {
  final schemaRow = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'goals'",
      )
      .getSingle();
  var oldSql = schemaRow
      .read<String>('sql')
      .replaceFirst('CREATE TABLE "goals"', 'CREATE TABLE "goals_old"')
      .replaceFirst(', "archived_at" INTEGER NULL', '')
      .replaceFirst(', archived_at INTEGER NULL', '')
      .replaceFirst(', CHECK (archived_at IS NULL OR archived_at >= 0)', '');
  if (removeCustom) {
    oldSql = oldSql.replaceFirst(", 'custom'", '');
  }
  const columns =
      'id, user_id, parent_goal_id, title, description, goal_level, status, '
      'start_date, target_date, completed_at, sort_order, created_at, '
      'updated_at, deleted_at, sync_status, server_version, '
      'origin_device_id, last_synced_at';

  await database.customStatement('PRAGMA foreign_keys = OFF');
  await database.transaction(() async {
    for (final indexName in const <String>[
      'goals_user_parent_sort_order',
      'goals_user_level_status',
      'goals_user_target_date',
    ]) {
      await database.customStatement('DROP INDEX $indexName');
    }
    await database.customStatement(oldSql);
    await database.customStatement(
      'INSERT INTO goals_old ($columns) SELECT $columns FROM goals',
    );
    await database.customStatement('DROP TABLE goals');
    await database.customStatement('ALTER TABLE goals_old RENAME TO goals');
    await database.customStatement(
      'CREATE INDEX goals_user_parent_sort_order '
      'ON goals (user_id, parent_goal_id, sort_order)',
    );
    await database.customStatement(
      'CREATE INDEX goals_user_level_status '
      'ON goals (user_id, goal_level, status)',
    );
    await database.customStatement(
      'CREATE INDEX goals_user_target_date ON goals (user_id, target_date)',
    );
    await database.customStatement('PRAGMA user_version = $version');
  });
}

Future<void> _expectCoreTableSet(AppDatabase database) async {
  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  expect(tables.map((row) => row.read<String>('name')).toSet(), <String>{
    'user_profiles',
    'app_settings',
    'today_records',
    'journal_entries',
    'goals',
    'health_records',
    'ai_reports',
    'sync_conflicts',
    'installation_info',
    'cloud_account_bindings',
  });
}

Future<_DatabaseFixture> _createDatabaseFixture() async {
  final directory = await Directory.systemTemp.createTemp(
    'rebirth_schema_migration_',
  );
  return _DatabaseFixture(
    directory,
    File('${directory.path}${Platform.pathSeparator}rebirth.sqlite'),
  );
}

final class _DatabaseFixture {
  const _DatabaseFixture(this.directory, this.file);

  final Directory directory;
  final File file;

  Future<void> dispose() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
