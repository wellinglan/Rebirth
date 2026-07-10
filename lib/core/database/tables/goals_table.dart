import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('Goal')
class Goals extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get parentGoalId =>
      text().references(Goals, #id, onDelete: KeyAction.setNull).nullable()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  TextColumn get goalLevel => text()();

  TextColumn get status => text().withDefault(const Constant('not_started'))();

  TextColumn get startDate => text().nullable()();

  TextColumn get targetDate => text().nullable()();

  IntColumn get completedAt => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(title)) > 0)',
    "CHECK (goal_level IN ('life', 'year', 'quarter', 'month', 'week', 'day'))",
    "CHECK (status IN ('not_started', 'in_progress', 'completed', 'paused', 'cancelled'))",
    "CHECK (start_date IS NULL OR start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (target_date IS NULL OR target_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    'CHECK (start_date IS NULL OR target_date IS NULL OR target_date >= start_date)',
    'CHECK (completed_at IS NULL OR completed_at >= 0)',
    'CHECK (sort_order >= 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
