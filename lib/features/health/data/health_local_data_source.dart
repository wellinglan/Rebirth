import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final class HealthLocalDataSource {
  const HealthLocalDataSource(this.database);

  final AppDatabase database;

  Future<HealthRecord?> selectByDate({
    required String userId,
    required String recordDate,
  }) {
    return (_activeRecords(userId)
          ..where((row) => row.recordDate.equals(recordDate)))
        .getSingleOrNull();
  }

  Future<List<HealthRecord>> selectByDateRange({
    required String userId,
    required String startDate,
    required String endDate,
  }) {
    return (_activeRecords(userId)
          ..where(
            (row) =>
                row.recordDate.isBiggerOrEqualValue(startDate) &
                row.recordDate.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.recordDate)]))
        .get();
  }

  Future<HealthRecord> upsertByDate({
    required String userId,
    required HealthSaveData data,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
  }) {
    return database.transaction(() async {
      final existing = await selectByDate(
        userId: userId,
        recordDate: data.recordDate,
      );
      final todayRecordId = await findTodayRecordId(
        userId: userId,
        recordDate: data.recordDate,
      );

      if (existing == null) {
        await database
            .into(database.healthRecords)
            .insert(
              HealthRecordsCompanion.insert(
                id: Value(_uuid.v4()),
                userId: userId,
                todayRecordId: Value(todayRecordId),
                recordDate: data.recordDate,
                timezoneOffsetMinutes: timezoneOffsetMinutes,
                sleepDurationMinutes: Value(data.sleepDurationMinutes),
                weightKg: Value(data.weightKg),
                waterIntakeMl: Value(data.waterIntakeMl),
                exerciseDurationMinutes: Value(data.exerciseDurationMinutes),
                exerciseType: Value(data.exerciseType),
                physicalStateScore: Value(data.physicalStateScore),
                note: Value(data.note),
                createdAt: Value(timestamp),
                updatedAt: Value(timestamp),
                originDeviceId: Value(originDeviceId),
              ),
            );
      } else {
        await (database.update(
          database.healthRecords,
        )..where((row) => row.id.equals(existing.id))).write(
          HealthRecordsCompanion(
            todayRecordId: Value(todayRecordId),
            timezoneOffsetMinutes: Value(timezoneOffsetMinutes),
            sleepDurationMinutes: Value(data.sleepDurationMinutes),
            weightKg: Value(data.weightKg),
            waterIntakeMl: Value(data.waterIntakeMl),
            exerciseDurationMinutes: Value(data.exerciseDurationMinutes),
            exerciseType: Value(data.exerciseType),
            physicalStateScore: Value(data.physicalStateScore),
            note: Value(data.note),
            updatedAt: Value(timestamp),
          ),
        );
      }

      return (await selectByDate(
        userId: userId,
        recordDate: data.recordDate,
      ))!;
    });
  }

  Future<String?> findTodayRecordId({
    required String userId,
    required String recordDate,
  }) async {
    final today =
        await (database.select(database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(recordDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }

  SimpleSelectStatement<$HealthRecordsTable, HealthRecord> _activeRecords(
    String userId,
  ) {
    return database.select(database.healthRecords)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
  }
}
