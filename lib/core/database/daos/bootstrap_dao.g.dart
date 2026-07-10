// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_dao.dart';

// ignore_for_file: type=lint
mixin _$BootstrapDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  BootstrapDaoManager get managers => BootstrapDaoManager(this);
}

class BootstrapDaoManager {
  final _$BootstrapDaoMixin _db;
  BootstrapDaoManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
}
