import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:uuid/uuid.dart';

final class SyncConflictRepositoryImpl implements SyncConflictRepository {
  SyncConflictRepositoryImpl(
    this._database, {
    required Iterable<SyncConflictPayloadCodec> payloadCodecs,
    this._uuid = const Uuid(),
  }) : _payloadCodecs = {
         for (final codec in payloadCodecs) codec.entityType: codec,
       };

  final db.AppDatabase _database;
  final Map<SyncEntityType, SyncConflictPayloadCodec> _payloadCodecs;
  final Uuid _uuid;

  @override
  Future<List<SyncConflictRecord>> listActiveConflicts(
    SyncConflictScope scope,
  ) async {
    final rows =
        await (_database.select(_database.syncConflicts)
              ..where(
                (row) => _scopePredicate(row, scope) & row.resolvedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.detectedAt)]))
            .get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Stream<int> watchActiveConflictCount(SyncConflictScope scope) {
    final count = _database.syncConflicts.id.count();
    final query = _database.selectOnly(_database.syncConflicts)
      ..addColumns([count])
      ..where(
        _scopePredicate(_database.syncConflicts, scope) &
            _database.syncConflicts.resolvedAt.isNull(),
      );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Future<SyncConflictRecord> getConflict(
    SyncConflictScope scope,
    String id,
  ) async {
    final row =
        await (_database.select(_database.syncConflicts)
              ..where((row) => _scopePredicate(row, scope) & row.id.equals(id)))
            .getSingleOrNull();
    if (row == null) throw const SyncConflictNotFoundException();
    return _toDomain(row);
  }

  @override
  Future<SyncConflictRecord?> findActiveConflict({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
  }) async {
    final rows =
        await (_database.select(_database.syncConflicts)..where(
              (row) =>
                  _scopePredicate(row, scope) &
                  row.entityType.equals(entityType.wireName) &
                  row.recordId.equals(recordId) &
                  row.resolvedAt.isNull(),
            ))
            .get();
    return _selectPreferred(rows);
  }

  @override
  Future<SyncConflictRecord?> findActiveConflictByRemoteRecordId({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String remoteRecordId,
  }) async {
    final rows =
        await (_database.select(_database.syncConflicts)..where(
              (row) =>
                  _scopePredicate(row, scope) &
                  row.entityType.equals(entityType.wireName) &
                  row.remoteRecordId.equals(remoteRecordId) &
                  row.resolvedAt.isNull(),
            ))
            .get();
    return _selectPreferred(rows);
  }

  SyncConflictRecord? _selectPreferred(List<db.SyncConflictRow> rows) {
    if (rows.isEmpty) return null;
    final conflicts = rows.map(_toDomain).toList(growable: false)
      ..sort((left, right) {
        final priority = _remoteMatchPriority(
          left.resolutionStatus,
        ).compareTo(_remoteMatchPriority(right.resolutionStatus));
        if (priority != 0) return priority;
        final detected = right.detectedAt.compareTo(left.detectedAt);
        return detected != 0 ? detected : left.id.compareTo(right.id);
      });
    return conflicts.first;
  }

  int _remoteMatchPriority(SyncConflictResolutionStatus status) {
    return switch (status) {
      SyncConflictResolutionStatus.adoptRemoteRequested => 0,
      SyncConflictResolutionStatus.awaitingRemoteSnapshot => 1,
      SyncConflictResolutionStatus.unresolved => 2,
      SyncConflictResolutionStatus.keepLocalRequested => 3,
      _ => 4,
    };
  }

  @override
  Future<SyncConflictRecord> upsertDetectedConflict(
    SyncConflictDetection detection,
  ) async {
    _validateDetection(detection);
    final existing = await findActiveConflict(
      scope: detection.scope,
      entityType: detection.entityType,
      recordId: detection.recordId,
    );
    if (existing == null) {
      final id = _uuid.v4();
      await _database
          .into(_database.syncConflicts)
          .insert(
            db.SyncConflictsCompanion.insert(
              id: Value(id),
              localUserId: detection.scope.localUserId,
              endpointKey: detection.scope.endpointKey,
              cloudUserId: detection.scope.cloudUserId,
              entityType: detection.entityType.wireName,
              recordId: detection.recordId,
              remoteRecordId: Value(detection.remoteRecordId),
              localPayloadJson: Value(
                _encodePayload(
                  detection.entityType,
                  detection.localSnapshot.payload,
                ),
              ),
              localUpdatedAt: detection.localSnapshot.updatedAt!,
              localDeletedAt: Value(detection.localSnapshot.deletedAt),
              localServerVersion: Value(detection.localSnapshot.serverVersion),
              localOriginDeviceId: Value(
                detection.localSnapshot.originDeviceId,
              ),
              remotePayloadJson: Value(
                _encodePayload(
                  detection.entityType,
                  detection.remoteSnapshot.payload,
                ),
              ),
              remoteOperation: detection.remoteOperation.wireValue,
              remoteUpdatedAt: Value(detection.remoteSnapshot.updatedAt),
              remoteDeletedAt: Value(detection.remoteSnapshot.deletedAt),
              remoteServerVersion: detection.remoteSnapshot.serverVersion!,
              remoteOriginDeviceId: Value(
                detection.remoteSnapshot.originDeviceId,
              ),
              detectedAt: detection.detectedAt,
              lastSeenAt: detection.detectedAt,
              resolutionStatus: detection.resolutionStatus.wireValue,
              resolvedAt: const Value(null),
            ),
          );
      return getConflict(detection.scope, id);
    }

    final incomingVersion = detection.remoteSnapshot.serverVersion!;
    final existingVersion = existing.remoteSnapshot.serverVersion ?? 0;
    final shouldReplaceRemote = incomingVersion >= existingVersion;
    final companion = db.SyncConflictsCompanion(
      lastSeenAt: Value(detection.detectedAt),
      remotePayloadJson: shouldReplaceRemote
          ? Value(
              _encodePayload(
                detection.entityType,
                detection.remoteSnapshot.payload,
              ),
            )
          : const Value.absent(),
      remoteRecordId: shouldReplaceRemote
          ? Value(detection.remoteRecordId)
          : const Value.absent(),
      remoteOperation: shouldReplaceRemote
          ? Value(detection.remoteOperation.wireValue)
          : const Value.absent(),
      remoteUpdatedAt: shouldReplaceRemote
          ? Value(detection.remoteSnapshot.updatedAt)
          : const Value.absent(),
      remoteDeletedAt: shouldReplaceRemote
          ? Value(detection.remoteSnapshot.deletedAt)
          : const Value.absent(),
      remoteServerVersion: shouldReplaceRemote
          ? Value(incomingVersion)
          : const Value.absent(),
      remoteOriginDeviceId: shouldReplaceRemote
          ? Value(detection.remoteSnapshot.originDeviceId)
          : const Value.absent(),
      resolutionStatus:
          shouldReplaceRemote &&
              (incomingVersion > existingVersion ||
                  existing.resolutionStatus ==
                      SyncConflictResolutionStatus.awaitingRemoteSnapshot)
          ? Value(detection.resolutionStatus.wireValue)
          : const Value.absent(),
    );
    await (_database.update(
      _database.syncConflicts,
    )..where((row) => row.id.equals(existing.id))).write(companion);
    return getConflict(detection.scope, existing.id);
  }

  @override
  Future<SyncConflictRecord> hydrateRemoteSnapshot({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
    String? remoteRecordId,
    required SyncConflictOperation operation,
    required SyncConflictSnapshot remoteSnapshot,
    required int seenAt,
  }) async {
    final existing = await findActiveConflict(
      scope: scope,
      entityType: entityType,
      recordId: recordId,
    );
    if (existing == null) throw const SyncConflictNotFoundException();
    final incomingVersion = remoteSnapshot.serverVersion;
    if (incomingVersion == null || incomingVersion < 0) {
      throw const SyncConflictChangedException();
    }
    final currentVersion = existing.remoteSnapshot.serverVersion ?? 0;
    if (incomingVersion < currentVersion) return existing;
    if (operation == SyncConflictOperation.upsert &&
        remoteSnapshot.payload == null) {
      throw const SyncConflictNotReadyException();
    }
    await (_database.update(
      _database.syncConflicts,
    )..where((row) => row.id.equals(existing.id))).write(
      db.SyncConflictsCompanion(
        remoteRecordId: Value(remoteRecordId),
        remotePayloadJson: Value(
          _encodePayload(entityType, remoteSnapshot.payload),
        ),
        remoteOperation: Value(operation.wireValue),
        remoteUpdatedAt: Value(remoteSnapshot.updatedAt),
        remoteDeletedAt: Value(remoteSnapshot.deletedAt),
        remoteServerVersion: Value(incomingVersion),
        remoteOriginDeviceId: Value(remoteSnapshot.originDeviceId),
        lastSeenAt: Value(seenAt),
        resolutionStatus: Value(
          existing.resolutionStatus ==
                  SyncConflictResolutionStatus.awaitingRemoteSnapshot
              ? SyncConflictResolutionStatus.unresolved.wireValue
              : existing.resolutionStatus.wireValue,
        ),
      ),
    );
    return getConflict(scope, existing.id);
  }

  @override
  Future<void> markAdoptRemoteRequested(
    SyncConflictScope scope,
    String id,
  ) async {
    final conflict = await getConflict(scope, id);
    if (!conflict.isActive) throw const SyncConflictNotFoundException();
    if (!conflict.remoteSnapshotReady) {
      throw const SyncConflictNotReadyException();
    }
    await _setStatus(
      conflict.id,
      SyncConflictResolutionStatus.adoptRemoteRequested,
    );
  }

  @override
  Future<void> markKeepLocalRequested(
    SyncConflictScope scope,
    String id,
  ) async {
    final conflict = await getConflict(scope, id);
    if (!conflict.isActive || conflict.remoteSnapshot.serverVersion == null) {
      throw const SyncConflictNotReadyException();
    }
    await _setStatus(
      conflict.id,
      SyncConflictResolutionStatus.keepLocalRequested,
    );
  }

  @override
  Future<void> markResolvedAdoptRemote(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) {
    return _markResolved(
      scope,
      id,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
      resolvedAt,
    );
  }

  @override
  Future<void> markResolvedKeepLocal(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) {
    return _markResolved(
      scope,
      id,
      SyncConflictResolutionStatus.resolvedKeepLocal,
      resolvedAt,
    );
  }

  @override
  Future<void> markSuperseded(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) {
    return _markResolved(
      scope,
      id,
      SyncConflictResolutionStatus.superseded,
      resolvedAt,
    );
  }

  Future<void> _markResolved(
    SyncConflictScope scope,
    String id,
    SyncConflictResolutionStatus status,
    int resolvedAt,
  ) async {
    final conflict = await getConflict(scope, id);
    if (conflict.resolvedAt != null) return;
    if (resolvedAt < conflict.detectedAt) {
      throw const SyncConflictResolutionException('冲突解决时间无效。');
    }
    final affected =
        await (_database.update(
          _database.syncConflicts,
        )..where((row) => row.id.equals(id) & row.resolvedAt.isNull())).write(
          db.SyncConflictsCompanion(
            resolutionStatus: Value(status.wireValue),
            resolvedAt: Value(resolvedAt),
            lastSeenAt: Value(resolvedAt),
          ),
        );
    if (affected != 1) throw const SyncConflictChangedException();
  }

  Future<void> _setStatus(
    String id,
    SyncConflictResolutionStatus status,
  ) async {
    final affected =
        await (_database.update(
          _database.syncConflicts,
        )..where((row) => row.id.equals(id) & row.resolvedAt.isNull())).write(
          db.SyncConflictsCompanion(resolutionStatus: Value(status.wireValue)),
        );
    if (affected != 1) throw const SyncConflictChangedException();
  }

  Expression<bool> _scopePredicate(
    db.$SyncConflictsTable row,
    SyncConflictScope scope,
  ) {
    return row.localUserId.equals(scope.localUserId) &
        row.endpointKey.equals(scope.endpointKey) &
        row.cloudUserId.equals(scope.cloudUserId);
  }

  void _validateDetection(SyncConflictDetection detection) {
    final localUpdatedAt = detection.localSnapshot.updatedAt;
    final remoteVersion = detection.remoteSnapshot.serverVersion;
    if (localUpdatedAt == null ||
        localUpdatedAt < 0 ||
        remoteVersion == null ||
        remoteVersion < 0 ||
        detection.detectedAt < 0) {
      throw const SyncException('同步冲突快照字段无效。');
    }
    if (detection.remoteOperation == SyncConflictOperation.upsert &&
        detection.remoteSnapshot.payload == null) {
      throw const SyncException('云端 upsert 冲突缺少 payload。');
    }
    if (detection.remoteOperation == SyncConflictOperation.delete &&
        detection.remoteSnapshot.deletedAt == null) {
      throw const SyncException('云端 delete 冲突缺少 deletedAt。');
    }
  }

  String? _encodePayload(
    SyncEntityType entityType,
    SyncEntityPayload? payload,
  ) {
    if (payload == null) return null;
    final codec = _payloadCodecs[entityType];
    if (codec == null) {
      throw SyncException('未注册 ${entityType.wireName} 冲突 payload codec。');
    }
    return jsonEncode(codec.encode(payload));
  }

  SyncConflictRecord _toDomain(db.SyncConflictRow row) {
    final entityType = SyncEntityType.parse(row.entityType);
    return SyncConflictRecord(
      id: row.id,
      scope: SyncConflictScope(
        localUserId: row.localUserId,
        endpointKey: row.endpointKey,
        cloudUserId: row.cloudUserId,
      ),
      entityType: entityType,
      recordId: row.recordId,
      remoteRecordId: row.remoteRecordId,
      localSnapshot: SyncConflictSnapshot(
        payload: _decodePayload(entityType, row.recordId, row.localPayloadJson),
        updatedAt: row.localUpdatedAt,
        deletedAt: row.localDeletedAt,
        serverVersion: row.localServerVersion,
        originDeviceId: row.localOriginDeviceId,
      ),
      remoteSnapshot: SyncConflictSnapshot(
        payload: _decodePayload(
          entityType,
          row.remoteRecordId ?? row.recordId,
          row.remotePayloadJson,
        ),
        updatedAt: row.remoteUpdatedAt,
        deletedAt: row.remoteDeletedAt,
        serverVersion: row.remoteServerVersion,
        originDeviceId: row.remoteOriginDeviceId,
      ),
      remoteOperation: SyncConflictOperation.parse(row.remoteOperation),
      detectedAt: row.detectedAt,
      lastSeenAt: row.lastSeenAt,
      resolutionStatus: SyncConflictResolutionStatus.parse(
        row.resolutionStatus,
      ),
      resolvedAt: row.resolvedAt,
    );
  }

  SyncEntityPayload? _decodePayload(
    SyncEntityType entityType,
    String recordId,
    String? encoded,
  ) {
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const SyncException('本地冲突 payload JSON 无效。');
    }
    final codec = _payloadCodecs[entityType];
    if (codec == null) {
      throw SyncException('未注册 ${entityType.wireName} 冲突 payload codec。');
    }
    return codec.decode(
      recordId: recordId,
      json: Map<String, Object?>.from(decoded),
    );
  }
}
