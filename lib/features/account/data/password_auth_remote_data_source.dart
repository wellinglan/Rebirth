import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';

import 'dto/auth_dto.dart';

abstract interface class PasswordAuthRemoteDataSource {
  Future<AuthSession> register({
    required String username,
    required String password,
    required Map<String, Object?> clientMetadata,
    String? displayName,
  });

  Future<AuthSession> login({
    required String username,
    required String password,
    required Map<String, Object?> clientMetadata,
  });

  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    required String accessToken,
    String? displayName,
  });

  Future<void> revokeSession(AuthSession session);
}

final class PasswordAuthApiDataSource implements PasswordAuthRemoteDataSource {
  const PasswordAuthApiDataSource(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
    required Map<String, Object?> clientMetadata,
    String? displayName,
  }) {
    return _createSession(
      '/auth/register',
      username: username,
      password: password,
      clientMetadata: clientMetadata,
      displayName: displayName,
    );
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required Map<String, Object?> clientMetadata,
  }) {
    return _createSession(
      '/auth/login',
      username: username,
      password: password,
      clientMetadata: clientMetadata,
    );
  }

  @override
  Future<void> attachPasswordIdentity({
    required String devUserKey,
    required String username,
    required String password,
    required String accessToken,
    String? displayName,
  }) async {
    final body = <String, Object?>{
      'dev_user_key': devUserKey,
      'username': username,
      'password': password,
    };
    if (displayName != null) body['display_name'] = displayName;
    await apiClient.postJson(
      '/auth/identities/password/attach',
      accessToken: accessToken,
      timeout: const Duration(seconds: 8),
      body: body,
    );
  }

  @override
  Future<void> revokeSession(AuthSession session) async {
    await apiClient.postJson(
      '/auth/logout',
      accessToken: session.accessToken,
      timeout: const Duration(seconds: 5),
      body: {'refresh_token': session.refreshToken},
    );
  }

  Future<AuthSession> _createSession(
    String path, {
    required String username,
    required String password,
    required Map<String, Object?> clientMetadata,
    String? displayName,
  }) async {
    final body = <String, Object?>{
      'username': username,
      'password': password,
      ...clientMetadata,
    };
    if (displayName != null) body['display_name'] = displayName;
    final json = await apiClient.postJson(
      path,
      timeout: const Duration(seconds: 8),
      body: body,
    );
    try {
      return AuthSessionDto.fromJson(json).toDomain();
    } on FormatException catch (error) {
      throw ApiException(message: '后端返回了无法识别的数据。', cause: error);
    } on TypeError catch (error) {
      throw ApiException(message: '后端返回了无法识别的数据。', cause: error);
    }
  }
}
