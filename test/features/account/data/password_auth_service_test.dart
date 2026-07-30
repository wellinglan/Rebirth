import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/data/password_auth_service.dart';
import 'package:rebirth/features/account/data/password_auth_remote_data_source.dart';
import 'package:rebirth/features/account/data/secure_auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';

void main() {
  late _MemorySessionStore store;
  late AuthSessionManager manager;
  late _RecordingApiClient api;
  late PasswordAuthServiceImpl service;

  setUp(() {
    store = _MemorySessionStore();
    manager = AuthSessionManager.forTesting(
      sessionStore: store,
      nowMilliseconds: () => 1000,
    );
    api = _RecordingApiClient();
    service = PasswordAuthServiceImpl(
      remoteDataSource: PasswordAuthApiDataSource(api),
      sessionManager: manager,
      serverBaseUrl: 'https://api.example',
      loadClientMetadata: () async => {
        'client_installation_id': 'install-1',
        'platform': 'windows',
        'app_version': 'test',
      },
    );
  });

  test(
    'register accepts the returned session without trimming password',
    () async {
      await service.register(
        username: 'Example.User',
        password: '  exact password  ',
        displayName: 'Example',
      );

      expect(api.lastPath, '/auth/register');
      expect(api.lastBody?['password'], '  exact password  ');
      expect(api.lastBody?['client_installation_id'], 'install-1');
      expect(store.session?.refreshToken, 'refresh-token');
      expect(store.session?.serverBaseUrl, 'http://127.0.0.1:8000');
    },
  );

  test('login accepts the returned session', () async {
    final session = await service.login(
      username: 'example.user',
      password: 'password-is-long-enough',
    );

    expect(api.lastPath, '/auth/login');
    expect(session.identityProvider, 'password_username');
    expect(manager.state.session?.user.id, 'user-1');
  });

  test(
    'attach uses current access token and does not replace session',
    () async {
      await manager.acceptLogin(_session);

      await service.attachPasswordIdentity(
        devUserKey: 'dev-key',
        username: 'example.user',
        password: 'password-is-long-enough',
      );

      expect(api.lastPath, '/auth/identities/password/attach');
      expect(api.lastAccessToken, 'runtime-access');
      expect(api.lastBody?['dev_user_key'], 'dev-key');
      expect(store.session?.identityProvider, 'dev');
    },
  );

  test('secure-store failure revokes the new server session', () async {
    final failingManager = AuthSessionManager.forTesting(
      sessionStore: _FailingSessionStore(),
    );
    final failingService = PasswordAuthServiceImpl(
      remoteDataSource: PasswordAuthApiDataSource(api),
      sessionManager: failingManager,
      serverBaseUrl: 'https://api.example',
      loadClientMetadata: () async => const {},
    );

    await expectLater(
      failingService.login(
        username: 'example.user',
        password: 'password-is-long-enough',
      ),
      throwsA(isA<AuthSessionStorageException>()),
    );

    expect(api.paths, ['/auth/login', '/auth/logout']);
    expect(failingManager.state.session, isNull);
  });
}

const _session = AuthSession(
  accessToken: 'runtime-access',
  refreshToken: 'refresh-token',
  accessExpiresAt: 900000,
  refreshExpiresAt: 1800000,
  sessionAbsoluteExpiresAt: 2700000,
  sessionId: 'session-1',
  identityProvider: 'dev',
  user: AuthUser(id: 'user-1', displayName: 'Alpha User'),
);

final class _MemorySessionStore implements AuthSessionStore {
  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;
}

final class _FailingSessionStore implements AuthSessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> save(AuthSession session) {
    throw const AuthSessionStorageException('private platform detail');
  }
}

final class _RecordingApiClient implements ApiClient {
  final List<String> paths = [];
  String? lastPath;
  String? lastAccessToken;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) async {
    paths.add(path);
    lastPath = path;
    lastAccessToken = accessToken;
    lastBody = body;
    if (path.endsWith('/attach')) {
      return {
        'status': 'attached',
        'provider': 'password_username',
        'user': {'id': 'user-1', 'display_name': 'Alpha User'},
      };
    }
    return {
      'access_token': 'runtime-access',
      'refresh_token': 'refresh-token',
      'token_type': 'bearer',
      'access_expires_at': 900000,
      'refresh_expires_at': 1800000,
      'session_absolute_expires_at': 2700000,
      'session_id': 'session-1',
      'identity_provider': 'password_username',
      'user': {'id': 'user-1', 'display_name': 'Example'},
    };
  }
}
