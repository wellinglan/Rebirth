import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'goals_table.dart';
import 'user_profiles_table.dart';

@DataClassName('TodayRecord')
class TodayRecords extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get recordDate => text()();

  IntColumn get timezoneOffsetMinutes => integer()();

  TextColumn get priority1 => text().named('priority_1').nullable()();

  BoolColumn get priority1Completed => boolean()
      .named('priority_1_completed')
      .withDefault(const Constant(false))();

  @ReferenceName('priorityOneTodayRecords')
  TextColumn get priority1GoalId => text()
      .named('priority_1_goal_id')
      .references(Goals, #id, onDelete: KeyAction.setNull)
      .nullable()();

  TextColumn get priority2 => text().named('priority_2').nullable()();

  BoolColumn get priority2Completed => boolean()
      .named('priority_2_completed')
      .withDefault(const Constant(false))();

  @ReferenceName('priorityTwoTodayRecords')
  TextColumn get priority2GoalId => text()
      .named('priority_2_goal_id')
      .references(Goals, #id, onDelete: KeyAction.setNull)
      .nullable()();

  TextColumn get priority3 => text().named('priority_3').nullable()();

  BoolColumn get priority3Completed => boolean()
      .named('priority_3_completed')
      .withDefault(const Constant(false))();

  @ReferenceName('priorityThreeTodayRecords')
  TextColumn get priority3GoalId => text()
      .named('priority_3_goal_id')
      .references(Goals, #id, onDelete: KeyAction.setNull)
      .nullable()();

  IntColumn get moodScore => integer().nullable()();

  IntColumn get wellbeingScoreScale => integer().nullable()();

  TextColumn get moodDescription => text().nullable()();

  IntColumn get energyScore => integer().nullable()();

  TextColumn get energyDescription => text().nullable()();

  IntColumn get researchMinutes => integer().nullable()();

  TextColumn get researchDescription => text().nullable().customConstraint(
    'NULL CHECK (length(research_description) <= 80)',
  )();

  IntColumn get learningMinutes => integer().nullable()();

  TextColumn get learningDescription => text().nullable().customConstraint(
    'NULL CHECK (length(learning_description) <= 80)',
  )();

  TextColumn get dailyNote => text().nullable()();

  TextColumn get recordStatus => text().withDefault(const Constant('draft'))();

  @override
  List<String> get customConstraints => const [
    "CHECK (record_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    'CHECK (timezone_offset_minutes BETWEEN -840 AND 840)',
    'CHECK (priority_1_completed IN (0, 1))',
    'CHECK (priority_2_completed IN (0, 1))',
    'CHECK (priority_3_completed IN (0, 1))',
    'CHECK (wellbeing_score_scale IS NULL OR wellbeing_score_scale IN (5, 10))',
    'CHECK (mood_score IS NULL OR '
        '(COALESCE(wellbeing_score_scale, 5) = 5 AND mood_score BETWEEN 1 AND 5) OR '
        '(wellbeing_score_scale = 10 AND mood_score BETWEEN 1 AND 10))',
    'CHECK (energy_score IS NULL OR '
        '(COALESCE(wellbeing_score_scale, 5) = 5 AND energy_score BETWEEN 1 AND 5) OR '
        '(wellbeing_score_scale = 10 AND energy_score BETWEEN 1 AND 10))',
    'CHECK (mood_description IS NULL OR length(mood_description) <= 80)',
    'CHECK (energy_description IS NULL OR length(energy_description) <= 80)',
    'CHECK (research_minutes IS NULL OR research_minutes >= 0)',
    'CHECK (learning_minutes IS NULL OR learning_minutes >= 0)',
    "CHECK (record_status IN ('draft', 'completed'))",
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
