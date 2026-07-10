import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'today_records_table.dart';
import 'user_profiles_table.dart';

@DataClassName('JournalEntry')
class JournalEntries extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get todayRecordId => text()
      .references(TodayRecords, #id, onDelete: KeyAction.setNull)
      .nullable()();

  TextColumn get entryDate => text()();

  IntColumn get timezoneOffsetMinutes => integer()();

  TextColumn get mostImportantAccomplishment => text().nullable()();

  TextColumn get mostDrainingEvent => text().nullable()();

  TextColumn get emotionSource => text().nullable()();

  TextColumn get learning => text().nullable()();

  TextColumn get tomorrowAdjustment => text().nullable()();

  TextColumn get entryStatus => text().withDefault(const Constant('draft'))();

  @override
  List<String> get customConstraints => const [
    "CHECK (entry_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')",
    'CHECK (timezone_offset_minutes BETWEEN -840 AND 840)',
    "CHECK (entry_status IN ('draft', 'completed'))",
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
