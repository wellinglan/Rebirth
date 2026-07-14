import 'package:drift/drift.dart';

import 'daos/bootstrap_dao.dart';
import 'database_connection.dart';
import 'tables/ai_reports_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/common_columns.dart';
import 'tables/goals_table.dart';
import 'tables/health_records_table.dart';
import 'tables/journal_entries_table.dart';
import 'tables/today_records_table.dart';
import 'tables/user_profiles_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserProfiles,
    AppSettings,
    Goals,
    TodayRecords,
    JournalEntries,
    HealthRecords,
    AiReports,
  ],
  daos: [BootstrapDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabaseConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createVersionOneIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(
          TableMigration(goals, newColumns: [goals.archivedAt]),
        );
        await _createGoalIndexes();
      } else if (from < 3) {
        await migrator.addColumn(goals, goals.archivedAt);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createVersionOneIndexes() async {
    // Drift's DSL does not directly model the partial unique indexes used to
    // keep soft-deleted rows out of uniqueness checks, so schema v1 creates
    // those indexes with explicit, version-controlled SQL.
    for (final statement in _versionOneIndexes) {
      await customStatement(statement);
    }
    await _createGoalIndexes();
  }

  Future<void> _createGoalIndexes() async {
    for (final statement in _goalIndexes) {
      await customStatement(statement);
    }
  }
}

const _versionOneIndexes = <String>[
  'CREATE UNIQUE INDEX user_profiles_one_active '
      'ON user_profiles (is_active) '
      'WHERE is_active = 1 AND deleted_at IS NULL',
  'CREATE INDEX user_profiles_sync_status_updated_at '
      'ON user_profiles (sync_status, updated_at)',
  'CREATE UNIQUE INDEX today_records_user_date_active '
      'ON today_records (user_id, record_date) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX today_records_user_date_desc '
      'ON today_records (user_id, record_date DESC)',
  'CREATE INDEX today_records_sync_status_updated_at '
      'ON today_records (sync_status, updated_at)',
  'CREATE UNIQUE INDEX journal_entries_user_date_active '
      'ON journal_entries (user_id, entry_date) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX journal_entries_today_record_active '
      'ON journal_entries (today_record_id) '
      'WHERE today_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX journal_entries_user_date_desc '
      'ON journal_entries (user_id, entry_date DESC)',
  'CREATE UNIQUE INDEX health_records_user_date_active '
      'ON health_records (user_id, record_date) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX health_records_today_record_active '
      'ON health_records (today_record_id) '
      'WHERE today_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX health_records_user_date_desc '
      'ON health_records (user_id, record_date DESC)',
  'CREATE UNIQUE INDEX health_records_external_source '
      'ON health_records (data_source, source_record_id) '
      'WHERE source_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX ai_reports_user_type_period '
      'ON ai_reports (user_id, report_type, period_end_date DESC)',
  'CREATE INDEX ai_reports_input_deduplication '
      'ON ai_reports '
      '(user_id, report_type, period_start_date, period_end_date, input_hash)',
  'CREATE INDEX ai_reports_status_requested_at '
      'ON ai_reports (report_status, requested_at)',
];

const _goalIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS goals_user_parent_sort_order '
      'ON goals (user_id, parent_goal_id, sort_order)',
  'CREATE INDEX IF NOT EXISTS goals_user_level_status '
      'ON goals (user_id, goal_level, status)',
  'CREATE INDEX IF NOT EXISTS goals_user_target_date '
      'ON goals (user_id, target_date)',
];
