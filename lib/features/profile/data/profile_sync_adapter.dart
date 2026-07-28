import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_record_keys.dart';

import 'profile_local_data_source.dart';

final class ProfileSyncAdapter implements SyncEntityAdapter {
  ProfileSyncAdapter(db.AppDatabase database)
    : _database = database,
      _localDataSource = ProfileLocalDataSource(database);

  final db.AppDatabase _database;
  final ProfileLocalDataSource _localDataSource;

  @override
  SyncEntityType get entityType => SyncEntityType.profile;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final context = await _loadLocalContext();
    final profile = context.profile;
    if (profile.syncStatus == 'synced') return const [];

    return [
      SyncPushItem(
        entityType: entityType,
        operation: SyncOperation.upsert,
        recordId: SyncRecordKeys.profile,
        payload: ProfileSyncPayload(
          displayName: profile.displayName,
          growthFocus: profile.growthFocus,
          timezoneId: profile.timezoneId,
          updatedAt: profile.updatedAt,
        ),
        updatedAt: profile.updatedAt,
        deletedAt: null,
        originDeviceId: context.localInstallationId,
        clientVersion: profile.serverVersion ?? 0,
      ),
    ];
  }

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) {
    if (payload is! ProfileSyncPayload) {
      throw const SyncException('Profile 同步 payload 类型无效。');
    }
    return {
      'display_name': payload.displayName,
      'growth_focus': payload.growthFocus,
      'timezone_id': payload.timezoneId,
      'updated_at': payload.updatedAt,
    };
  }

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) {
    if (serverVersion < 0 || updatedAt < 0) {
      throw const SyncException('云端 Profile 版本或时间无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    final typedPayload = operation == SyncOperation.delete
        ? null
        : _decodePayload(payload, updatedAt);
    return SyncChange(
      entityType: entityType,
      operation: operation,
      recordId: recordId,
      payload: typedPayload,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      originDeviceId: originDeviceId,
      serverVersion: serverVersion,
    );
  }

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) {
    return _database.transaction(() async {
      if (submitted.length != 1 ||
          submitted.single.entityType != entityType ||
          submitted.single.recordId != SyncRecordKeys.profile) {
        throw const SyncException('Profile 上传上下文无效。');
      }
      final context = await _loadLocalContext();
      final conflict = conflicts
          .where(
            (item) =>
                item.tableName == entityType.wireName &&
                item.recordId == SyncRecordKeys.profile,
          )
          .firstOrNull;
      if (conflict != null) {
        await _localDataSource.markSyncConflict(
          context.profile.id,
          serverVersion: conflict.serverVersion,
        );
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: 'Profile 同步冲突，请先拉取或稍后处理',
          conflictCount: 1,
          serverVersion: conflict.serverVersion,
        );
      }

      final acknowledgement = accepted
          .where(
            (item) =>
                item.entityType == entityType &&
                item.recordId == SyncRecordKeys.profile,
          )
          .firstOrNull;
      if (acknowledgement == null) {
        throw const SyncException('后端未确认 Profile 上传结果。');
      }
      await _localDataSource.updateSyncMetadata(
        userId: context.profile.id,
        syncStatus: 'synced',
        serverVersion: acknowledgement.serverVersion,
        lastSyncedAt: syncedAt,
        originDeviceId: context.localInstallationId,
      );
      return SyncEntityResult(
        entityType: entityType,
        status: SyncEntityStatus.succeeded,
        message: 'Profile 已上传',
        pushedCount: 1,
        serverVersion: acknowledgement.serverVersion,
      );
    });
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) {
    return _database.transaction(() async {
      final context = await _loadLocalContext();
      var profile = context.profile;
      var applied = 0;
      var ignored = 0;
      var preparedLocalOverwrite = 0;
      final ordered = changes.toList(growable: false)
        ..sort(
          (left, right) => left.serverVersion.compareTo(right.serverVersion),
        );

      for (final change in ordered) {
        if (change.entityType != entityType) {
          throw SyncUnsupportedEntityException(change.entityType.wireName);
        }
        final localVersion = profile.serverVersion ?? 0;
        final isIncremental = pullMode == SyncPullMode.incremental;
        if ((isIncremental && change.serverVersion <= localVersion) ||
            (!isIncremental && change.serverVersion < localVersion)) {
          ignored += 1;
          continue;
        }

        if (pullMode == SyncPullMode.preserveLocalConflictResolution) {
          profile = await _localDataSource.markSyncConflict(
            profile.id,
            serverVersion: change.serverVersion,
          );
          preparedLocalOverwrite += 1;
          continue;
        }

        if (_hasUnsyncedLocalChanges(profile) &&
            pullMode != SyncPullMode.preferRemoteConflictResolution) {
          await _localDataSource.markSyncConflict(profile.id);
          return SyncEntityResult(
            entityType: entityType,
            status: SyncEntityStatus.conflict,
            message: '检测到本地与云端都有修改，暂未自动覆盖',
            ignoredCount: ignored,
            conflictCount: 1,
            serverVersion: change.serverVersion,
          );
        }
        if (change.operation == SyncOperation.delete) {
          await _localDataSource.markSyncConflict(profile.id);
          return SyncEntityResult(
            entityType: entityType,
            status: SyncEntityStatus.conflict,
            message: '云端 Profile 删除暂不支持自动应用',
            ignoredCount: ignored,
            conflictCount: 1,
            serverVersion: change.serverVersion,
          );
        }
        final payload = change.payload;
        if (payload is! ProfileSyncPayload) {
          throw const SyncException('云端 Profile payload 类型无效。');
        }
        final originDeviceId = change.originDeviceId.length == 36
            ? change.originDeviceId
            : context.localInstallationId;
        profile = await _localDataSource.applyRemoteProfile(
          userId: profile.id,
          displayName: payload.displayName,
          growthFocus: payload.growthFocus,
          timezoneId: payload.timezoneId,
          updatedAt: payload.updatedAt,
          serverVersion: change.serverVersion,
          lastSyncedAt: syncedAt,
          originDeviceId: originDeviceId,
        );
        applied += 1;
      }

      if (pullMode == SyncPullMode.preserveLocalConflictResolution) {
        return SyncEntityResult(
          entityType: entityType,
          status: preparedLocalOverwrite == 0
              ? SyncEntityStatus.conflict
              : SyncEntityStatus.succeeded,
          message: preparedLocalOverwrite == 0
              ? '未找到可确认的云端 Profile，冲突保持不变'
              : '已获取云端版本，等待保留本地 Profile',
          ignoredCount: ignored,
          conflictCount: preparedLocalOverwrite == 0 ? 1 : 0,
          serverVersion: profile.serverVersion,
        );
      }
      if (pullMode == SyncPullMode.preferRemoteConflictResolution &&
          applied == 0) {
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: '未找到可采用的云端 Profile，冲突保持不变',
          ignoredCount: ignored,
          conflictCount: 1,
          serverVersion: profile.serverVersion,
        );
      }

      return SyncEntityResult(
        entityType: entityType,
        status: applied == 0
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: applied == 0 ? '没有新的 Profile 更新' : 'Profile 已更新',
        pulledCount: applied,
        ignoredCount: ignored,
        serverVersion: profile.serverVersion,
      );
    });
  }

  Future<UserProfile> currentProfile() async {
    final profile = (await _loadLocalContext()).profile;
    return UserProfile(
      id: profile.id,
      displayName: profile.displayName,
      growthFocus: profile.growthFocus,
      timezoneId: profile.timezoneId,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }

  Future<bool> hasConflict() async {
    final profile = (await _loadLocalContext()).profile;
    return profile.syncStatus == 'conflict';
  }

  Future<_ProfileLocalContext> _loadLocalContext() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final profile = await _localDataSource.selectActiveById(
      bootstrap.activeUserId,
    );
    if (profile == null) {
      throw const SyncException('本地 Profile 不可用。');
    }
    return _ProfileLocalContext(
      profile: profile,
      localInstallationId: bootstrap.localInstallationId,
    );
  }

  ProfileSyncPayload _decodePayload(
    Map<String, Object?> payload,
    int fallbackUpdatedAt,
  ) {
    for (final key in const ['display_name', 'growth_focus']) {
      if (!payload.containsKey(key)) {
        throw SyncException('云端 Profile 缺少字段 $key。');
      }
    }
    final displayName = _nullableString(payload, 'display_name');
    final growthFocus = _nullableString(payload, 'growth_focus');
    final timezoneId = payload['timezone_id'];
    final updatedAt = payload['updated_at'] ?? fallbackUpdatedAt;
    if (timezoneId is! String || timezoneId.trim().isEmpty) {
      throw const SyncException('云端 Profile 时区数据无效。');
    }
    if (updatedAt is! int || updatedAt < 0) {
      throw const SyncException('云端 Profile 更新时间无效。');
    }
    return ProfileSyncPayload(
      displayName: displayName,
      growthFocus: growthFocus,
      timezoneId: timezoneId,
      updatedAt: updatedAt,
    );
  }

  bool _hasUnsyncedLocalChanges(db.UserProfile profile) {
    if (profile.syncStatus == 'pending' || profile.syncStatus == 'conflict') {
      return true;
    }
    return profile.syncStatus == 'local_only' &&
        (profile.displayName != null || profile.growthFocus != null);
  }

  String? _nullableString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Profile 字段 $key 无效。');
    }
    return value as String?;
  }
}

final class _ProfileLocalContext {
  const _ProfileLocalContext({
    required this.profile,
    required this.localInstallationId,
  });

  final db.UserProfile profile;
  final String localInstallationId;
}
