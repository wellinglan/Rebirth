import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/domain/identity_repository.dart';
import 'package:rebirth/features/account/presentation/account_security_controller.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

void main() {
  test('authenticated account loads identities', () async {
    final repository = _FakeIdentityRepository();
    final container = _container(
      repository: repository,
      auth: const AppAuthState(
        status: AppAuthStatus.authenticated,
        cloudUserId: 'cloud-a',
        localUserId: 'local-a',
        identityProvider: 'password_username',
      ),
    );
    addTearDown(container.dispose);

    final state = await container.read(
      accountSecurityControllerProvider.future,
    );

    expect(state.identities.single.provider, AuthIdentityProvider.password);
    expect(state.isOfflineSnapshot, isFalse);
    expect(repository.calls, 1);
  });

  test('account switch rebuilds identity state', () async {
    final repository = _FakeIdentityRepository();
    final authController = _SwitchingAppAuthController(
      const AppAuthState(
        status: AppAuthStatus.authenticated,
        cloudUserId: 'cloud-a',
        localUserId: 'local-a',
        identityProvider: 'password_username',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(repository),
        appAuthControllerProvider.overrideWith(() => authController),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);
    await container.read(accountSecurityControllerProvider.future);

    authController.switchTo(
      const AppAuthState(
        status: AppAuthStatus.authenticated,
        cloudUserId: 'cloud-b',
        localUserId: 'local-b',
        identityProvider: 'dev',
      ),
    );
    await container.read(accountSecurityControllerProvider.future);

    expect(repository.calls, 2);
  });

  test(
    'offline account uses current session identity without network',
    () async {
      final repository = _FakeIdentityRepository();
      final container = _container(
        repository: repository,
        auth: const AppAuthState(
          status: AppAuthStatus.authenticatedOffline,
          cloudUserId: 'cloud-a',
          localUserId: 'local-a',
          identityProvider: 'dev',
        ),
      );
      addTearDown(container.dispose);

      final state = await container.read(
        accountSecurityControllerProvider.future,
      );

      expect(state.isOfflineSnapshot, isTrue);
      expect(state.identities.single.provider, AuthIdentityProvider.developer);
      expect(repository.calls, 0);
    },
  );

  test('signed-out account is denied', () async {
    final container = _container(
      repository: _FakeIdentityRepository(),
      auth: const AppAuthState.signedOut(),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(accountSecurityControllerProvider.future),
      throwsStateError,
    );
  });
}

ProviderContainer _container({
  required IdentityRepository repository,
  required AppAuthState auth,
}) {
  return ProviderContainer(
    overrides: [
      identityRepositoryProvider.overrideWithValue(repository),
      appAuthStateProvider.overrideWithValue(AsyncData(auth)),
    ],
  );
}

final class _FakeIdentityRepository implements IdentityRepository {
  int calls = 0;

  @override
  Future<List<AuthIdentity>> getCurrentIdentities() async {
    calls += 1;
    return const [
      AuthIdentity(
        provider: AuthIdentityProvider.password,
        createdAt: 100,
        lastUsedAt: 200,
      ),
    ];
  }
}

final class _SwitchingAppAuthController extends AppAuthController {
  _SwitchingAppAuthController(this.initial);

  final AppAuthState initial;

  @override
  Future<AppAuthState> build() async => initial;

  void switchTo(AppAuthState value) {
    state = AsyncData(value);
  }
}
