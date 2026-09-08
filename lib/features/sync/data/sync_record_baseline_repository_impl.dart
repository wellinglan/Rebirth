import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

final class SyncRecordBaselineRepositoryImpl
    implements SyncRecordBaselineRepository {
  const SyncRecordBaselineRepositoryImpl(this._database);

  final db.AppDatabase _database;

  @override
  Future<SyncRecordBaseline?> read({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    final row =
        await (_database.select(_database.syncRecordBaselines)..where(
              (row) =>
                  row.localUserId.equals(localUserId) &
                  row.entityType.equals(entityType) &
                  row.recordId.equals(recordId),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> write(SyncRecordBaseline baseline) async {
    final hashes = jsonEncode(
      Map.fromEntries(
        baseline.groupHashes.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)),
      ),
    );
    await _database
        .into(_database.syncRecordBaselines)
        .insertOnConflictUpdate(
          db.SyncRecordBaselinesCompanion.insert(
            localUserId: baseline.localUserId,
            entityType: baseline.entityType,
            recordId: baseline.recordId,
            baseExists: baseline.baseExists,
            baseServerVersion: baseline.baseServerVersion,
            baseTombstone: baseline.baseTombstone,
            groupHashesJson: hashes,
            capturedAt: baseline.capturedAt,
          ),
        );
  }

  @override
  Future<void> delete({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    await (_database.delete(_database.syncRecordBaselines)..where(
          (row) =>
              row.localUserId.equals(localUserId) &
              row.entityType.equals(entityType) &
              row.recordId.equals(recordId),
        ))
        .go();
  }

  SyncRecordBaseline _toDomain(db.SyncRecordBaselineRow row) {
    final decoded = jsonDecode(row.groupHashesJson);
    if (decoded is! Map ||
        decoded.entries.any(
          (entry) => entry.key is! String || entry.value is! String,
        )) {
      throw const FormatException('Invalid sync baseline hash map.');
    }
    return SyncRecordBaseline(
      localUserId: row.localUserId,
      entityType: row.entityType,
      recordId: row.recordId,
      baseExists: row.baseExists,
      baseServerVersion: row.baseServerVersion,
      baseTombstone: row.baseTombstone,
      groupHashes: Map<String, String>.from(decoded),
      capturedAt: row.capturedAt,
    );
  }
}
