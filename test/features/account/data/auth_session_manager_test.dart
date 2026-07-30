import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/account_api_data_source.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_session_manager_state.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

void main() {
  late _MemorySessionStore store;
  late _FakeAccountRemote remote;
  late AuthSessionManager manager;

  setUp(() {
    store = _MemorySessionStore();
    remote = _FakeAccountRemote();
    manager = AuthSessionManager(
      sessionStore: store,
      remoteDataSource: remote,
      serverBaseUrl: _endpoint,
      nowMilliseconds: () => 1000,
    );
  });

  test('no secure session initializes signed out', () async {
    final state = await manager.initialize();

    expect(state.status, AuthSessionManagerStatus.signedOut);
    expect(remote.refreshCalls, 0);
  });

  test(
    'offline startup preserves the session without consuming refresh',
    () async {
      store.session = _persistedSession;
      remote.healthError = const ApiException(
        message: 'offline',
        isNetworkError: true,
      );

      final state = await manager.initialize();

      expect(state.status, AuthSessionManagerStatus.authenticatedOffline);
      expect(state.session?.refreshToken, 'refresh-1');
      expect(remote.refreshCalls, 0);
      expect(store.clearCount, 0);
    },
  );

  test('startup refresh stores a new token pair', () async {
    store.session = _persistedSession;
    remote.refreshResult = _runtimeSession;

    final state = await manager.initialize();

    expect(state.status, AuthSessionManagerStatus.authenticated);
    expect(state.session?.accessToken, 'access-2');
    expect(store.session?.refreshToken, 'refresh-2');
    expect(remote.refreshCalls, 1);
  });

  test('concurrent access requests share one refresh future', () async {
    store.session = _persistedSession;
    final refresh = Completer<AuthSession>();
    remote.refreshCompleter = refresh;

    final first = manager.validAccessToken();
    final second = manager.validAccessToken();
    await Future<void>.delayed(Duration.zero);
    expect(remote.refreshCalls, 1);

    refresh.complete(_runtimeSession);

    expect(await first, 'access-2');
    expect(await second, 'access-2');
    expect(remote.refreshCalls, 1);
  });

  test('definitive refresh rejection clears only cloud credentials', () async {
    store.session = _persistedSession;
    remote.refreshError = const ApiException(
      message: 'revoked',
      statusCode: 401,
      errorCode: 'session_revoked',
    );

    await expectLater(manager.initialize(), completes);

    expect(manager.state.status, AuthSessionManagerStatus.sessionRejected);
    expect(store.session, isNull);
    expect(store.clearCount, 1);
  });

  test(
    'refresh network outcome unknown does not retain old refresh token',
    () async {
      store.session = _persistedSession;
      remote.refreshError = const ApiException(
        message: 'timeout',
        isNetworkError: true,
      );

      final state = await manager.initialize();

      expect(state.status, AuthSessionManagerStatus.refreshOutcomeUnknown);
      expect(state.session?.refreshToken, isEmpty);
      expect(store.session, isNull);
      expect(store.clearCount, 1);
    },
  );

  test('local logout succeeds when remote revocation fails', () async {
    store.session = _runtimeSession;
    await manager.initialize();
    remote.logoutError = const ApiException(
      message: 'offline',
      isNetworkError: true,
    );

    await manager.logout();

    expect(manager.state.status, AuthSessionManagerStatus.signedOut);
    expect(store.session, isNull);
    expect(store.clearCount, 1);
  });

  test(
    'access token expiry refreshes and replays a request only once',
    () async {
      store.session = _runtimeSession;
      remote.refreshResult = _runtimeSession.copyWith(
        accessToken: 'access-3',
        refreshToken: 'refresh-3',
      );
      var calls = 0;

      final result = await manager.runAuthorized((token) async {
        calls += 1;
        if (calls == 1) {
          throw const ApiException(
            message: 'expired',
            statusCode: 401,
            errorCode: 'access_token_expired',
          );
        }
        return token;
      });

      expect(result, 'access-3');
      expect(calls, 2);
      expect(remote.refreshCalls, 1);
    },
  );

  test('a definitive second 401 stops retry and rejects the session', () async {
    store.session = _runtimeSession;
    remote.refreshResult = _runtimeSession.copyWith(
      accessToken: 'access-3',
      refreshToken: 'refresh-3',
    );
    var calls = 0;

    await expectLater(
      manager.runAuthorized<void>((_) async {
        calls += 1;
        throw ApiException(
          message: calls == 1 ? 'expired' : 'revoked',
          statusCode: 401,
          errorCode: calls == 1 ? 'access_token_expired' : 'session_revoked',
        );
      }),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'session_revoked',
        ),
      ),
    );

    expect(calls, 2);
    expect(remote.refreshCalls, 1);
    expect(manager.state.status, AuthSessionManagerStatus.sessionRejected);
    expect(store.session, isNull);
  });
}

const _endpoint = 'http://127.0.0.1:8000';
const _persistedSession = AuthSession(
  accessToken: '',
  refreshToken: 'refresh-1',
  user: AuthUser(id: 'cloud-user-1', displayName: 'Alpha User'),
  serverBaseUrl: _endpoint,
  refreshExpiresAt: 500000,
  sessionAbsoluteExpiresAt: 900000,
  sessionId: 'session-1',
  identityProvider: 'dev',
);
const _runtimeSession = AuthSession(
  accessToken: 'access-2',
  refreshToken: 'refresh-2',
  user: AuthUser(id: 'cloud-user-1', displayName: 'Alpha User'),
  serverBaseUrl: _endpoint,
  accessExpiresAt: 120000,
  refreshExpiresAt: 500000,
  sessionAbsoluteExpiresAt: 900000,
  sessionId: 'session-1',
  identityProvider: 'dev',
);

final class _MemorySessionStore implements AuthSessionStore {
  AuthSession? session;
  int clearCount = 0;

  @override
  Future<void> clear() async {
    clearCount += 1;
    session = null;
  }

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }
}

final class _FakeAccountRemote implements AccountRemoteDataSource {
  ApiException? healthError;
  ApiException? refreshError;
  ApiException? logoutError;
  AuthSession refreshResult = _runtimeSession;
  Completer<AuthSession>? refreshCompleter;
  int refreshCalls = 0;

  @override
  Future<BackendHealth> getHealth() async {
    if (healthError case final error?) throw error;
    return const BackendHealth(status: 'ok', service: 'rebirth-api');
  }

  @override
  Future<AuthSession> refreshSession(String refreshToken) async {
    refreshCalls += 1;
    if (refreshError case final error?) throw error;
    final completer = refreshCompleter;
    return completer == null ? refreshResult : completer.future;
  }

  @override
  Future<void> logout({
    required String refreshToken,
    String? accessToken,
  }) async {
    if (logoutError case final error?) throw error;
  }

  @override
  Future<AuthSession> devLogin(String devUserKey) => throw UnimplementedError();

  @override
  Future<DeviceRegistration> registerDevice(
    DeviceRegistrationRequest request, {
    required String accessToken,
  }) => throw UnimplementedError();
}
