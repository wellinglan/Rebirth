import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';

import 'health_local_data_source.dart';

final class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl({
    required db.AppDatabase database,
    required this.dateTimeService,
  }) : _database = database,
       _localDataSource = HealthLocalDataSource(database);

  final db.AppDatabase _database;
  final DateTimeService dateTimeService;
  final HealthLocalDataSource _localDataSource;

  @override
  Future<HealthEntry> getToday() async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final existing = await _localDataSource.selectByDate(
      userId: bootstrap.activeUserId,
      recordDate: snapshot.localDateString,
    );
    if (existing != null) {
      return _toDomain(existing);
    }
    final created = await _localDataSource.upsertByDate(
      userId: bootstrap.activeUserId,
      data: HealthSaveData(recordDate: snapshot.localDateString),
      timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );
    return _toDomain(created);
  }

  @override
  Future<HealthEntry?> getByDate(String recordDate) async {
    _validateDate(recordDate, 'recordDate');
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final record = await _localDataSource.selectByDate(
      userId: bootstrap.activeUserId,
      recordDate: recordDate,
    );
    return record == null ? null : _toDomain(record);
  }

  @override
  Future<List<HealthEntry>> listRecent({int days = 30}) async {
    _validateDays(days);
    final snapshot = dateTimeService.currentSnapshot();
    final range = dateTimeService.recentLocalDateRange(
      days,
      endingAt: snapshot.now,
    );
    final entries = await listByDateRange(
      startDate: range.first,
      endDate: range.last,
    );
    return entries.where((entry) => entry.hasMetrics).toList(growable: false);
  }

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    _validateDate(startDate, 'startDate');
    _validateDate(endDate, 'endDate');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final records = await _localDataSource.selectByDateRange(
      userId: bootstrap.activeUserId,
      startDate: startDate,
      endDate: endDate,
    );
    return records.map(_toDomain).toList(growable: false);
  }

  @override
  Future<HealthEntry> saveForDate(HealthSaveData data) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final record = await _localDataSource.upsertByDate(
      userId: bootstrap.activeUserId,
      data: data,
      timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );
    return _toDomain(record);
  }

  @override
  Future<HealthSummary> getSummary({int days = 7}) async {
    _validateDays(days);
    final entries = await listRecent(days: days);
    return HealthSummary.fromEntries(days: days, entries: entries);
  }

  HealthEntry _toDomain(db.HealthRecord record) {
    return HealthEntry(
      id: record.id,
      userId: record.userId,
      todayRecordId: record.todayRecordId,
      recordDate: record.recordDate,
      sleepDurationMinutes: record.sleepDurationMinutes,
      weightKg: record.weightKg,
      waterIntakeMl: record.waterIntakeMl,
      exerciseDurationMinutes: record.exerciseDurationMinutes,
      exerciseType: record.exerciseType,
      physicalStateScore: record.physicalStateScore,
      note: record.note,
      timezoneOffsetMinutes: record.timezoneOffsetMinutes,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  void _validateDate(String value, String name) {
    if (!dateTimeService.isValidLocalDateString(value)) {
      throw InvalidHealthDateException(value);
    }
  }

  void _validateDays(int days) {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Days must be positive.');
    }
  }
}
