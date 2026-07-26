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

  TextColumn get bindingOrigin =>
      text().withDefault(const Constant('clean_first_login'))();

  TextColumn get syncEligibilityStatus =>
      text().withDefault(const Constant('ready'))();

  IntColumn get ownershipConfirmedAt => integer().nullable()();

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
    "CHECK (binding_origin IN ("
        "'clean_first_login', 'fresh_space', 'legacy_claim'))",
    "CHECK (sync_eligibility_status IN ("
        "'ready', 'legacy_review_required'))",
    'CHECK (ownership_confirmed_at IS NULL OR ownership_confirmed_at >= 0)',
    "CHECK (binding_origin != 'legacy_claim' "
        'OR ownership_confirmed_at IS NOT NULL)',
  ];
}
