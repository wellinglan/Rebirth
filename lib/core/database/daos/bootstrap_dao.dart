import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/app_settings_table.dart';
import '../tables/common_columns.dart';
import '../tables/installation_info_table.dart';
import '../tables/user_profiles_table.dart';

part 'bootstrap_dao.g.dart';

const _uuid = Uuid();

final class DatabaseBootstrapResult {
  const DatabaseBootstrapResult({
    required this.activeUser,
    required this.settings,
    required this.installation,
  });

  final UserProfile activeUser;
  final AppSetting settings;
  final InstallationInfoRow installation;

  String get activeUserId => activeUser.id;

  String get localInstallationId => installation.installationId;
}

final class ActiveUserProfileRequiredException implements Exception {
  const ActiveUserProfileRequiredException();

  @override
  String toString() {
    return 'Database bootstrap requires an authenticated active user profile.';
  }
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

@DriftAccessor(tables: [UserProfiles, AppSettings, InstallationInfo])
class BootstrapDao extends DatabaseAccessor<AppDatabase>
    with _$BootstrapDaoMixin {
  BootstrapDao(super.attachedDatabase);

  Future<DatabaseBootstrapResult> bootstrap({
    String defaultTimezoneId = 'Etc/UTC',
    bool? createUnboundProfile,
  }) {
    if (defaultTimezoneId.trim().isEmpty) {
      throw ArgumentError.value(
        defaultTimezoneId,
        'defaultTimezoneId',
        'Timezone ID must not be empty.',
      );
    }

    return attachedDatabase.transaction(() async {
      final allowUnboundProfile =
          createUnboundProfile ??
          attachedDatabase.allowUnboundProfileBootstrapForTesting;
      final installation = await _getOrCreateInstallation();
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
        if (!allowUnboundProfile) {
          throw const ActiveUserProfileRequiredException();
        }
        activeUser = await _createDefaultUser(
          defaultTimezoneId,
          installation.installationId,
        );
      } else {
        activeUser = activeProfiles.single;
      }

      final settings = await _getOrCreateSettings(
        activeUser,
        installation.installationId,
      );
      return DatabaseBootstrapResult(
        activeUser: activeUser,
        settings: settings,
        installation: installation,
      );
    });
  }

  Future<InstallationInfoRow> ensureInstallation() {
    return attachedDatabase.transaction(_getOrCreateInstallation);
  }

  Future<UserProfile> _createDefaultUser(
    String timezoneId,
    String installationId,
  ) async {
    final profileId = _uuid.v4();

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

  Future<AppSetting> _getOrCreateSettings(
    UserProfile activeUser,
    String installationId,
  ) async {
    final existingSettings =
        await (select(appSettings)
              ..where((settings) => settings.userId.equals(activeUser.id)))
            .getSingleOrNull();
    if (existingSettings != null) {
      if (existingSettings.localInstallationId != installationId) {
        await (update(
          appSettings,
        )..where((row) => row.id.equals(existingSettings.id))).write(
          AppSettingsCompanion(localInstallationId: Value(installationId)),
        );
        return (select(
          appSettings,
        )..where((row) => row.id.equals(existingSettings.id))).getSingle();
      }
      return existingSettings;
    }

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

  Future<InstallationInfoRow> _getOrCreateInstallation() async {
    final existing = await select(installationInfo).getSingleOrNull();
    if (existing != null) return existing;

    final legacySettings =
        await (select(appSettings)
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    await into(installationInfo).insert(
      InstallationInfoCompanion.insert(
        installationId: legacySettings?.localInstallationId ?? _uuid.v4(),
        createdAt: legacySettings?.createdAt ?? utcNowMilliseconds(),
      ),
    );
    return select(installationInfo).getSingle();
  }
}
