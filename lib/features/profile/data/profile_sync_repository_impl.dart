import 'package:rebirth/features/sync/application/sync_coordinator.dart';
import 'package:rebirth/features/sync/domain/profile_sync_direction.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'profile_sync_adapter.dart';

final class ProfileSyncRepositoryImpl implements ProfileSyncRepository {
  const ProfileSyncRepositoryImpl({
    required this.coordinator,
    required this.adapter,
  });

  final SyncCoordinator coordinator;
  final ProfileSyncAdapter adapter;

  @override
  Future<ProfileSyncResult> pushProfile() {
    return _run(
      direction: SyncRunDirection.push,
      profileDirection: ProfileSyncDirection.push,
    );
  }

  @override
  Future<ProfileSyncResult> pullProfile() {
    return _run(
      direction: SyncRunDirection.pull,
      profileDirection: ProfileSyncDirection.pull,
    );
  }

  Future<ProfileSyncResult> _run({
    required SyncRunDirection direction,
    required ProfileSyncDirection profileDirection,
  }) async {
    final run = await coordinator.run(
      direction: direction,
      entityTypes: const [SyncEntityType.profile],
    );
    final entity = run.resultFor(SyncEntityType.profile);
    final failure = run.failure;
    if (failure != null && failure.reason != SyncFailureReason.conflict) {
      switch (failure.reason) {
        case SyncFailureReason.authenticationRequired:
        case SyncFailureReason.cloudUserUnavailable:
          throw const SyncAuthenticationRequiredException();
        case SyncFailureReason.accountScopeMismatch:
        case SyncFailureReason.accountSyncReviewRequired:
          throw SyncException(failure.message);
        case SyncFailureReason.deviceRegistrationRequired:
          throw const SyncDeviceRegistrationRequiredException();
        case SyncFailureReason.endpointUnavailable:
          throw SyncException('${failure.message} 本地资料未受影响。');
        case SyncFailureReason.syncInProgress:
          throw SyncException(failure.message);
        case SyncFailureReason.unsupportedEntity:
          throw SyncException(failure.message);
        case SyncFailureReason.pushFailed:
        case SyncFailureReason.pullFailed:
        case SyncFailureReason.payloadInvalid:
        case SyncFailureReason.applyFailed:
        case SyncFailureReason.cursorFailed:
        case SyncFailureReason.unexpected:
          throw SyncException(failure.message);
        case SyncFailureReason.conflict:
          break;
      }
    }
    if (entity == null) {
      throw const SyncException('Profile 同步未返回实体结果。');
    }

    final profile = await adapter.currentProfile();
    final isConflict = entity.status == SyncEntityStatus.conflict;
    final pushed = entity.pushedCount > 0;
    final pulled = entity.pulledCount > 0;
    final message = switch ((profileDirection, pushed, pulled, isConflict)) {
      (_, _, _, true) => entity.message,
      (ProfileSyncDirection.push, false, _, false) => '没有待上传的 Profile 更新',
      (ProfileSyncDirection.pull, _, false, false) => '没有新的 Profile 更新',
      _ => entity.message,
    };
    return ProfileSyncResult(
      success: !isConflict,
      direction: profileDirection,
      message: message,
      pushed: pushed,
      pulled: pulled,
      conflict: isConflict,
      serverVersion: entity.serverVersion,
      updatedProfile: profile,
    );
  }
}
