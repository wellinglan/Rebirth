import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_local_data_source.dart';

final class JournalRepositoryImpl implements JournalRepository {
  JournalRepositoryImpl({
    required db.AppDatabase database,
    required this.dateTimeService,
  }) : _database = database,
       _localDataSource = JournalLocalDataSource(database);

  final db.AppDatabase _database;
  final DateTimeService dateTimeService;
  final JournalLocalDataSource _localDataSource;

  @override
  Future<JournalEntry> createEntry(JournalSaveData data) async {
    final content = _normalize(data);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.insertEntry(
      userId: bootstrap.activeUserId,
      entryDate: snapshot.localDateString,
      timezoneOffsetMinutes: snapshot.timezoneOffsetMinutes,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
      mostImportantAccomplishment: content.mostImportantAccomplishment,
      mostDrainingEvent: content.mostDrainingEvent,
      emotionSource: content.emotionSource,
      learning: content.learning,
      tomorrowAdjustment: content.tomorrowAdjustment,
      entryStatus: data.status.name,
    );
    return _toDomain(entry);
  }

  @override
  Future<JournalEntry?> getById(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.selectById(
      userId: bootstrap.activeUserId,
      id: id,
    );
    return entry == null ? null : _toDomain(entry);
  }

  @override
  Future<List<JournalEntry>> listRecent({int limit = 20}) async {
    _validateLimit(limit);
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectRecent(
        userId: bootstrap.activeUserId,
        limit: limit,
      ),
    );
  }

  @override
  Future<List<JournalEntry>> listByDate(String entryDate) async {
    _validateDate(entryDate, 'entryDate');
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectByDate(
        userId: bootstrap.activeUserId,
        entryDate: entryDate,
      ),
    );
  }

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    _validateDate(startDate, 'startDate');
    _validateDate(endDate, 'endDate');
    if (startDate.compareTo(endDate) > 0) {
      throw ArgumentError('startDate must not be after endDate.');
    }
    if (limit != null) {
      _validateLimit(limit);
    }

    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapEntries(
      await _localDataSource.selectByDateRange(
        userId: bootstrap.activeUserId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      ),
    );
  }

  @override
  Future<JournalEntry> updateEntry({
    required String id,
    required JournalSaveData data,
  }) async {
    final content = _normalize(data);
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final entry = await _localDataSource.updateById(
      userId: bootstrap.activeUserId,
      id: id,
      changes: db.JournalEntriesCompanion(
        mostImportantAccomplishment: Value(content.mostImportantAccomplishment),
        mostDrainingEvent: Value(content.mostDrainingEvent),
        emotionSource: Value(content.emotionSource),
        learning: Value(content.learning),
        tomorrowAdjustment: Value(content.tomorrowAdjustment),
        entryStatus: Value(data.status.name),
        updatedAt: Value(snapshot.utcMilliseconds),
      ),
    );
    if (entry == null) {
      throw JournalEntryNotFoundException(id);
    }
    return _toDomain(entry);
  }

  @override
  Future<void> softDelete(String id) async {
    final snapshot = dateTimeService.currentSnapshot();
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final deleted = await _localDataSource.softDeleteById(
      userId: bootstrap.activeUserId,
      id: id,
      timestamp: snapshot.utcMilliseconds,
    );
    if (!deleted) {
      throw JournalEntryNotFoundException(id);
    }
  }

  JournalEntry _toDomain(db.JournalEntry entry) {
    return JournalEntry(
      id: entry.id,
      userId: entry.userId,
      todayRecordId: entry.todayRecordId,
      entryDate: entry.entryDate,
      timezoneOffsetMinutes: entry.timezoneOffsetMinutes,
      mostImportantAccomplishment: entry.mostImportantAccomplishment,
      mostDrainingEvent: entry.mostDrainingEvent,
      emotionSource: entry.emotionSource,
      learning: entry.learning,
      tomorrowAdjustment: entry.tomorrowAdjustment,
      status: switch (entry.entryStatus) {
        'draft' => JournalEntryStatus.draft,
        'completed' => JournalEntryStatus.completed,
        final value => throw StateError('Unknown journal entry status: $value'),
      },
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  List<JournalEntry> _mapEntries(List<db.JournalEntry> entries) {
    return entries.map(_toDomain).toList(growable: false);
  }

  _NormalizedJournalContent _normalize(JournalSaveData data) {
    final content = _NormalizedJournalContent(
      mostImportantAccomplishment: _trimToNull(
        data.mostImportantAccomplishment,
      ),
      mostDrainingEvent: _trimToNull(data.mostDrainingEvent),
      emotionSource: _trimToNull(data.emotionSource),
      learning: _trimToNull(data.learning),
      tomorrowAdjustment: _trimToNull(data.tomorrowAdjustment),
    );
    if (!content.hasContent) {
      throw const EmptyJournalContentException();
    }
    return content;
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _validateDate(String date, String name) {
    if (!dateTimeService.isValidLocalDateString(date)) {
      throw ArgumentError.value(
        date,
        name,
        'Expected a valid date in YYYY-MM-DD format.',
      );
    }
  }

  void _validateLimit(int limit) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be positive.');
    }
  }
}

final class _NormalizedJournalContent {
  const _NormalizedJournalContent({
    required this.mostImportantAccomplishment,
    required this.mostDrainingEvent,
    required this.emotionSource,
    required this.learning,
    required this.tomorrowAdjustment,
  });

  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;

  bool get hasContent =>
      mostImportantAccomplishment != null ||
      mostDrainingEvent != null ||
      emotionSource != null ||
      learning != null ||
      tomorrowAdjustment != null;
}
