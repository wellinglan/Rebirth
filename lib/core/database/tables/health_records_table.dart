import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'today_records_table.dart';
import 'user_profiles_table.dart';

@DataClassName('HealthRecord')
class HealthRecords extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get todayRecordId => text()
      .references(TodayRecords, #id, onDelete: KeyAction.setNull)
      .nullable()();

  TextColumn get recordDate => text()();

  IntColumn get timezoneOffsetMinutes => integer()();

  IntColumn get sleepDurationMinutes => integer().nullable()();

  RealColumn get weightKg => real().nullable()();

  IntColumn get waterIntakeMl => integer().nullable()();

  TextColumn get exerciseType => text().nullable()();

  IntColumn get exerciseDurationMinutes => integer().nullable()();

  IntColumn get physicalStateScore => integer().nullable()();

  TextColumn get note => text().nullable()();

  TextColumn get dataSource => text().withDefault(const Constant('manual'))();

  TextColumn get sourceRecordId => text().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (record_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    'CHECK (timezone_offset_minutes BETWEEN -840 AND 840)',
    'CHECK (sleep_duration_minutes IS NULL OR sleep_duration_minutes >= 0)',
    'CHECK (weight_kg IS NULL OR weight_kg > 0)',
    'CHECK (water_intake_ml IS NULL OR water_intake_ml >= 0)',
    'CHECK (exercise_duration_minutes IS NULL OR exercise_duration_minutes >= 0)',
    'CHECK (physical_state_score IS NULL OR physical_state_score BETWEEN 1 AND 5)',
    "CHECK (data_source IN ('manual', 'health_connect', 'apple_health'))",
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
