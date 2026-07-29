import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_payload_codec.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class ProfileSyncPayloadCodec implements SyncConflictPayloadCodec {
  const ProfileSyncPayloadCodec();

  @override
  SyncEntityType get entityType => SyncEntityType.profile;

  @override
  Map<String, Object?> encode(SyncEntityPayload payload) {
    if (payload is! ProfileSyncPayload) {
      throw const SyncException('Profile 冲突 payload 类型无效。');
    }
    return {
      'display_name': payload.displayName,
      'growth_focus': payload.growthFocus,
      'timezone_id': payload.timezoneId,
      'updated_at': payload.updatedAt,
    };
  }

  @override
  ProfileSyncPayload decode({
    required String recordId,
    required Map<String, Object?> json,
  }) {
    final displayName = json['display_name'];
    final growthFocus = json['growth_focus'];
    final timezoneId = json['timezone_id'];
    final updatedAt = json['updated_at'];
    if ((displayName != null && displayName is! String) ||
        (growthFocus != null && growthFocus is! String) ||
        timezoneId is! String ||
        timezoneId.trim().isEmpty ||
        updatedAt is! int ||
        updatedAt < 0) {
      throw const SyncException('Profile 冲突 payload 内容无效。');
    }
    return ProfileSyncPayload(
      displayName: displayName as String?,
      growthFocus: growthFocus as String?,
      timezoneId: timezoneId,
      updatedAt: updatedAt,
    );
  }
}
