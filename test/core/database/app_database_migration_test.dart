import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';

void main() {
  test(
    'v1 to v2 preserves goals, accepts custom, and rebuilds indexes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'rebirth_schema_migration_',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}rebirth.sqlite',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      final original = AppDatabase.forTesting(NativeDatabase(file));
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
              startDate: const Value('2026-07-14'),
              targetDate: const Value('2026-08-14'),
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      await _replaceGoalsWithVersionOneDefinition(original);
      await original.close();

      final migrated = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(migrated.close);

      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 2);

      final existing =
          await (migrated.select(migrated.goals)..where(
                (goal) =>
                    goal.id.equals('00000000-0000-4000-8000-000000000001'),
              ))
              .getSingle();
      expect(existing.title, '迁移前目标');
      expect(existing.goalLevel, 'month');
      expect(existing.startDate, '2026-07-14');
      expect(existing.targetDate, '2026-08-14');

      await migrated
          .into(migrated.goals)
          .insert(
            GoalsCompanion.insert(
              id: const Value('00000000-0000-4000-8000-000000000002'),
              userId: bootstrap.activeUserId,
              title: '自定义目标',
              goalLevel: 'custom',
              originDeviceId: Value(bootstrap.localInstallationId),
            ),
          );
      final custom =
          await (migrated.select(migrated.goals)..where(
                (goal) =>
                    goal.id.equals('00000000-0000-4000-8000-000000000002'),
              ))
              .getSingle();
      expect(custom.goalLevel, 'custom');

      final indexes = await migrated
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND tbl_name = 'goals'",
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

      final tables = await migrated
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
    },
  );
}

Future<void> _replaceGoalsWithVersionOneDefinition(AppDatabase database) async {
  final schemaRow = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'goals'",
      )
      .getSingle();
  final versionTwoSql = schemaRow.read<String>('sql');
  final versionOneSql = versionTwoSql
      .replaceFirst('CREATE TABLE "goals"', 'CREATE TABLE "goals_v1"')
      .replaceFirst(", 'custom'", '');
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
    await database.customStatement(versionOneSql);
    await database.customStatement(
      'INSERT INTO goals_v1 ($columns) SELECT $columns FROM goals',
    );
    await database.customStatement('DROP TABLE goals');
    await database.customStatement('ALTER TABLE goals_v1 RENAME TO goals');
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
    await database.customStatement('PRAGMA user_version = 1');
  });
}
