import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('AiReport')
class AiReports extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get reportType => text()();

  TextColumn get periodStartDate => text()();

  TextColumn get periodEndDate => text()();

  TextColumn get inputSourcesJson => text().withDefault(const Constant('[]'))();

  TextColumn get inputHash => text()();

  TextColumn get inputSnapshotJson => text().nullable()();

  TextColumn get promptVersion => text()();

  TextColumn get provider => text().nullable()();

  TextColumn get model => text().nullable()();

  TextColumn get generationMode =>
      text().withDefault(const Constant('manual'))();

  TextColumn get reportStatus =>
      text().withDefault(const Constant('pending'))();

  TextColumn get reportContent => text().nullable()();

  TextColumn get structuredOutputJson => text().nullable()();

  TextColumn get errorCode => text().nullable()();

  IntColumn get requestedAt => integer()();

  IntColumn get generatedAt => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (report_type IN ('daily_insight', 'weekly_report', 'monthly_reflection', 'tomorrow_suggestion', 'trend_explanation'))",
    "CHECK (period_start_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    "CHECK (period_end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    'CHECK (period_end_date >= period_start_date)',
    'CHECK (length(trim(input_hash)) > 0)',
    'CHECK (length(trim(prompt_version)) > 0)',
    "CHECK (generation_mode IN ('manual', 'automatic'))",
    "CHECK (report_status IN ('pending', 'completed', 'failed'))",
    "CHECK (report_status != 'completed' OR report_content IS NOT NULL)",
    'CHECK (requested_at >= 0)',
    'CHECK (generated_at IS NULL OR generated_at >= 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
