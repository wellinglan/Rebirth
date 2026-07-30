import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';

abstract interface class IdentityRemoteDataSource {
  Future<List<AuthIdentity>> getCurrentIdentities({
    required String accessToken,
  });
}

final class IdentityApiDataSource implements IdentityRemoteDataSource {
  const IdentityApiDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AuthIdentity>> getCurrentIdentities({
    required String accessToken,
  }) async {
    final json = await _apiClient.getJson(
      '/auth/identities',
      accessToken: accessToken,
    );
    try {
      final values = json['identities'];
      if (values is! List) {
        throw const FormatException('Missing identities.');
      }
      return values
          .map((value) {
            if (value is! Map) {
              throw const FormatException('Invalid identity.');
            }
            final item = Map<String, Object?>.from(value);
            final provider = item['provider'];
            final createdAt = item['created_at'];
            final lastUsedAt = item['last_used_at'];
            if (provider is! String ||
                createdAt is! int ||
                (lastUsedAt != null && lastUsedAt is! int)) {
              throw const FormatException('Invalid identity fields.');
            }
            return AuthIdentity(
              provider: AuthIdentityProvider.fromWire(provider),
              createdAt: createdAt,
              lastUsedAt: lastUsedAt as int?,
            );
          })
          .toList(growable: false);
    } on FormatException catch (error) {
      throw ApiException(message: '服务器返回了无法识别的登录方式数据。', cause: error);
    } on TypeError catch (error) {
      throw ApiException(message: '服务器返回了无法识别的登录方式数据。', cause: error);
    }
  }
}
