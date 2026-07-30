import 'package:rebirth/features/account/domain/auth_session.dart';

import 'auth_session_manager.dart';
import 'password_auth_remote_data_source.dart';
import 'secure_auth_session_store.dart';

abstract interface class PasswordAuthService {
  Future<AuthSession> register({
    required String username,
    required String password,
    String? displayName,
  });

  Future<AuthSession> login({
    required String username,
    required String password,
  });

  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    String? displayName,
  });
}

final class PasswordAuthServiceImpl implements PasswordAuthService {
  const PasswordAuthServiceImpl({
    required this.remoteDataSource,
    required this.sessionManager,
    required this.serverBaseUrl,
    required this.loadClientMetadata,
  });

  final PasswordAuthRemoteDataSource remoteDataSource;
  final AuthSessionManager sessionManager;
  final String serverBaseUrl;
  final Future<Map<String, Object?>> Function() loadClientMetadata;

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
    String? displayName,
  }) {
    return _createSession(
      (metadata) => remoteDataSource.register(
        username: username,
        password: password,
        displayName: displayName,
        clientMetadata: metadata,
      ),
    );
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _createSession(
      (metadata) => remoteDataSource.login(
        username: username,
        password: password,
        clientMetadata: metadata,
      ),
    );
  }

  @override
  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    String? displayName,
  }) async {
    await sessionManager.runAuthorized(
      (accessToken) => remoteDataSource.attachPasswordIdentity(
        devUserKey: devUserKey,
        username: username,
        password: password,
        displayName: displayName,
        accessToken: accessToken,
      ),
      canReplay: false,
    );
  }

  Future<AuthSession> _createSession(
    Future<AuthSession> Function(Map<String, Object?> metadata) request,
  ) async {
    final metadata = await loadClientMetadata();
    final session = (await request(
      metadata,
    )).copyWith(serverBaseUrl: serverBaseUrl);
    try {
      await sessionManager.acceptLogin(session);
    } on AuthSessionStorageException {
      await _revokeUnpersistedSession(session);
      rethrow;
    }
    return session;
  }

  Future<void> _revokeUnpersistedSession(AuthSession session) async {
    try {
      await remoteDataSource.revokeSession(session);
    } catch (_) {
      // The local session remains unusable even if remote revocation is unknown.
    }
    await sessionManager.discardUnpersistedLogin();
  }
}
