import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/features/profile/domain/profile_repository.dart';
import 'package:rebirth/features/profile/domain/profile_save_data.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';

import 'profile_local_data_source.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required db.AppDatabase database,
    required this.dateTimeService,
  }) : _database = database,
       _localDataSource = ProfileLocalDataSource(database);

  final db.AppDatabase _database;
  final DateTimeService dateTimeService;
  final ProfileLocalDataSource _localDataSource;

  @override
  Future<UserProfile> getActiveProfile() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final profile = await _localDataSource.selectActiveById(
      bootstrap.activeUserId,
    );
    if (profile == null) {
      throw StateError('Bootstrap active user profile is unavailable.');
    }
    return _toDomain(profile);
  }

  @override
  Future<UserProfile> saveProfile(ProfileSaveData data) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final updated = await _localDataSource.updateAllowedFields(
      userId: bootstrap.activeUserId,
      displayName: data.displayName,
      growthFocus: data.growthFocus,
      updatedAt: snapshot.utcMilliseconds,
    );
    return _toDomain(updated);
  }

  @override
  Future<DeviceProfileStatus> getDeviceStatus() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return DeviceProfileStatus(
      localInstallationId: bootstrap.localInstallationId,
      activeUserId: bootstrap.activeUserId,
      isLocalMode: true,
      syncEnabled: false,
    );
  }

  UserProfile _toDomain(db.UserProfile profile) {
    return UserProfile(
      id: profile.id,
      displayName: profile.displayName,
      growthFocus: profile.growthFocus,
      timezoneId: profile.timezoneId,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }
}
