import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification_repository.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/account/presentation/legacy_ownership_verification_controller.dart';

void main() {
  test(
    'verified result refreshes auth state after provider invalidation',
    () async {
      final repository = _FakeRepository(_verified);
      final container = ProviderContainer(
        overrides: [
          legacyOwnershipVerificationRepositoryProvider.overrideWithValue(
            repository,
          ),
          appAuthControllerProvider.overrideWith(_FakeAppAuthController.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appAuthControllerProvider.future);
      await container.read(
        legacyOwnershipVerificationControllerProvider.future,
      );

      final result = await container
          .read(legacyOwnershipVerificationControllerProvider.notifier)
          .verify();

      expect(result.isVerified, isTrue);
      expect(repository.calls, 1);
      expect(
        container.read(appAuthControllerProvider).value?.verificationStatus,
        AccountOwnershipVerificationStatus.verified,
      );
      expect(
        container.read(legacyOwnershipVerificationControllerProvider).value,
        _verified,
      );
    },
  );

  test('failure is exposed and a later retry succeeds', () async {
    final repository = _FakeRepository(_verified, error: StateError('offline'));
    final container = ProviderContainer(
      overrides: [
        legacyOwnershipVerificationRepositoryProvider.overrideWithValue(
          repository,
        ),
        appAuthControllerProvider.overrideWith(_FakeAppAuthController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);
    await container.read(legacyOwnershipVerificationControllerProvider.future);

    await expectLater(
      container
          .read(legacyOwnershipVerificationControllerProvider.notifier)
          .verify(),
      throwsStateError,
    );
    expect(
      container.read(legacyOwnershipVerificationControllerProvider).hasError,
      isTrue,
    );

    repository.error = null;
    final retried = await container
        .read(legacyOwnershipVerificationControllerProvider.notifier)
        .verify();
    expect(retried.isVerified, isTrue);
    expect(repository.calls, 2);
  });
}

const _verified = LegacyOwnershipVerificationResult(
  outcome: LegacyOwnershipVerificationOutcome.verified,
  verifiedCount: 1,
  rejectedCount: 0,
  unknownCount: 0,
  reason: LegacyOwnershipVerificationReason.allEvidenceMatchesCurrentUser,
);

final class _FakeRepository implements LegacyOwnershipVerificationRepository {
  _FakeRepository(this.result, {this.error});

  final LegacyOwnershipVerificationResult result;
  Object? error;
  int calls = 0;

  @override
  Future<LegacyOwnershipVerificationResult> verifyCurrentDataSpace() async {
    calls += 1;
    if (error case final current?) throw current;
    return result;
  }
}

final class _FakeAppAuthController extends AppAuthController {
  @override
  Future<AppAuthState> build() async {
    return const AppAuthState(
      status: AppAuthStatus.authenticated,
      localUserId: 'local-user',
      cloudUserId: 'cloud-user',
      syncEligibility: AccountSyncEligibility.legacyReviewRequired,
      verificationStatus: AccountOwnershipVerificationStatus.notVerified,
    );
  }

  @override
  Future<void> retry() async {
    state = const AsyncData(
      AppAuthState(
        status: AppAuthStatus.authenticated,
        localUserId: 'local-user',
        cloudUserId: 'cloud-user',
        syncEligibility: AccountSyncEligibility.ready,
        verificationStatus: AccountOwnershipVerificationStatus.verified,
      ),
    );
  }
}
