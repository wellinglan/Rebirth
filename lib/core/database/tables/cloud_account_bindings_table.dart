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

  TextColumn get verificationStatus =>
      text().withDefault(const Constant('verified'))();

  IntColumn get verificationTime => integer().nullable()();

  TextColumn get verificationMethod => text().nullable()();

  TextColumn get verificationReason => text().nullable()();

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
    "CHECK (verification_status IN ('not_verified', 'verified', 'failed'))",
    'CHECK (verification_time IS NULL OR verification_time >= 0)',
    "CHECK (verification_method IS NULL OR verification_method IN ("
        "'account_space_creation', 'server_sync_metadata_v1'))",
    "CHECK (verification_reason IS NULL OR verification_reason IN ("
        "'all_evidence_matches_current_user', 'no_verifiable_evidence', "
        "'remote_record_missing', 'metadata_mismatch_or_other_owner'))",
    "CHECK (verification_status != 'verified' OR "
        '(verification_time IS NOT NULL AND verification_method IS NOT NULL))',
    "CHECK ((sync_eligibility_status = 'ready' AND "
        "verification_status = 'verified') OR "
        "(sync_eligibility_status = 'legacy_review_required' AND "
        "verification_status IN ('not_verified', 'failed')))",
  ];
}
