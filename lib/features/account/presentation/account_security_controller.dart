import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';

import 'account_security_state.dart';
import 'app_auth_controller.dart';

final accountSecurityControllerProvider =
    AsyncNotifierProvider<AccountSecurityController, AccountSecurityState>(
      AccountSecurityController.new,
    );

class AccountSecurityController extends AsyncNotifier<AccountSecurityState> {
  @override
  Future<AccountSecurityState> build() async {
    final auth = ref.watch(appAuthStateProvider).value;
    if (auth == null || !auth.canAccessBusiness) {
      throw StateError('Authentication is required.');
    }
    if (auth.status == AppAuthStatus.authenticatedOffline) {
      final provider = auth.identityProvider;
      return AccountSecurityState(
        identities: provider == null
            ? const []
            : [
                AuthIdentity(
                  provider: AuthIdentityProvider.fromWire(provider),
                  createdAt: 0,
                  lastUsedAt: null,
                ),
              ],
        isOfflineSnapshot: true,
      );
    }
    return AccountSecurityState(
      identities: await ref
          .read(identityRepositoryProvider)
          .getCurrentIdentities(),
    );
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  Future<WechatBindingStartResult> startWechatBinding({
    required ReauthenticationMethod method,
    required String credential,
  }) async {
    final current = state.value;
    final auth = ref.read(appAuthStateProvider).value;
    if (current == null ||
        current.isStartingWechatBinding ||
        auth == null ||
        auth.status != AppAuthStatus.authenticated) {
      throw StateError('An online authenticated session is required.');
    }

    state = AsyncData(current.copyWith(isStartingWechatBinding: true));
    try {
      final repository = ref.read(identityRepositoryProvider);
      final proof = await repository.reauthenticate(
        method: method,
        credential: credential,
      );
      return await repository.startWechatBinding(
        reauthenticationProof: proof.value,
      );
    } finally {
      final latest = state.value;
      if (latest != null) {
        state = AsyncData(latest.copyWith(isStartingWechatBinding: false));
      }
    }
  }
}
