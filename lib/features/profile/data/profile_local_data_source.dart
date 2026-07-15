import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;

final class ProfileLocalDataSource {
  const ProfileLocalDataSource(this.database);

  final db.AppDatabase database;

  Future<db.UserProfile?> selectActiveById(String userId) {
    return (database.select(database.userProfiles)..where(
          (row) =>
              row.id.equals(userId) &
              row.isActive.equals(true) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<db.UserProfile> updateAllowedFields({
    required String userId,
    required String? displayName,
    required String? growthFocus,
    required int updatedAt,
  }) async {
    final affected =
        await (database.update(database.userProfiles)..where(
              (row) =>
                  row.id.equals(userId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .write(
              db.UserProfilesCompanion(
                displayName: Value(displayName),
                growthFocus: Value(growthFocus),
                updatedAt: Value(updatedAt),
                syncStatus: const Value('pending'),
              ),
            );
    if (affected != 1) {
      throw StateError('Active user profile could not be updated.');
    }

    final updated = await selectActiveById(userId);
    if (updated == null) {
      throw StateError('Active user profile disappeared after update.');
    }
    return updated;
  }

  Future<db.UserProfile> updateSyncMetadata({
    required String userId,
    required String syncStatus,
    required int serverVersion,
    required int lastSyncedAt,
    required String originDeviceId,
  }) {
    return _updateActive(
      userId,
      db.UserProfilesCompanion(
        syncStatus: Value(syncStatus),
        serverVersion: Value(serverVersion),
        lastSyncedAt: Value(lastSyncedAt),
        originDeviceId: Value(originDeviceId),
      ),
    );
  }

  Future<db.UserProfile> markSyncConflict(String userId) {
    return _updateActive(
      userId,
      const db.UserProfilesCompanion(syncStatus: Value('conflict')),
    );
  }

  Future<db.UserProfile> applyRemoteProfile({
    required String userId,
    required String? displayName,
    required String? growthFocus,
    required String timezoneId,
    required int updatedAt,
    required int serverVersion,
    required int lastSyncedAt,
    required String originDeviceId,
  }) {
    return _updateActive(
      userId,
      db.UserProfilesCompanion(
        displayName: Value(displayName),
        growthFocus: Value(growthFocus),
        timezoneId: Value(timezoneId),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('synced'),
        serverVersion: Value(serverVersion),
        lastSyncedAt: Value(lastSyncedAt),
        originDeviceId: Value(originDeviceId),
      ),
    );
  }

  Future<db.UserProfile> _updateActive(
    String userId,
    db.UserProfilesCompanion companion,
  ) async {
    final affected =
        await (database.update(database.userProfiles)..where(
              (row) =>
                  row.id.equals(userId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .write(companion);
    if (affected != 1) {
      throw StateError('Active user profile could not be updated.');
    }
    final updated = await selectActiveById(userId);
    if (updated == null) {
      throw StateError('Active user profile disappeared after update.');
    }
    return updated;
  }
}
