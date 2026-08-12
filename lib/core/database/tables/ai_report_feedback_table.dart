import 'package:drift/drift.dart';

import 'ai_reports_table.dart';
import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('AiReportFeedbackRow')
class AiReportFeedback extends Table with UuidPrimaryKey, TimestampColumns {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get reportId =>
      text().references(AiReports, #id, onDelete: KeyAction.restrict)();

  IntColumn get reportVersion => integer()();

  TextColumn get reportType => text()();

  TextColumn get helpfulness => text()();

  TextColumn get reasonCodesJson => text().withDefault(const Constant('[]'))();

  TextColumn get promptId => text()();

  TextColumn get promptVersion => text()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('local_only'))();

  IntColumn get serverVersion => integer().nullable()();

  IntColumn get lastSyncedAt => integer().nullable()();

  IntColumn get deletedAt => integer().nullable()();

  TextColumn get remoteSnapshotJson => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, reportId, reportVersion},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (report_version > 0)',
    "CHECK (report_type IN ('daily_insight', 'weekly_report', 'monthly_reflection', 'tomorrow_suggestion', 'trend_explanation'))",
    "CHECK (helpfulness IN ('helpful', 'not_helpful'))",
    'CHECK (length(trim(prompt_id)) > 0)',
    'CHECK (length(trim(prompt_version)) > 0)',
    "CHECK (sync_status IN ('local_only', 'pending_push', 'synced', 'conflict', 'pending_delete'))",
    'CHECK (server_version IS NULL OR server_version >= 1)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= created_at)',
    'CHECK (deleted_at IS NULL OR deleted_at >= created_at)',
    "CHECK (sync_status = 'conflict' OR remote_snapshot_json IS NULL)",
  ];
}
