import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final class JournalLocalDataSource {
  const JournalLocalDataSource(this.database);

  final AppDatabase database;

  Future<JournalEntry> insertEntry({
    required String userId,
    required String entryDate,
    required int timezoneOffsetMinutes,
    required int timestamp,
    required String originDeviceId,
    required String? mostImportantAccomplishment,
    required String? mostDrainingEvent,
    required String? emotionSource,
    required String? learning,
    required String? tomorrowAdjustment,
    required String entryStatus,
  }) async {
    final id = _uuid.v4();
    final todayRecordId = await _findTodayRecordId(
      userId: userId,
      entryDate: entryDate,
    );

    await database
        .into(database.journalEntries)
        .insert(
          JournalEntriesCompanion.insert(
            id: Value(id),
            userId: userId,
            todayRecordId: Value(todayRecordId),
            entryDate: entryDate,
            timezoneOffsetMinutes: timezoneOffsetMinutes,
            mostImportantAccomplishment: Value(mostImportantAccomplishment),
            mostDrainingEvent: Value(mostDrainingEvent),
            emotionSource: Value(emotionSource),
            learning: Value(learning),
            tomorrowAdjustment: Value(tomorrowAdjustment),
            entryStatus: Value(entryStatus),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
            originDeviceId: Value(originDeviceId),
          ),
        );

    return (await selectById(userId: userId, id: id))!;
  }

  Future<JournalEntry?> selectById({
    required String userId,
    required String id,
  }) {
    return (database.select(database.journalEntries)..where(
          (row) =>
              row.userId.equals(userId) &
              row.id.equals(id) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<List<JournalEntry>> selectRecent({
    required String userId,
    required int limit,
  }) {
    return (_activeEntries(userId)
          ..orderBy(_recentFirst)
          ..limit(limit))
        .get();
  }

  Future<List<JournalEntry>> selectByDate({
    required String userId,
    required String entryDate,
  }) {
    return (_activeEntries(userId)
          ..where((row) => row.entryDate.equals(entryDate))
          ..orderBy(_recentFirst))
        .get();
  }

  Future<List<JournalEntry>> selectByDateRange({
    required String userId,
    required String startDate,
    required String endDate,
    int? limit,
  }) {
    final query = _activeEntries(userId)
      ..where(
        (row) =>
            row.entryDate.isBiggerOrEqualValue(startDate) &
            row.entryDate.isSmallerOrEqualValue(endDate),
      )
      ..orderBy(_recentFirst);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }

  Future<JournalEntry?> updateById({
    required String userId,
    required String id,
    required JournalEntriesCompanion changes,
  }) async {
    final affectedRows =
        await (database.update(database.journalEntries)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.id.equals(id) &
                  row.deletedAt.isNull(),
            ))
            .write(changes);
    if (affectedRows == 0) {
      return null;
    }
    return selectById(userId: userId, id: id);
  }

  Future<bool> softDeleteById({
    required String userId,
    required String id,
    required int timestamp,
  }) async {
    final affectedRows =
        await (database.update(database.journalEntries)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.id.equals(id) &
                  row.deletedAt.isNull(),
            ))
            .write(
              JournalEntriesCompanion(
                deletedAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
    return affectedRows > 0;
  }

  SimpleSelectStatement<$JournalEntriesTable, JournalEntry> _activeEntries(
    String userId,
  ) {
    return database.select(database.journalEntries)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
  }

  List<OrderingTerm Function($JournalEntriesTable)> get _recentFirst => [
    (row) => OrderingTerm.desc(row.updatedAt),
    (row) => OrderingTerm.desc(row.createdAt),
    (row) => OrderingTerm.desc(row.entryDate),
  ];

  Future<String?> _findTodayRecordId({
    required String userId,
    required String entryDate,
  }) async {
    final today =
        await (database.select(database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(entryDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }
}
