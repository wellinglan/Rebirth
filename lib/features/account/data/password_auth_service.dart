import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';

import 'auth_session_manager.dart';
import 'dto/auth_dto.dart';

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
    required this.apiClient,
    required this.sessionManager,
    required this.serverBaseUrl,
    required this.loadClientMetadata,
  });

  final ApiClient apiClient;
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
      '/auth/register',
      username: username,
      password: password,
      displayName: displayName,
    );
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _createSession(
      '/auth/login',
      username: username,
      password: password,
    );
  }

  @override
  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    String? displayName,
  }) async {
    final body = <String, Object?>{
      'dev_user_key': devUserKey,
      'username': username,
      'password': password,
    };
    if (displayName != null) body['display_name'] = displayName;
    await sessionManager.runAuthorized(
      (accessToken) => apiClient.postJson(
        '/auth/identities/password/attach',
        accessToken: accessToken,
        timeout: const Duration(seconds: 8),
        body: body,
      ),
      canReplay: false,
    );
  }

  Future<AuthSession> _createSession(
    String path, {
    required String username,
    required String password,
    String? displayName,
  }) async {
    final metadata = await loadClientMetadata();
    final body = <String, Object?>{
      'username': username,
      'password': password,
      ...metadata,
    };
    if (displayName != null) body['display_name'] = displayName;
    final json = await apiClient.postJson(
      path,
      timeout: const Duration(seconds: 8),
      body: body,
    );
    final session = AuthSessionDto.fromJson(
      json,
    ).toDomain().copyWith(serverBaseUrl: serverBaseUrl);
    await sessionManager.acceptLogin(session);
    return session;
  }
}
