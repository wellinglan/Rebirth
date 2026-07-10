import 'package:drift/drift.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:uuid/uuid.dart';

const databaseUuid = Uuid();
const databaseDateTimeService = DateTimeService();

int utcNowMilliseconds() =>
    databaseDateTimeService.currentUtcMillisecondsSinceEpoch();

mixin UuidPrimaryKey on Table {
  TextColumn get id =>
      text().withLength(min: 36, max: 36).clientDefault(databaseUuid.v4)();

  @override
  Set<Column> get primaryKey => {id};
}

mixin SyncableColumns on Table {
  IntColumn get createdAt => integer().clientDefault(utcNowMilliseconds)();

  IntColumn get updatedAt => integer().clientDefault(utcNowMilliseconds)();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('local_only'))();

  IntColumn get serverVersion => integer().nullable()();

  IntColumn get lastSyncedAt => integer().nullable()();

  TextColumn get originDeviceId =>
      text().withLength(min: 36, max: 36).nullable()();
}

mixin SoftDeleteColumn on Table {
  IntColumn get deletedAt => integer().nullable()();
}
