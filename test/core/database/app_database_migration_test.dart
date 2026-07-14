import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';

void main() {
  test('v2 to v3 preserves goals and adds nullable archived_at', () async {
    final fixture = await _createDatabaseFixture();
    addTearDown(fixture.dispose);
    final original = AppDatabase.forTesting(NativeDatabase(fixture.file));
    addTearDown(original.close);
    final bootstrap = await original.bootstrapDao.bootstrap();
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
    expect(version.read<int>('user_version'), 3);

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
    final bootstrap = await original.bootstrapDao.bootstrap();
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
    expect(migrated.schemaVersion, 3);
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
