import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';

import 'account_scoped_provider_invalidator.dart';
import 'app_auth_controller.dart';

final legacyOwnershipVerificationControllerProvider =
    AsyncNotifierProvider<
      LegacyOwnershipVerificationController,
      LegacyOwnershipVerificationResult?
    >(LegacyOwnershipVerificationController.new);

class LegacyOwnershipVerificationController
    extends AsyncNotifier<LegacyOwnershipVerificationResult?> {
  @override
  Future<LegacyOwnershipVerificationResult?> build() async => null;

  Future<LegacyOwnershipVerificationResult> verify() async {
    if (state.isLoading) {
      throw StateError('Ownership verification is already running.');
    }
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(legacyOwnershipVerificationRepositoryProvider)
          .verifyCurrentDataSpace();
      invalidateAccountScopedProviders(ref);
      await ref.read(appAuthControllerProvider.notifier).retry();
      state = AsyncData(result);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
