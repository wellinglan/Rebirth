import 'package:drift/drift.dart';

import 'common_columns.dart';

@DataClassName('UserProfile')
class UserProfiles extends Table
    with UuidPrimaryKey, SyncableColumns, SoftDeleteColumn {
  @override
  String get tableName => 'user_profiles';

  TextColumn get displayName => text().nullable()();

  TextColumn get growthFocus => text().nullable()();

  TextColumn get timezoneId => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(timezone_id)) > 0)',
    'CHECK (is_active IN (0, 1))',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    'CHECK (deleted_at IS NULL OR deleted_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
