import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/profile/data/profile_sync_repository_provider.dart';
import 'package:rebirth/features/sync/domain/profile_sync_direction.dart';
import 'package:rebirth/features/sync/domain/profile_sync_repository.dart';
import 'package:rebirth/features/sync/domain/profile_sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/profile_sync_controller.dart';
import 'package:rebirth/shared/state/profile_revision_provider.dart';

void main() {
  test(
    'successful pull bumps Profile revision for Settings and Profile',
    () async {
      final repository = _FakeProfileSyncRepository(
        pullResult: const ProfileSyncResult(
          success: true,
          direction: ProfileSyncDirection.pull,
          message: 'Profile 已更新',
          pushed: false,
          pulled: true,
          conflict: false,
          serverVersion: 2,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          profileSyncRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(profileRevisionProvider), 0);

      final result = await container
          .read(profileSyncControllerProvider.notifier)
          .pullProfile();

      expect(result.pulled, isTrue);
      expect(container.read(profileRevisionProvider), 1);
      expect(container.read(profileSyncControllerProvider).isBusy, isFalse);
    },
  );

  test('failed operation returns to idle and does not bump revision', () async {
    final repository = _FakeProfileSyncRepository(error: StateError('failed'));
    final container = ProviderContainer(
      overrides: [profileSyncRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(profileSyncControllerProvider.notifier).pushProfile(),
      throwsStateError,
    );

    expect(container.read(profileSyncControllerProvider).isBusy, isFalse);
    expect(container.read(profileRevisionProvider), 0);
  });

  test('cloud conflict resolution bumps Profile revision', () async {
    final repository = _FakeProfileSyncRepository(
      pullResult: const ProfileSyncResult(
        success: true,
        direction: ProfileSyncDirection.pull,
        message: '已采用云端 Profile',
        pushed: false,
        pulled: true,
        conflict: false,
        serverVersion: 3,
      ),
    );
    final container = ProviderContainer(
      overrides: [profileSyncRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(profileSyncControllerProvider.notifier)
        .resolveConflictUsingCloud();

    expect(repository.resolveUsingCloudCalls, 1);
    expect(container.read(profileRevisionProvider), 1);
    expect(container.read(profileSyncControllerProvider).isBusy, isFalse);
  });
}

final class _FakeProfileSyncRepository implements ProfileSyncRepository {
  _FakeProfileSyncRepository({this.pullResult, this.error});

  final ProfileSyncResult? pullResult;
  final Object? error;
  int resolveUsingCloudCalls = 0;

  @override
  Future<SyncRunResult> syncProfile() async {
    return SyncRunResult(
      direction: SyncRunDirection.twoWay,
      phases: const [],
      entityResults: const [],
      startedAt: 1,
      completedAt: 2,
    );
  }

  @override
  Future<bool> hasConflict() async => false;

  @override
  Future<ProfileSyncResult> pullProfile() async {
    if (error case final value?) throw value;
    return pullResult!;
  }

  @override
  Future<ProfileSyncResult> pushProfile() async {
    if (error case final value?) throw value;
    return const ProfileSyncResult(
      success: true,
      direction: ProfileSyncDirection.push,
      message: 'Profile 已上传',
      pushed: true,
      pulled: false,
      conflict: false,
      serverVersion: 1,
    );
  }

  @override
  Future<ProfileSyncResult> resolveConflictKeepingLocal() => pushProfile();

  @override
  Future<ProfileSyncResult> resolveConflictUsingCloud() {
    resolveUsingCloudCalls += 1;
    return pullProfile();
  }
}
