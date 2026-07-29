import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('JournalPromptConfigurationRow')
class JournalPromptConfigurations extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  TextColumn get userId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get logicalKey => text().withDefault(const Constant('default'))();

  IntColumn get configurationVersion =>
      integer().withDefault(const Constant(1))();

  @override
  List<String> get customConstraints => const [
    "CHECK (logical_key = 'default')",
    'CHECK (configuration_version >= 1)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
