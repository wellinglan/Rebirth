import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/data/password_auth_service.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/account_boundary_repository.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/domain/auth_repository.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

void main() {
  test(
    'signedOut deactivates local profiles and exposes no business access',
    () async {
      final boundary = _FakeBoundary();
      final container = _container(
        sessionStore: _MemorySessionStore(null),
        boundary: boundary,
        authRepository: _FakeAuthRepository(),
      );
      addTearDown(container.dispose);

      final state = await container.read(appAuthControllerProvider.future);

      expect(state.status, AppAuthStatus.signedOut);
      expect(state.canAccessBusiness, isFalse);
      expect(boundary.deactivateCalls, 1);
    },
  );

  test('valid session and reachable backend become authenticated', () async {
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: _FakeBoundary(resolution: _activatedResolution),
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    final state = await container.read(appAuthControllerProvider.future);

    expect(state.status, AppAuthStatus.authenticated);
    expect(state.localUserId, 'local-a');
    expect(state.cloudUserId, 'cloud-a');
    expect(state.canAccessBusiness, isTrue);
  });

  test('valid bound session remains usable while backend is offline', () async {
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: _FakeBoundary(resolution: _activatedResolution),
      authRepository: _FakeAuthRepository(
        healthError: const ApiException(
          message: 'offline',
          isNetworkError: true,
        ),
      ),
    );
    addTearDown(container.dispose);

    final state = await container.read(appAuthControllerProvider.future);

    expect(state.status, AppAuthStatus.authenticatedOffline);
    expect(state.canAccessBusiness, isTrue);
    expect(state.isOffline, isTrue);
  });

  test('rejected account scope exposes sessionRejected', () async {
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: _FakeBoundary(
        error: const AccountSessionRejectedException('session rejected'),
      ),
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    final state = await container.read(appAuthControllerProvider.future);

    expect(state.status, AppAuthStatus.sessionRejected);
    expect(state.message, 'session rejected');
    expect(state.canAccessBusiness, isFalse);
  });

  test('unbound legacy profile exposes bindingRequired', () async {
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: _FakeBoundary(
        resolution: const AccountBindingResolution.bindingRequired(
          unboundProfileCount: 1,
          accountScope: _scope,
        ),
      ),
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);

    final state = await container.read(appAuthControllerProvider.future);

    expect(state.status, AppAuthStatus.bindingRequired);
    expect(state.unboundProfileCount, 1);
    expect(state.canAccessBusiness, isFalse);
  });

  test('legacy claim enters local app with sync review quarantine', () async {
    final boundary = _FakeBoundary(
      resolution: const AccountBindingResolution.bindingRequired(
        unboundProfileCount: 1,
        accountScope: _scope,
      ),
    );
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: boundary,
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);

    await container
        .read(appAuthControllerProvider.notifier)
        .claimLegacyDataSpace('legacy-local');

    final state = container.read(appAuthControllerProvider).value!;
    expect(state.status, AppAuthStatus.authenticated);
    expect(state.localUserId, 'legacy-local');
    expect(state.syncEligibility, AccountSyncEligibility.legacyReviewRequired);
    expect(
      state.verificationStatus,
      AccountOwnershipVerificationStatus.notVerified,
    );
    expect(state.canAccessBusiness, isTrue);
    expect(state.canUseCloudSync, isFalse);
    expect(boundary.claimCalls, 1);
  });

  test('fresh space enters local app with ready sync eligibility', () async {
    final boundary = _FakeBoundary(
      resolution: const AccountBindingResolution.bindingRequired(
        unboundProfileCount: 1,
        accountScope: _scope,
      ),
    );
    final container = _container(
      sessionStore: _MemorySessionStore(_session),
      boundary: boundary,
      authRepository: _FakeAuthRepository(),
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);

    await container
        .read(appAuthControllerProvider.notifier)
        .createFreshDataSpace();

    final state = container.read(appAuthControllerProvider).value!;
    expect(state.localUserId, 'fresh-local');
    expect(state.syncEligibility, AccountSyncEligibility.ready);
    expect(
      state.verificationStatus,
      AccountOwnershipVerificationStatus.verified,
    );
    expect(state.canUseCloudSync, isTrue);
    expect(boundary.createFreshCalls, 1);
  });

  test(
    'password login establishes account boundary and identity metadata',
    () async {
      final passwordAuth = _FakePasswordAuthService();
      final container = _container(
        sessionStore: _MemorySessionStore(null),
        boundary: _FakeBoundary(resolution: _activatedResolution),
        authRepository: _FakeAuthRepository(),
        passwordAuthService: passwordAuth,
      );
      addTearDown(container.dispose);
      await container.read(appAuthControllerProvider.future);

      final result = await container
          .read(appAuthControllerProvider.notifier)
          .loginWithPassword(
            username: 'Account.User',
            password: ' exact password ',
          );

      final state = container.read(appAuthControllerProvider).value!;
      expect(result, isTrue);
      expect(passwordAuth.lastUsername, 'account.user');
      expect(passwordAuth.lastPassword, ' exact password ');
      expect(state.status, AppAuthStatus.authenticated);
      expect(state.identityProvider, 'password_username');
      expect(state.displayName, 'Account A');
    },
  );

  test(
    'registration passes nullable display name and enters the local space',
    () async {
      final passwordAuth = _FakePasswordAuthService();
      final container = _container(
        sessionStore: _MemorySessionStore(null),
        boundary: _FakeBoundary(resolution: _activatedResolution),
        authRepository: _FakeAuthRepository(),
        passwordAuthService: passwordAuth,
      );
      addTearDown(container.dispose);
      await container.read(appAuthControllerProvider.future);

      final result = await container
          .read(appAuthControllerProvider.notifier)
          .registerWithPassword(
            username: 'New.User',
            password: 'registration password',
            displayName: null,
          );

      expect(result, isTrue);
      expect(passwordAuth.registerCalls, 1);
      expect(passwordAuth.lastUsername, 'new.user');
      expect(passwordAuth.lastDisplayName, isNull);
    },
  );

  test('login is single-flight and state never retains a password', () async {
    final pending = Completer<AuthSession>();
    final passwordAuth = _FakePasswordAuthService(loginResult: pending.future);
    final container = _container(
      sessionStore: _MemorySessionStore(null),
      boundary: _FakeBoundary(resolution: _activatedResolution),
      authRepository: _FakeAuthRepository(),
      passwordAuthService: passwordAuth,
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);

    final first = container
        .read(appAuthControllerProvider.notifier)
        .loginWithPassword(username: 'Account.User', password: 'private value');
    final second = await container
        .read(appAuthControllerProvider.notifier)
        .loginWithPassword(username: 'Account.User', password: 'private value');

    expect(second, isFalse);
    expect(passwordAuth.loginCalls, 1);
    final submitting = container.read(appAuthControllerProvider).value!;
    expect(submitting.status, AppAuthStatus.submittingLogin);
    expect(submitting.toString(), isNot(contains('private value')));

    pending.complete(_passwordSession);
    expect(await first, isTrue);
  });

  test('safe mapped login failure leaves account boundary unchanged', () async {
    final boundary = _FakeBoundary();
    final passwordAuth = _FakePasswordAuthService(
      error: const ApiException(
        message: 'raw response 401',
        statusCode: 401,
        errorCode: 'invalid_credentials',
      ),
    );
    final container = _container(
      sessionStore: _MemorySessionStore(null),
      boundary: boundary,
      authRepository: _FakeAuthRepository(),
      passwordAuthService: passwordAuth,
    );
    addTearDown(container.dispose);
    await container.read(appAuthControllerProvider.future);
    final initialDeactivateCalls = boundary.deactivateCalls;

    final result = await container
        .read(appAuthControllerProvider.notifier)
        .loginWithPassword(username: 'Known.User', password: 'wrong password');

    final state = container.read(appAuthControllerProvider).value!;
    expect(result, isFalse);
    expect(state.status, AppAuthStatus.signedOut);
    expect(state.message, '用户名或密码不正确。');
    expect(boundary.deactivateCalls, initialDeactivateCalls);
  });

  test(
    'controller denies developer login when the build disables it',
    () async {
      final repository = _FakeAuthRepository();
      final container = _container(
        sessionStore: _MemorySessionStore(null),
        boundary: _FakeBoundary(),
        authRepository: repository,
        config: const AppConfig.test(enableDevLogin: false),
      );
      addTearDown(container.dispose);
      await container.read(appAuthControllerProvider.future);

      final result = await container
          .read(appAuthControllerProvider.notifier)
          .devLogin('not-used');

      expect(result, isFalse);
      expect(repository.devLoginCalls, 0);
    },
  );
}

ProviderContainer _container({
  required AuthSessionStore sessionStore,
  required AccountBoundaryRepository boundary,
  required AuthRepository authRepository,
  PasswordAuthService? passwordAuthService,
  AppConfig config = const AppConfig.test(enableDevLogin: true),
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      authSessionStoreProvider.overrideWithValue(sessionStore),
      accountBoundaryRepositoryProvider.overrideWithValue(boundary),
      accountRepositoryProvider.overrideWithValue(authRepository),
      if (passwordAuthService != null)
        passwordAuthServiceProvider.overrideWithValue(passwordAuthService),
    ],
  );
}

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

final class _FakeBoundary implements AccountBoundaryRepository {
  _FakeBoundary({this.resolution = _activatedResolution, this.error});

  final AccountBindingResolution resolution;
  final Object? error;
  int deactivateCalls = 0;
  int claimCalls = 0;
  int createFreshCalls = 0;

  @override
  Future<void> deactivateAllProfiles() async {
    deactivateCalls += 1;
  }

  @override
  Future<AccountBindingResolution> claimLegacyDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
    required String localUserId,
  }) async {
    claimCalls += 1;
    return AccountBindingResolution.activated(
      localUserId: localUserId,
      accountScope: expectedScope,
      syncEligibility: AccountSyncEligibility.legacyReviewRequired,
      verificationStatus: AccountOwnershipVerificationStatus.notVerified,
    );
  }

  @override
  Future<AccountBindingResolution> createFreshDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
  }) async {
    createFreshCalls += 1;
    return AccountBindingResolution.activated(
      localUserId: 'fresh-local',
      accountScope: expectedScope,
      syncEligibility: AccountSyncEligibility.ready,
    );
  }

  @override
  Future<InstallationInfoRow> ensureInstallation() {
    throw UnimplementedError();
  }

  @override
  Future<String> requireActiveScope({
    required String endpoint,
    required String cloudUserId,
  }) async {
    return resolution.localUserId ?? 'local-a';
  }

  @override
  Future<List<LegacyLocalDataSpaceCandidate>> listLegacyDataSpaces() async {
    return const [];
  }

  @override
  Future<AccountBindingResolution> resolveAndActivate(
    AuthSession session,
  ) async {
    if (error case final value?) throw value;
    return resolution;
  }
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.healthError});

  final Object? healthError;
  int devLoginCalls = 0;

  @override
  Future<BackendHealth> checkBackendHealth() async {
    if (healthError case final value?) throw value;
    return const BackendHealth(status: 'ok', service: 'rebirth-api');
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) async {
    devLoginCalls += 1;
    return _session;
  }

  @override
  Future<AccountStatus> getAccountStatus() {
    throw UnimplementedError();
  }

  @override
  Future<DeviceRegistration> registerCurrentDevice() {
    throw UnimplementedError();
  }

  @override
  Future<void> refreshSession() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}
}

final class _FakePasswordAuthService implements PasswordAuthService {
  _FakePasswordAuthService({this.loginResult, this.error});

  final Future<AuthSession>? loginResult;
  final Object? error;
  int loginCalls = 0;
  int registerCalls = 0;
  String? lastUsername;
  String? lastPassword;
  String? lastDisplayName;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    lastUsername = username;
    lastPassword = password;
    if (error case final value?) throw value;
    return loginResult ?? _passwordSession;
  }

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    registerCalls += 1;
    lastUsername = username;
    lastPassword = password;
    lastDisplayName = displayName;
    if (error case final value?) throw value;
    return _passwordSession;
  }

  @override
  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError();
  }
}

const _session = AuthSession(
  accessToken: 'token',
  refreshToken: 'refresh',
  user: AuthUser(id: 'cloud-a', displayName: 'Account A'),
  serverBaseUrl: 'https://alpha.example.test',
);

const _passwordSession = AuthSession(
  accessToken: 'runtime',
  refreshToken: 'refresh',
  user: AuthUser(id: 'cloud-a', displayName: 'Account A'),
  serverBaseUrl: 'https://alpha.example.test',
  identityProvider: 'password_username',
);

const _scope = CloudAccountScope(
  endpointKey: 'https://alpha.example.test',
  cloudUserId: 'cloud-a',
);

const _activatedResolution = AccountBindingResolution.activated(
  localUserId: 'local-a',
  accountScope: _scope,
  syncEligibility: AccountSyncEligibility.ready,
);
