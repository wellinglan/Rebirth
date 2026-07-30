import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/identity_api_data_source.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';

void main() {
  test('parses safe identity summaries and sends bearer token', () async {
    final api = _IdentityApiClient({
      'identities': [
        {'provider': 'password', 'created_at': 100, 'last_used_at': 200},
        {'provider': 'developer', 'created_at': 300, 'last_used_at': null},
      ],
    });

    final identities = await IdentityApiDataSource(
      api,
    ).getCurrentIdentities(accessToken: 'access-token');

    expect(api.path, '/auth/identities');
    expect(api.accessToken, 'access-token');
    expect(identities, hasLength(2));
    expect(identities.first.provider, AuthIdentityProvider.password);
    expect(identities.first.lastUsedAt, 200);
    expect(identities.last.provider, AuthIdentityProvider.developer);
  });

  test('rejects malformed identity responses', () async {
    final api = _IdentityApiClient({
      'identities': [
        {'provider': 'password', 'created_at': 'not-an-int'},
      ],
    });

    await expectLater(
      IdentityApiDataSource(
        api,
      ).getCurrentIdentities(accessToken: 'access-token'),
      throwsA(isA<ApiException>()),
    );
  });
}

final class _IdentityApiClient implements ApiClient {
  _IdentityApiClient(this.response);

  final Map<String, Object?> response;
  String? path;
  String? accessToken;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) async {
    this.path = path;
    this.accessToken = accessToken;
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) {
    throw UnimplementedError();
  }
}
