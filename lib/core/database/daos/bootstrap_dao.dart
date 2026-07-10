import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/app_settings_table.dart';
import '../tables/user_profiles_table.dart';

part 'bootstrap_dao.g.dart';

const _uuid = Uuid();

final class DatabaseBootstrapResult {
  const DatabaseBootstrapResult({
    required this.activeUser,
    required this.settings,
  });

  final UserProfile activeUser;
  final AppSetting settings;

  String get activeUserId => activeUser.id;

  String get localInstallationId => settings.localInstallationId;
}

final class MultipleActiveUserProfilesException implements Exception {
  const MultipleActiveUserProfilesException(this.activeProfileCount);

  final int activeProfileCount;

  @override
  String toString() {
    return 'Database bootstrap found $activeProfileCount active user profiles; '
        'exactly one is required.';
  }
}

@DriftAccessor(tables: [UserProfiles, AppSettings])
class BootstrapDao extends DatabaseAccessor<AppDatabase>
    with _$BootstrapDaoMixin {
  BootstrapDao(super.attachedDatabase);

  Future<DatabaseBootstrapResult> bootstrap({
    String defaultTimezoneId = 'Etc/UTC',
  }) {
    if (defaultTimezoneId.trim().isEmpty) {
      throw ArgumentError.value(
        defaultTimezoneId,
        'defaultTimezoneId',
        'Timezone ID must not be empty.',
      );
    }

    return attachedDatabase.transaction(() async {
      final activeProfiles =
          await (select(userProfiles)..where(
                (profile) =>
                    profile.isActive.equals(true) & profile.deletedAt.isNull(),
              ))
              .get();

      if (activeProfiles.length > 1) {
        throw MultipleActiveUserProfilesException(activeProfiles.length);
      }

      final UserProfile activeUser;
      if (activeProfiles.isEmpty) {
        activeUser = await _createDefaultUser(defaultTimezoneId);
      } else {
        activeUser = activeProfiles.single;
      }

      final settings = await _getOrCreateSettings(activeUser);
      return DatabaseBootstrapResult(
        activeUser: activeUser,
        settings: settings,
      );
    });
  }

  Future<UserProfile> _createDefaultUser(String timezoneId) async {
    final profileId = _uuid.v4();
    final installationId = _uuid.v4();

    await into(userProfiles).insert(
      UserProfilesCompanion.insert(
        id: Value(profileId),
        timezoneId: timezoneId,
        originDeviceId: Value(installationId),
      ),
    );
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        id: Value(_uuid.v4()),
        userId: profileId,
        localInstallationId: installationId,
        originDeviceId: Value(installationId),
      ),
    );

    return (select(
      userProfiles,
    )..where((row) => row.id.equals(profileId))).getSingle();
  }

  Future<AppSetting> _getOrCreateSettings(UserProfile activeUser) async {
    final existingSettings =
        await (select(appSettings)
              ..where((settings) => settings.userId.equals(activeUser.id)))
            .getSingleOrNull();
    if (existingSettings != null) {
      return existingSettings;
    }

    final installationId = _uuid.v4();
    final settingsId = _uuid.v4();
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        id: Value(settingsId),
        userId: activeUser.id,
        localInstallationId: installationId,
        originDeviceId: Value(installationId),
      ),
    );

    return (select(
      appSettings,
    )..where((row) => row.id.equals(settingsId))).getSingle();
  }
}
