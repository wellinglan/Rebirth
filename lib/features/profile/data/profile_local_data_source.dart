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
}
