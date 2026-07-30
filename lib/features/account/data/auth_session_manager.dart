import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_session_manager_state.dart';
import 'package:rebirth/features/account/domain/backend_health.dart';
import 'package:rebirth/features/account/domain/device_registration.dart';

import 'account_api_data_source.dart';
import 'auth_session_store.dart';
import 'secure_auth_session_store.dart';

final class AuthSessionManager {
  AuthSessionManager({
    required this.sessionStore,
    required this.remoteDataSource,
    required this.serverBaseUrl,
    required this.nowMilliseconds,
    this._trustRuntimeAccessToken = false,
  });

  factory AuthSessionManager.forTesting({
    required AuthSessionStore sessionStore,
    int Function()? nowMilliseconds,
  }) {
    return AuthSessionManager(
      sessionStore: sessionStore,
      remoteDataSource: const _UnavailableAccountRemoteDataSource(),
      serverBaseUrl: 'http://127.0.0.1:8000',
      nowMilliseconds: nowMilliseconds ?? (() => 0),
      trustRuntimeAccessToken: true,
    );
  }

  final AuthSessionStore sessionStore;
  final AccountRemoteDataSource remoteDataSource;
  final String serverBaseUrl;
  final int Function() nowMilliseconds;
  final bool _trustRuntimeAccessToken;

  AuthSessionManagerState _state =
      const AuthSessionManagerState.uninitialized();
  Future<AuthSession?>? _refreshInFlight;

  AuthSessionManagerState get state => _state;

  Future<AuthSession?> readCurrentSession() => sessionStore.read();

  Future<AuthSessionManagerState> initialize() async {
    if (_state.status != AuthSessionManagerStatus.uninitialized) return _state;
    try {
      final session = await sessionStore.read();
      if (session == null) {
        _state = const AuthSessionManagerState(
          status: AuthSessionManagerStatus.signedOut,
        );
        return _state;
      }
      if (_hasUsableAccessToken(session)) {
        _state = AuthSessionManagerState(
          status: AuthSessionManagerStatus.authenticated,
          session: session,
        );
        return _state;
      }
      try {
        await remoteDataSource.getHealth();
      } on ApiException catch (error) {
        if (error.isNetworkError) {
          _state = AuthSessionManagerState(
            status: AuthSessionManagerStatus.authenticatedOffline,
            session: session,
          );
          return _state;
        }
        rethrow;
      }
      await _refresh(session);
      return _state;
    } on AuthSessionStorageException {
      await _rejectSession();
      return _state;
    } on ApiException catch (error) {
      if (_state.status == AuthSessionManagerStatus.sessionRejected ||
          _state.status == AuthSessionManagerStatus.refreshOutcomeUnknown) {
        return _state;
      }
      if (_isDefinitiveRefreshFailure(error)) {
        await _rejectSession();
      } else {
        final session = await sessionStore.read();
        _state = AuthSessionManagerState(
          status: error.isNetworkError
              ? AuthSessionManagerStatus.refreshOutcomeUnknown
              : AuthSessionManagerStatus.authenticatedOffline,
          session: session,
        );
      }
      return _state;
    }
  }

  Future<void> acceptLogin(AuthSession session) async {
    final bound = session.copyWith(
      serverBaseUrl: serverBaseUrl,
      lastVerifiedAt: nowMilliseconds(),
    );
    await sessionStore.save(bound);
    _state = AuthSessionManagerState(
      status: AuthSessionManagerStatus.authenticated,
      session: bound,
    );
  }

  Future<void> updateSession(AuthSession session) async {
    await sessionStore.save(session);
    _state = AuthSessionManagerState(
      status: AuthSessionManagerStatus.authenticated,
      session: session,
    );
  }

  Future<String> validAccessToken() async {
    if (_state.status == AuthSessionManagerStatus.uninitialized) {
      await initialize();
    }
    final current = _state.session ?? await sessionStore.read();
    if (current == null) {
      throw const ApiException(
        message: '登录状态已失效，请重新登录。',
        statusCode: 401,
        errorCode: 'authentication_required',
      );
    }
    if (_hasUsableAccessToken(current)) return current.accessToken;
    final refreshed = await _refresh(current);
    if (refreshed == null || refreshed.accessToken.isEmpty) {
      throw const ApiException(
        message: '当前无法验证云端会话。',
        statusCode: 401,
        errorCode: 'authentication_required',
      );
    }
    return refreshed.accessToken;
  }

  Future<String> refreshAfterAccessTokenExpired() async {
    final current = _state.session ?? await sessionStore.read();
    if (current == null) {
      throw const ApiException(
        message: '登录状态已失效，请重新登录。',
        statusCode: 401,
        errorCode: 'authentication_required',
      );
    }
    final refreshed = await _refresh(current);
    if (refreshed == null) {
      throw const ApiException(
        message: '登录状态已失效，请重新登录。',
        statusCode: 401,
        errorCode: 'authentication_required',
      );
    }
    return refreshed.accessToken;
  }

  Future<T> runAuthorized<T>(
    Future<T> Function(String accessToken) request, {
    bool canReplay = true,
  }) async {
    final token = await validAccessToken();
    try {
      return await request(token);
    } on ApiException catch (error) {
      if (error.errorCode == 'access_token_expired' && canReplay) {
        final refreshed = await refreshAfterAccessTokenExpired();
        try {
          return await request(refreshed);
        } on ApiException catch (retryError) {
          await handleDefinitiveAuthFailure(retryError);
          rethrow;
        }
      }
      await handleDefinitiveAuthFailure(error);
      rethrow;
    }
  }

  Future<void> handleDefinitiveAuthFailure(ApiException error) async {
    if (_isDefinitiveAccessFailure(error) ||
        _isDefinitiveRefreshFailure(error)) {
      await _rejectSession();
    }
  }

  Future<void> logout() async {
    final current = _state.session ?? await sessionStore.read();
    try {
      if (current != null) {
        await remoteDataSource.logout(
          refreshToken: current.refreshToken,
          accessToken: current.accessToken.isEmpty ? null : current.accessToken,
        );
      }
    } catch (_) {
      // Local logout is authoritative even when remote revocation is unknown.
    } finally {
      await sessionStore.clear();
      _state = const AuthSessionManagerState(
        status: AuthSessionManagerStatus.signedOut,
      );
    }
  }

  Future<AuthSession?> _refresh(AuthSession current) {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final operation = _performRefresh(current);
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) _refreshInFlight = null;
    });
  }

  Future<AuthSession?> _performRefresh(AuthSession current) async {
    _state = AuthSessionManagerState(
      status: AuthSessionManagerStatus.refreshing,
      session: current,
    );
    try {
      final refreshed =
          (await remoteDataSource.refreshSession(
            current.refreshToken,
          )).copyWith(
            serverBaseUrl: serverBaseUrl,
            deviceRegistration: current.deviceRegistration,
            lastVerifiedAt: nowMilliseconds(),
          );
      try {
        await sessionStore.save(refreshed);
      } on AuthSessionStorageException {
        await _rejectSession();
        rethrow;
      }
      _state = AuthSessionManagerState(
        status: AuthSessionManagerStatus.authenticated,
        session: refreshed,
      );
      return refreshed;
    } on ApiException catch (error) {
      if (_isDefinitiveRefreshFailure(error)) {
        await _rejectSession();
      } else if (error.isNetworkError) {
        await sessionStore.clear();
        _state = AuthSessionManagerState(
          status: AuthSessionManagerStatus.refreshOutcomeUnknown,
          session: current.copyWith(refreshToken: ''),
        );
      } else {
        _state = AuthSessionManagerState(
          status: AuthSessionManagerStatus.authenticatedOffline,
          session: current,
        );
      }
      rethrow;
    }
  }

  bool _hasUsableAccessToken(AuthSession session) {
    return session.accessToken.isNotEmpty &&
        (_trustRuntimeAccessToken ||
            session.accessExpiresAt > nowMilliseconds() + 30 * 1000);
  }

  bool _isDefinitiveRefreshFailure(ApiException error) {
    return const {
      'refresh_token_invalid',
      'refresh_token_expired',
      'refresh_token_reused',
      'session_revoked',
      'session_expired',
      'legacy_token_migration_closed',
    }.contains(error.errorCode);
  }

  bool _isDefinitiveAccessFailure(ApiException error) {
    return const {
      'access_token_invalid',
      'session_revoked',
      'session_expired',
    }.contains(error.errorCode);
  }

  Future<void> _rejectSession() async {
    await sessionStore.clear();
    _state = const AuthSessionManagerState(
      status: AuthSessionManagerStatus.sessionRejected,
    );
  }
}

final class _UnavailableAccountRemoteDataSource
    implements AccountRemoteDataSource {
  const _UnavailableAccountRemoteDataSource();

  @override
  Future<BackendHealth> getHealth() =>
      throw UnsupportedError('Network is unavailable in this test manager.');

  @override
  Future<AuthSession> devLogin(String devUserKey) =>
      throw UnsupportedError('Development login is unavailable.');

  @override
  Future<AuthSession> refreshSession(String refreshToken) =>
      throw UnsupportedError('Refresh is unavailable.');

  @override
  Future<void> logout({
    required String refreshToken,
    String? accessToken,
  }) async {}

  @override
  Future<DeviceRegistration> registerDevice(
    DeviceRegistrationRequest request, {
    required String accessToken,
  }) => throw UnsupportedError('Device registration is unavailable.');
}
