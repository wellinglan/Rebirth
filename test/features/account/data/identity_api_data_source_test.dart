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
        {'provider': 'wechat', 'created_at': 400, 'last_used_at': null},
      ],
    });

    final identities = await IdentityApiDataSource(
      api,
    ).getCurrentIdentities(accessToken: 'access-token');

    expect(api.path, '/auth/identities');
    expect(api.accessToken, 'access-token');
    expect(identities, hasLength(3));
    expect(identities.first.provider, AuthIdentityProvider.password);
    expect(identities.first.lastUsedAt, 200);
    expect(identities[1].provider, AuthIdentityProvider.developer);
    expect(identities.last.provider, AuthIdentityProvider.wechat);
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

  test(
    'starts WeChat binding with bearer token and no identity data',
    () async {
      final api = _IdentityApiClient(
        const {},
        postResponse: {
          'status': 'provider_unavailable',
          'provider': 'wechat',
          'requires_reauthentication': true,
          'message': 'WeChat binding is not configured in this release.',
        },
      );

      final result = await IdentityApiDataSource(
        api,
      ).startWechatBinding(accessToken: 'access-token');

      expect(api.path, '/auth/identities/wechat/bind/start');
      expect(api.accessToken, 'access-token');
      expect(api.body, isEmpty);
      expect(result.provider, AuthIdentityProvider.wechat);
      expect(result.requiresReauthentication, isTrue);
      expect(result.isProviderUnavailable, isTrue);
    },
  );

  test('rejects malformed WeChat binding responses', () async {
    final api = _IdentityApiClient(
      const {},
      postResponse: {'status': 'provider_unavailable'},
    );

    await expectLater(
      IdentityApiDataSource(
        api,
      ).startWechatBinding(accessToken: 'access-token'),
      throwsA(isA<ApiException>()),
    );
  });
}

final class _IdentityApiClient implements ApiClient {
  _IdentityApiClient(this.response, {this.postResponse});

  final Map<String, Object?> response;
  final Map<String, Object?>? postResponse;
  String? path;
  String? accessToken;
  Map<String, Object?>? body;

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
  }) async {
    this.path = path;
    this.body = body;
    this.accessToken = accessToken;
    return postResponse ?? response;
  }
}
