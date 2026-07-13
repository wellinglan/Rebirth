import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final class TodayDatabaseEntry {
  const TodayDatabaseEntry({required this.today, required this.health});

  final TodayRecord today;
  final HealthRecord? health;
}

final class TodayRecordNotFoundException implements Exception {
  const TodayRecordNotFoundException(this.recordDate);

  final String recordDate;

  @override
  String toString() => 'No active Today record exists for $recordDate.';
}

final class TodayLocalDataSource {
  const TodayLocalDataSource(this.database);

  final AppDatabase database;

  Future<TodayDatabaseEntry?> getByDate({
    required String userId,
    required String recordDate,
  }) async {
    final today = await _findToday(userId: userId, recordDate: recordDate);
    if (today == null) {
      return null;
    }

    return TodayDatabaseEntry(
      today: today,
      health: await _findHealth(userId: userId, recordDate: recordDate),
    );
  }

  Future<List<TodayDatabaseEntry>> selectByDateRange({
    required String userId,
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    final todayQuery = database.select(database.todayRecords)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.recordDate.isBiggerOrEqualValue(startDate) &
            row.recordDate.isSmallerOrEqualValue(endDate) &
            row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.recordDate)]);
    if (limit != null) {
      todayQuery.limit(limit);
    }

    final todayRecords = await todayQuery.get();
    if (todayRecords.isEmpty) {
      return const <TodayDatabaseEntry>[];
    }

    final includedDates = todayRecords
        .map((record) => record.recordDate)
        .toSet();
    final healthRecords =
        await (database.select(database.healthRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.isBiggerOrEqualValue(startDate) &
                  row.recordDate.isSmallerOrEqualValue(endDate) &
                  row.deletedAt.isNull(),
            ))
            .get();
    final healthByDate = <String, HealthRecord>{
      for (final health in healthRecords)
        if (includedDates.contains(health.recordDate))
          health.recordDate: health,
    };

    return todayRecords
        .map(
          (today) => TodayDatabaseEntry(
            today: today,
            health: healthByDate[today.recordDate],
          ),
        )
        .toList(growable: false);
  }

  Future<TodayDatabaseEntry> getOrCreate({
    required String userId,
    required String recordDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
  }) {
    return database.transaction(() async {
      await _ensureToday(
        userId: userId,
        recordDate: recordDate,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        timestamp: timestamp,
        originDeviceId: originDeviceId,
      );
      return (await getByDate(userId: userId, recordDate: recordDate))!;
    });
  }

  Future<TodayDatabaseEntry> updateToday({
    required String userId,
    required String recordDate,
    required TodayRecordsCompanion changes,
  }) {
    return database.transaction(() async {
      final today = await _findToday(userId: userId, recordDate: recordDate);
      if (today == null) {
        throw TodayRecordNotFoundException(recordDate);
      }

      await (database.update(
        database.todayRecords,
      )..where((row) => row.id.equals(today.id))).write(changes);

      return (await getByDate(userId: userId, recordDate: recordDate))!;
    });
  }

  Future<TodayDatabaseEntry> saveAggregate({
    required String userId,
    required String recordDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
    required TodayRecordsCompanion todayChanges,
    required TodayHealthInput? health,
  }) {
    return database.transaction(() async {
      final today = await _ensureToday(
        userId: userId,
        recordDate: recordDate,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        timestamp: timestamp,
        originDeviceId: originDeviceId,
      );

      await (database.update(
        database.todayRecords,
      )..where((row) => row.id.equals(today.id))).write(todayChanges);

      if (health != null) {
        await _upsertHealth(
          todayRecordId: today.id,
          userId: userId,
          recordDate: recordDate,
          timezoneOffsetMinutes: timezoneOffsetMinutes,
          timestamp: timestamp,
          originDeviceId: originDeviceId,
          health: health,
        );
      }

      return (await getByDate(userId: userId, recordDate: recordDate))!;
    });
  }

  Future<TodayRecord> _ensureToday({
    required String userId,
    required String recordDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
  }) async {
    final existing = await _findToday(userId: userId, recordDate: recordDate);
    if (existing != null) {
      return existing;
    }

    final id = _uuid.v4();
    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            id: Value(id),
            userId: userId,
            recordDate: recordDate,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
            originDeviceId: Value(originDeviceId),
          ),
        );

    return (await _findToday(userId: userId, recordDate: recordDate))!;
  }

  Future<void> _upsertHealth({
    required String todayRecordId,
    required String userId,
    required String recordDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
    required TodayHealthInput health,
  }) async {
    final existing = await _findHealth(userId: userId, recordDate: recordDate);

    if (existing == null) {
      await database
          .into(database.healthRecords)
          .insert(
            HealthRecordsCompanion.insert(
              id: Value(_uuid.v4()),
              userId: userId,
              todayRecordId: Value(todayRecordId),
              recordDate: recordDate,
              timezoneOffsetMinutes: timezoneOffsetMinutes,
              sleepDurationMinutes: Value(health.sleepDurationMinutes),
              weightKg: Value(health.weightKg),
              waterIntakeMl: Value(health.waterIntakeMl),
              exerciseType: Value(health.exerciseType),
              exerciseDurationMinutes: Value(health.exerciseDurationMinutes),
              physicalStateScore: Value(health.physicalStateScore),
              note: Value(health.note),
              createdAt: Value(timestamp),
              updatedAt: Value(timestamp),
              originDeviceId: Value(originDeviceId),
            ),
          );
      return;
    }

    await (database.update(
      database.healthRecords,
    )..where((row) => row.id.equals(existing.id))).write(
      HealthRecordsCompanion(
        todayRecordId: Value(todayRecordId),
        sleepDurationMinutes: Value(health.sleepDurationMinutes),
        weightKg: Value(health.weightKg),
        waterIntakeMl: Value(health.waterIntakeMl),
        exerciseType: Value(health.exerciseType),
        exerciseDurationMinutes: Value(health.exerciseDurationMinutes),
        physicalStateScore: Value(health.physicalStateScore),
        note: Value(health.note),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<TodayRecord?> _findToday({
    required String userId,
    required String recordDate,
  }) {
    return (database.select(database.todayRecords)..where(
          (row) =>
              row.userId.equals(userId) &
              row.recordDate.equals(recordDate) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<HealthRecord?> _findHealth({
    required String userId,
    required String recordDate,
  }) {
    return (database.select(database.healthRecords)..where(
          (row) =>
              row.userId.equals(userId) &
              row.recordDate.equals(recordDate) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }
}
