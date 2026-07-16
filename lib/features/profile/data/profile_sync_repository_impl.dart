import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/profile_sync_direction.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_item.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';
import 'package:rebirth/features/sync/domain/sync_record_keys.dart';

import 'profile_local_data_source.dart';

final class ProfileSyncRepositoryImpl implements ProfileSyncRepository {
  ProfileSyncRepositoryImpl({
    required db.AppDatabase database,
    required this.sessionStore,
    required this.remoteDataSource,
    required this.dateTimeService,
    required this.cursorStore,
    required this.endpoint,
  }) : _database = database,
       _localDataSource = ProfileLocalDataSource(database);

  static const _tableName = 'user_profiles';

  final db.AppDatabase _database;
  final ProfileLocalDataSource _localDataSource;
  final AuthSessionStore sessionStore;
  final SyncRemoteDataSource remoteDataSource;
  final DateTimeService dateTimeService;
  final SyncCursorStore cursorStore;
  final String endpoint;

  @override
  Future<ProfileSyncResult> pushProfile() async {
    final context = await _loadContext();
    final local = context.profile;
    final response = await remoteDataSource.push(
      SyncPushRequestDto(
        deviceId: context.deviceId,
        items: [
          SyncItem(
            tableName: _tableName,
            recordId: SyncRecordKeys.profile,
            payload: {
              'display_name': local.displayName,
              'growth_focus': local.growthFocus,
              'timezone_id': local.timezoneId,
              'updated_at': local.updatedAt,
            },
            updatedAt: local.updatedAt,
            deletedAt: null,
            originDeviceId: context.localInstallationId,
            clientVersion: local.serverVersion ?? 0,
          ),
        ],
      ),
      accessToken: context.session.accessToken,
    );

    final conflict = response.conflicts
        .where(
          (item) =>
              item.tableName == _tableName &&
              item.recordId == SyncRecordKeys.profile,
        )
        .firstOrNull;
    if (conflict != null) {
      await _localDataSource.markSyncConflict(local.id);
      return ProfileSyncResult(
        success: false,
        direction: ProfileSyncDirection.push,
        message: 'Profile 同步冲突，请先拉取或稍后处理',
        pushed: false,
        pulled: false,
        conflict: true,
        serverVersion: conflict.serverVersion,
      );
    }

    final accepted = response.accepted
        .where(
          (item) =>
              item.tableName == _tableName &&
              item.recordId == SyncRecordKeys.profile,
        )
        .firstOrNull;
    if (accepted == null) {
      throw const SyncException('后端未确认 Profile 上传结果。');
    }
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final updated = await _localDataSource.updateSyncMetadata(
      userId: local.id,
      syncStatus: 'synced',
      serverVersion: accepted.serverVersion,
      lastSyncedAt: now,
      originDeviceId: context.localInstallationId,
    );
    return ProfileSyncResult(
      success: true,
      direction: ProfileSyncDirection.push,
      message: 'Profile 已上传',
      pushed: true,
      pulled: false,
      conflict: false,
      serverVersion: accepted.serverVersion,
      updatedProfile: _toDomain(updated),
    );
  }

  @override
  Future<ProfileSyncResult> pullProfile() async {
    final context = await _loadContext();
    final local = context.profile;
    final cursor = await cursorStore.read(
      endpoint: endpoint,
      cloudUserId: context.session.user.id,
      scope: _tableName,
    );
    final response = await remoteDataSource.pull(
      SyncPullRequestDto(
        deviceId: context.deviceId,
        sinceServerVersion: cursor,
        tables: const [_tableName],
      ),
      accessToken: context.session.accessToken,
    );
    final candidates = response.items
        .where(
          (item) =>
              item.tableName == _tableName &&
              item.recordId == SyncRecordKeys.profile,
        )
        .toList(growable: false)
      ..sort((left, right) => right.serverVersion.compareTo(left.serverVersion));
    if (candidates.isEmpty) {
      await _writeCursor(context, response.serverVersion);
      return ProfileSyncResult(
        success: true,
        direction: ProfileSyncDirection.pull,
        message: '没有新的 Profile 更新',
        pushed: false,
        pulled: false,
        conflict: false,
        serverVersion: local.serverVersion,
        updatedProfile: _toDomain(local),
      );
    }

    final latest = candidates.first;
    final localVersion = local.serverVersion ?? 0;
    if (_hasUnsyncedLocalChanges(local) &&
        latest.serverVersion > localVersion) {
      await _localDataSource.markSyncConflict(local.id);
      return ProfileSyncResult(
        success: false,
        direction: ProfileSyncDirection.pull,
        message: '检测到本地与云端都有修改，暂未自动覆盖',
        pushed: false,
        pulled: false,
        conflict: true,
        serverVersion: latest.serverVersion,
        updatedProfile: _toDomain(local),
      );
    }
    if (latest.deletedAt != null) {
      await _localDataSource.markSyncConflict(local.id);
      return ProfileSyncResult(
        success: false,
        direction: ProfileSyncDirection.pull,
        message: '云端 Profile 删除暂不支持自动应用',
        pushed: false,
        pulled: false,
        conflict: true,
        serverVersion: latest.serverVersion,
        updatedProfile: _toDomain(local),
      );
    }

    final payload = _ProfilePayload.fromSyncItem(latest);
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final originDeviceId = latest.originDeviceId.length == 36
        ? latest.originDeviceId
        : context.localInstallationId;
    final updated = await _localDataSource.applyRemoteProfile(
      userId: local.id,
      displayName: payload.displayName,
      growthFocus: payload.growthFocus,
      timezoneId: payload.timezoneId,
      updatedAt: payload.updatedAt,
      serverVersion: latest.serverVersion,
      lastSyncedAt: now,
      originDeviceId: originDeviceId,
    );
    await _writeCursor(context, response.serverVersion);
    return ProfileSyncResult(
      success: true,
      direction: ProfileSyncDirection.pull,
      message: 'Profile 已更新',
      pushed: false,
      pulled: true,
      conflict: false,
      serverVersion: latest.serverVersion,
      updatedProfile: _toDomain(updated),
    );
  }

  Future<void> _writeCursor(
    _ProfileSyncContext context,
    int serverVersion,
  ) {
    return cursorStore.write(
      endpoint: endpoint,
      cloudUserId: context.session.user.id,
      scope: _tableName,
      serverVersion: serverVersion,
    );
  }

  Future<_ProfileSyncContext> _loadContext() async {
    final session = await sessionStore.read();
    if (session == null || session.accessToken.trim().isEmpty) {
      throw const SyncAuthenticationRequiredException();
    }
    final registration = session.deviceRegistration;
    if (registration == null || !registration.isRegistered) {
      throw const SyncDeviceRegistrationRequiredException();
    }
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final profile = await _localDataSource.selectActiveById(
      bootstrap.activeUserId,
    );
    if (profile == null) {
      throw const SyncException('本地 Profile 不可用。');
    }
    return _ProfileSyncContext(
      session: session,
      deviceId: registration.deviceId,
      localInstallationId: bootstrap.localInstallationId,
      profile: profile,
    );
  }

  bool _hasUnsyncedLocalChanges(db.UserProfile profile) {
    final metadataMarksLocalChange =
        profile.syncStatus == 'pending' || profile.syncStatus == 'conflict';
    final legacyLocalContent =
        profile.syncStatus == 'local_only' &&
        (profile.displayName != null || profile.growthFocus != null);
    final changedAfterSync =
        profile.updatedAt > (profile.lastSyncedAt ?? 0);
    return changedAfterSync &&
        (metadataMarksLocalChange || legacyLocalContent);
  }

  UserProfile _toDomain(db.UserProfile profile) {
    return UserProfile(
      id: profile.id,
      displayName: profile.displayName,
      growthFocus: profile.growthFocus,
      timezoneId: profile.timezoneId,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }
}

final class _ProfileSyncContext {
  const _ProfileSyncContext({
    required this.session,
    required this.deviceId,
    required this.localInstallationId,
    required this.profile,
  });

  final AuthSession session;
  final String deviceId;
  final String localInstallationId;
  final db.UserProfile profile;
}

final class _ProfilePayload {
  const _ProfilePayload({
    required this.displayName,
    required this.growthFocus,
    required this.timezoneId,
    required this.updatedAt,
  });

  factory _ProfilePayload.fromSyncItem(PulledSyncItemDto item) {
    final displayName = _nullableString(item.payload, 'display_name');
    final growthFocus = _nullableString(item.payload, 'growth_focus');
    final timezoneId = item.payload['timezone_id'];
    final updatedAt = item.payload['updated_at'] ?? item.updatedAt;
    if (timezoneId is! String || timezoneId.trim().isEmpty) {
      throw const SyncException('云端 Profile 时区数据无效。');
    }
    if (updatedAt is! int || updatedAt < 0) {
      throw const SyncException('云端 Profile 更新时间无效。');
    }
    return _ProfilePayload(
      displayName: displayName,
      growthFocus: growthFocus,
      timezoneId: timezoneId,
      updatedAt: updatedAt,
    );
  }

  final String? displayName;
  final String? growthFocus;
  final String timezoneId;
  final int updatedAt;

  static String? _nullableString(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = payload[key];
    if (value != null && value is! String) {
      throw SyncException('云端 Profile 字段 $key 无效。');
    }
    return value as String?;
  }
}
