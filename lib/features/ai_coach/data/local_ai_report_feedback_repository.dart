import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/deterministic_uuid.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';

final class LocalAiReportFeedbackRepository
    implements AiReportFeedbackRepository {
  const LocalAiReportFeedbackRepository({
    required this.database,
    required this.dateTimeService,
    this.reasonCodec = const AiReportFeedbackReasonCodec(),
  });

  final db.AppDatabase database;
  final DateTimeService dateTimeService;
  final AiReportFeedbackReasonCodec reasonCodec;

  @override
  Future<AiReportFeedback?> getForVersion({
    required String reportId,
    required int reportVersion,
  }) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final row = await _row(userId, reportId, reportVersion);
    if (row == null || row.deletedAt != null) return null;
    return _toDomain(row);
  }

  @override
  Future<AiReportFeedback> save({
    required String reportId,
    required int reportVersion,
    required AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons = const [],
  }) async {
    final normalizedReasons = reasons.toSet().toList()
      ..sort((left, right) => left.code.compareTo(right.code));
    if (helpfulness == AiReportHelpfulness.helpful) {
      normalizedReasons.clear();
    } else if (normalizedReasons.isEmpty) {
      throw const AiReportFeedbackNotAllowedException();
    }
    final bootstrap = await database.bootstrapDao.bootstrap();
    final report = await _eligibleVersion(
      bootstrap.activeUserId,
      reportId,
      reportVersion,
    );
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final existing = await _row(
      bootstrap.activeUserId,
      reportId,
      reportVersion,
    );
    final encoded = reasonCodec.encode(normalizedReasons);
    if (existing != null &&
        existing.deletedAt == null &&
        existing.helpfulness == helpfulness.databaseValue &&
        existing.reasonCodesJson == encoded) {
      return _toDomain(existing);
    }
    final id =
        existing?.id ??
        deterministicUuid('ai-report-feedback:$reportId:$reportVersion');
    await database
        .into(database.aiReportFeedback)
        .insertOnConflictUpdate(
          db.AiReportFeedbackCompanion.insert(
            id: Value(id),
            userId: bootstrap.activeUserId,
            reportId: reportId,
            reportVersion: reportVersion,
            reportType: report.reportType,
            helpfulness: helpfulness.databaseValue,
            reasonCodesJson: Value(encoded),
            promptId: report.reportType,
            promptVersion: report.promptVersion,
            syncStatus: const Value('pending_push'),
            serverVersion: Value(existing?.serverVersion),
            lastSyncedAt: Value(existing?.lastSyncedAt),
            deletedAt: const Value(null),
            remoteSnapshotJson: const Value(null),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    return _toDomain(
      (await _row(bootstrap.activeUserId, reportId, reportVersion))!,
    );
  }

  @override
  Future<void> clear({
    required String reportId,
    required int reportVersion,
  }) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final existing = await _row(userId, reportId, reportVersion);
    if (existing == null || existing.deletedAt != null) return;
    if (existing.serverVersion == null) {
      await (database.delete(database.aiReportFeedback)..where(
            (row) => row.id.equals(existing.id) & row.userId.equals(userId),
          ))
          .go();
      return;
    }
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await (database.update(database.aiReportFeedback)..where(
          (row) => row.id.equals(existing.id) & row.userId.equals(userId),
        ))
        .write(
          db.AiReportFeedbackCompanion(
            syncStatus: const Value('pending_delete'),
            deletedAt: Value(now),
            updatedAt: Value(now),
            remoteSnapshotJson: const Value(null),
          ),
        );
  }

  @override
  Future<List<AiReportFeedback>> listPending() async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final rows =
        await (database.select(database.aiReportFeedback)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.syncStatus.isIn(const [
                      'local_only',
                      'pending_push',
                      'pending_delete',
                    ]),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<AiReportFeedback>> listAllForActiveAccount() async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final rows =
        await (database.select(database.aiReportFeedback)
              ..where((row) => row.userId.equals(userId))
              ..orderBy([
                (row) => OrderingTerm.asc(row.reportId),
                (row) => OrderingTerm.asc(row.reportVersion),
              ]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> applyRemote(AiReportFeedbackRemoteRecord remote) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final report = await _findOwnedReport(userId, remote.reportId);
    if (report == null ||
        !await _versionExists(remote.reportId, remote.reportVersion)) {
      return;
    }
    final existing = await _row(userId, remote.reportId, remote.reportVersion);
    if (existing == null) {
      await database
          .into(database.aiReportFeedback)
          .insert(
            db.AiReportFeedbackCompanion.insert(
              id: Value(remote.id),
              userId: userId,
              reportId: remote.reportId,
              reportVersion: remote.reportVersion,
              reportType: remote.reportType,
              helpfulness: remote.helpfulness.databaseValue,
              reasonCodesJson: Value(reasonCodec.encode(remote.reasons)),
              promptId: remote.promptId,
              promptVersion: remote.promptVersion,
              syncStatus: const Value('synced'),
              serverVersion: Value(remote.serverVersion),
              lastSyncedAt: Value(remote.updatedAt),
              deletedAt: Value(remote.deletedAt),
              remoteSnapshotJson: const Value(null),
              createdAt: Value(remote.createdAt),
              updatedAt: Value(remote.updatedAt),
            ),
          );
      return;
    }
    if (existing.syncStatus == 'conflict') return;
    if (existing.syncStatus == 'pending_push' ||
        existing.syncStatus == 'pending_delete' ||
        existing.syncStatus == 'local_only') {
      if (existing.serverVersion == remote.serverVersion) return;
      await markConflict(id: existing.id, remote: remote.snapshot);
      return;
    }
    if ((existing.serverVersion ?? 0) >= remote.serverVersion) return;
    await _writeRemote(existing.id, remote.snapshot);
  }

  @override
  Future<void> markSynced({
    required String id,
    required int serverVersion,
    required int serverUpdatedAt,
  }) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    await (database.update(
      database.aiReportFeedback,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      db.AiReportFeedbackCompanion(
        syncStatus: const Value('synced'),
        serverVersion: Value(serverVersion),
        lastSyncedAt: Value(serverUpdatedAt),
        remoteSnapshotJson: const Value(null),
      ),
    );
  }

  @override
  Future<void> markConflict({
    required String id,
    required AiReportFeedbackRemoteSnapshot remote,
  }) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    await (database.update(
      database.aiReportFeedback,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      db.AiReportFeedbackCompanion(
        syncStatus: const Value('conflict'),
        remoteSnapshotJson: Value(_encodeSnapshot(remote)),
      ),
    );
  }

  @override
  Future<void> adoptRemote(String id) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final row = await _rowById(userId, id);
    final remote = row == null ? null : _decodeSnapshot(row.remoteSnapshotJson);
    if (row == null || remote == null || row.syncStatus != 'conflict') {
      throw const AiReportFeedbackNotAllowedException();
    }
    await _writeRemote(id, remote);
  }

  @override
  Future<void> keepLocal(String id) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    final row = await _rowById(userId, id);
    final remote = row == null ? null : _decodeSnapshot(row.remoteSnapshotJson);
    if (row == null || remote == null || row.syncStatus != 'conflict') {
      throw const AiReportFeedbackNotAllowedException();
    }
    await (database.update(
      database.aiReportFeedback,
    )..where((item) => item.id.equals(id) & item.userId.equals(userId))).write(
      db.AiReportFeedbackCompanion(
        syncStatus: Value(
          row.deletedAt == null ? 'pending_push' : 'pending_delete',
        ),
        serverVersion: Value(remote.serverVersion),
        remoteSnapshotJson: const Value(null),
      ),
    );
  }

  Future<void> _writeRemote(
    String id,
    AiReportFeedbackRemoteSnapshot remote,
  ) async {
    final userId = (await database.bootstrapDao.bootstrap()).activeUserId;
    await (database.update(
      database.aiReportFeedback,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      db.AiReportFeedbackCompanion(
        helpfulness: Value(remote.helpfulness.databaseValue),
        reasonCodesJson: Value(reasonCodec.encode(remote.reasons)),
        syncStatus: const Value('synced'),
        serverVersion: Value(remote.serverVersion),
        lastSyncedAt: Value(remote.updatedAt),
        createdAt: Value(remote.createdAt),
        updatedAt: Value(remote.updatedAt),
        deletedAt: Value(remote.deletedAt),
        remoteSnapshotJson: const Value(null),
      ),
    );
  }

  Future<db.AiReport> _eligibleVersion(
    String userId,
    String reportId,
    int version,
  ) async {
    final report = await _findOwnedReport(userId, reportId);
    if (report == null ||
        report.deletedAt != null ||
        (report.reportStatus != 'completed' &&
            report.reportStatus != 'archived')) {
      throw const AiReportFeedbackNotAllowedException();
    }
    final versionRow =
        await (database.select(database.aiReportVersions)..where(
              (row) =>
                  row.reportId.equals(reportId) &
                  row.version.equals(version) &
                  row.status.equals('completed') &
                  row.content.isNotNull(),
            ))
            .getSingleOrNull();
    if (versionRow == null) throw const AiReportFeedbackNotAllowedException();
    return report;
  }

  Future<db.AiReport?> _findOwnedReport(String userId, String reportId) =>
      (database.select(database.aiReports)..where(
            (row) => row.id.equals(reportId) & row.userId.equals(userId),
          ))
          .getSingleOrNull();

  Future<bool> _versionExists(String reportId, int version) async =>
      await (database.select(database.aiReportVersions)..where(
            (row) =>
                row.reportId.equals(reportId) & row.version.equals(version),
          ))
          .getSingleOrNull() !=
      null;

  Future<db.AiReportFeedbackRow?> _row(
    String userId,
    String reportId,
    int version,
  ) =>
      (database.select(database.aiReportFeedback)..where(
            (row) =>
                row.userId.equals(userId) &
                row.reportId.equals(reportId) &
                row.reportVersion.equals(version),
          ))
          .getSingleOrNull();

  Future<db.AiReportFeedbackRow?> _rowById(String userId, String id) =>
      (database.select(database.aiReportFeedback)
            ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
          .getSingleOrNull();

  AiReportFeedback _toDomain(db.AiReportFeedbackRow row) => AiReportFeedback(
    id: row.id,
    userId: row.userId,
    reportId: row.reportId,
    reportVersion: row.reportVersion,
    reportType: row.reportType,
    helpfulness: AiReportHelpfulness.fromDatabaseValue(row.helpfulness),
    reasons: reasonCodec.decode(row.reasonCodesJson),
    promptId: row.promptId,
    promptVersion: row.promptVersion,
    syncStatus: AiReportFeedbackSyncStatus.fromDatabaseValue(row.syncStatus),
    serverVersion: row.serverVersion,
    lastSyncedAt: row.lastSyncedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    remoteSnapshot: _decodeSnapshot(row.remoteSnapshotJson),
  );

  String _encodeSnapshot(AiReportFeedbackRemoteSnapshot value) => jsonEncode({
    'deleted_at': value.deletedAt,
    'helpfulness': value.helpfulness.databaseValue,
    'id': value.id,
    'reason_codes': value.reasons.map((item) => item.code).toList(),
    'server_version': value.serverVersion,
    'created_at': value.createdAt,
    'updated_at': value.updatedAt,
  });

  AiReportFeedbackRemoteSnapshot? _decodeSnapshot(String? value) {
    if (value == null) return null;
    final json = jsonDecode(value);
    if (json is! Map) throw const FormatException('Invalid remote feedback.');
    final map = Map<String, Object?>.from(json);
    final reasons = map['reason_codes'];
    if (reasons is! List || reasons.any((item) => item is! String)) {
      throw const FormatException('Invalid remote feedback reasons.');
    }
    return AiReportFeedbackRemoteSnapshot(
      id: map['id'] as String,
      helpfulness: AiReportHelpfulness.fromDatabaseValue(
        map['helpfulness'] as String,
      ),
      reasons: reasons.cast<String>().map(AiReportFeedbackReason.fromCode),
      serverVersion: map['server_version'] as int,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
