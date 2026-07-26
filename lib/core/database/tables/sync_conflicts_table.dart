import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('SyncConflictRow')
class SyncConflicts extends Table with UuidPrimaryKey {
  TextColumn get localUserId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get endpointKey => text()();

  TextColumn get cloudUserId => text()();

  TextColumn get entityType => text()();

  TextColumn get recordId => text()();

  TextColumn get localPayloadJson => text().nullable()();

  IntColumn get localUpdatedAt => integer()();

  IntColumn get localDeletedAt => integer().nullable()();

  IntColumn get localServerVersion => integer().nullable()();

  TextColumn get localOriginDeviceId => text().nullable()();

  TextColumn get remotePayloadJson => text().nullable()();

  TextColumn get remoteOperation => text()();

  IntColumn get remoteUpdatedAt => integer().nullable()();

  IntColumn get remoteDeletedAt => integer().nullable()();

  IntColumn get remoteServerVersion => integer()();

  TextColumn get remoteOriginDeviceId => text().nullable()();

  IntColumn get detectedAt => integer()();

  IntColumn get lastSeenAt => integer()();

  TextColumn get resolutionStatus => text()();

  IntColumn get resolvedAt => integer().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(endpoint_key)) > 0)',
    'CHECK (length(trim(cloud_user_id)) > 0)',
    "CHECK (entity_type IN ("
        "'user_profiles', 'today_records', 'journal_entries', "
        "'goals', 'health_records'))",
    'CHECK (length(trim(record_id)) > 0)',
    'CHECK (local_updated_at >= 0)',
    'CHECK (local_deleted_at IS NULL OR local_deleted_at >= 0)',
    'CHECK (local_server_version IS NULL OR local_server_version >= 0)',
    "CHECK (remote_operation IN ('upsert', 'delete', 'unknown_pending_pull'))",
    'CHECK (remote_updated_at IS NULL OR remote_updated_at >= 0)',
    'CHECK (remote_deleted_at IS NULL OR remote_deleted_at >= 0)',
    'CHECK (remote_server_version >= 0)',
    'CHECK (detected_at >= 0)',
    'CHECK (last_seen_at >= detected_at)',
    "CHECK (resolution_status IN ("
        "'unresolved', "
        "'awaiting_remote_snapshot', "
        "'adopt_remote_requested', "
        "'keep_local_requested', "
        "'resolved_adopt_remote', "
        "'resolved_keep_local', "
        "'superseded', "
        "'superseded_by_account_isolation_migration'))",
    "CHECK ((resolution_status IN ("
        "'resolved_adopt_remote', 'resolved_keep_local', 'superseded', "
        "'superseded_by_account_isolation_migration') "
        'AND resolved_at IS NOT NULL) OR '
        "(resolution_status NOT IN ("
        "'resolved_adopt_remote', 'resolved_keep_local', 'superseded', "
        "'superseded_by_account_isolation_migration') "
        'AND resolved_at IS NULL))',
    'CHECK (resolved_at IS NULL OR resolved_at >= detected_at)',
  ];
}
