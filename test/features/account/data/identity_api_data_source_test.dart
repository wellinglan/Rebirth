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
    'reauthenticates in memory and starts binding with one-time proof',
    () async {
      final api = _IdentityApiClient(
        const {},
        postResponses: [
          {
            'status': 'proof_created',
            'purpose': 'wechat_bind',
            'method': 'password',
            'proof': 'one-time-proof',
            'expires_at': 5000,
          },
          {
            'status': 'provider_unavailable',
            'provider': 'wechat',
            'requires_reauthentication': true,
            'message': 'WeChat binding is not configured in this release.',
          },
        ],
      );

      final dataSource = IdentityApiDataSource(api);
      final proof = await dataSource.reauthenticate(
        accessToken: 'access-token',
        method: ReauthenticationMethod.password,
        credential: 'private password',
      );
      final result = await dataSource.startWechatBinding(
        accessToken: 'access-token',
        reauthenticationProof: proof.value,
      );

      expect(api.path, '/auth/identities/wechat/bind/start');
      expect(api.accessToken, 'access-token');
      expect(api.bodies.first, {
        'password': 'private password',
        'purpose': 'wechat_bind',
      });
      expect(api.body, {'reauthentication_proof': 'one-time-proof'});
      expect(proof.expiresAt, 5000);
      expect(result.provider, AuthIdentityProvider.wechat);
      expect(result.requiresReauthentication, isTrue);
      expect(result.isProviderUnavailable, isTrue);
    },
  );

  test('rejects malformed WeChat binding responses', () async {
    final api = _IdentityApiClient(
      const {},
      postResponses: [
        {'status': 'provider_unavailable'},
      ],
    );

    await expectLater(
      IdentityApiDataSource(api).startWechatBinding(
        accessToken: 'access-token',
        reauthenticationProof: 'proof',
      ),
      throwsA(isA<ApiException>()),
    );
  });
}

final class _IdentityApiClient implements ApiClient {
  _IdentityApiClient(this.response, {this.postResponses = const []});

  final Map<String, Object?> response;
  final List<Map<String, Object?>> postResponses;
  String? path;
  String? accessToken;
  Map<String, Object?>? body;
  final List<Map<String, Object?>> bodies = [];
  int postCalls = 0;

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
    bodies.add(body);
    this.accessToken = accessToken;
    if (postCalls < postResponses.length) {
      return postResponses[postCalls++];
    }
    return response;
  }
}
