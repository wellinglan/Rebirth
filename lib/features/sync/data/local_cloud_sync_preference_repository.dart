import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/daos/bootstrap_dao.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/domain/cloud_sync_preference_repository.dart';

final class LocalCloudSyncPreferenceRepository
    implements CloudSyncPreferenceRepository {
  const LocalCloudSyncPreferenceRepository({
    required this.database,
    required this.dateTimeService,
  });

  final AppDatabase database;
  final DateTimeService dateTimeService;

  @override
  Future<bool> readEnabled(String localUserId) async {
    final bootstrap = await _bootstrapFor(localUserId);
    return bootstrap.settings.cloudSyncEnabled;
  }

  @override
  Future<bool> setEnabled({
    required String localUserId,
    required bool enabled,
  }) async {
    final bootstrap = await _bootstrapFor(localUserId);
    if (bootstrap.settings.cloudSyncEnabled == enabled) return enabled;

    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await (database.update(
      database.appSettings,
    )..where((row) => row.id.equals(bootstrap.settings.id))).write(
      AppSettingsCompanion(
        cloudSyncEnabled: Value(enabled),
        updatedAt: Value(now),
      ),
    );
    return enabled;
  }

  Future<DatabaseBootstrapResult> _bootstrapFor(String localUserId) async {
    final normalized = localUserId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(localUserId, 'localUserId');
    }
    final bootstrap = await database.bootstrapDao.bootstrap();
    if (bootstrap.activeUserId != normalized) {
      throw StateError('Cloud sync preference account scope changed.');
    }
    return bootstrap;
  }
}
