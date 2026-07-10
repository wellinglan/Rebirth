import 'package:drift/drift.dart';

import 'common_columns.dart';
import 'user_profiles_table.dart';

@DataClassName('AppSetting')
class AppSettings extends Table with UuidPrimaryKey, SyncableColumns {
  @override
  String get tableName => 'app_settings';

  TextColumn get userId => text()
      .references(UserProfiles, #id, onDelete: KeyAction.restrict)
      .unique()();

  TextColumn get localInstallationId => text().withLength(min: 36, max: 36)();

  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  TextColumn get locale => text().withDefault(const Constant('zh_CN'))();

  IntColumn get firstDayOfWeek => integer().withDefault(const Constant(1))();

  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get aiDataSharingEnabled =>
      boolean().withDefault(const Constant(false))();

  IntColumn get aiDataSharingConsentAt => integer().nullable()();

  BoolColumn get cloudSyncEnabled =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => const [
    "CHECK (theme_mode IN ('system', 'light', 'dark'))",
    'CHECK (length(trim(locale)) > 0)',
    'CHECK (first_day_of_week BETWEEN 1 AND 7)',
    'CHECK (onboarding_completed IN (0, 1))',
    'CHECK (ai_data_sharing_enabled IN (0, 1))',
    'CHECK (cloud_sync_enabled IN (0, 1))',
    'CHECK (ai_data_sharing_consent_at IS NULL OR ai_data_sharing_consent_at >= 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    "CHECK (sync_status IN ('local_only', 'pending', 'synced', 'conflict'))",
    'CHECK (server_version IS NULL OR server_version >= 0)',
    'CHECK (last_synced_at IS NULL OR last_synced_at >= 0)',
  ];
}
