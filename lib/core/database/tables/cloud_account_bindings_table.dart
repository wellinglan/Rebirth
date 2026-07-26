import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('CloudAccountBindingRow')
class CloudAccountBindings extends Table with UuidPrimaryKey {
  TextColumn get localUserId =>
      text().references(UserProfiles, #id, onDelete: KeyAction.restrict)();

  TextColumn get endpointKey => text()();

  TextColumn get cloudUserId => text()();

  IntColumn get createdAt => integer()();

  IntColumn get lastUsedAt => integer()();

  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {endpointKey, cloudUserId},
    {localUserId},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(endpoint_key)) > 0)',
    'CHECK (length(trim(cloud_user_id)) > 0)',
    'CHECK (created_at >= 0)',
    'CHECK (last_used_at >= created_at)',
    "CHECK (status IN ('active', 'disabled'))",
  ];
}
