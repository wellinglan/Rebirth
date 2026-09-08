import 'package:drift/drift.dart';

import 'user_profiles_table.dart';

@DataClassName('SyncRecordBaselineRow')
class SyncRecordBaselines extends Table {
  TextColumn get localUserId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.cascade)();

  TextColumn get entityType => text()();

  TextColumn get recordId => text()();

  BoolColumn get baseExists => boolean()();

  IntColumn get baseServerVersion => integer()();

  BoolColumn get baseTombstone => boolean()();

  TextColumn get groupHashesJson => text()();

  IntColumn get capturedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {localUserId, entityType, recordId};

  @override
  List<String> get customConstraints => const [
    "CHECK (entity_type IN ("
        "'user_profiles', 'today_records', 'journal_prompt_configurations', "
        "'journal_entries', 'goals', 'health_records', 'ai_reports', "
        "'ai_report_feedback'))",
    'CHECK (length(trim(record_id)) > 0)',
    'CHECK (base_exists IN (0, 1))',
    'CHECK (base_server_version >= 0)',
    'CHECK (base_tombstone IN (0, 1))',
    'CHECK (base_exists = 1 OR base_tombstone = 0)',
    'CHECK (length(trim(group_hashes_json)) > 0)',
    'CHECK (captured_at >= 0)',
  ];
}
