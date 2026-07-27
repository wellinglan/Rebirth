import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/legacy_ownership_verification_api_data_source.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';

void main() {
  const evidence = LegacyOwnershipEvidence(
    tableName: 'goals',
    recordId: '10000000-0000-4000-8000-000000000001',
    serverVersion: 7,
    metadataFingerprint:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );

  test('sends metadata-only request and parses verified response', () async {
    final client = _FakeApiClient(
      responses: [
        {
          'status': 'verified',
          'verified_count': 1,
          'rejected_count': 0,
          'unknown_count': 0,
          'reason': 'all_evidence_matches_current_user',
        },
      ],
    );
    final dataSource = LegacyOwnershipVerificationApiDataSource(client);

    final result = await dataSource.verify(
      evidence: const [evidence],
      accessToken: 'access-token',
    );

    expect(result.outcome, LegacyOwnershipVerificationOutcome.verified);
    expect(client.lastPath, '/sync/verify-ownership');
    expect(client.lastToken, 'access-token');
    expect(client.lastBody, {
      'evidence': [
        {
          'table': 'goals',
          'id': evidence.recordId,
          'server_version': 7,
          'metadata_fingerprint': evidence.metadataFingerprint,
        },
      ],
    });
    expect(client.lastBody.toString(), isNot(contains('user_id')));
    expect(client.lastBody.toString(), isNot(contains('payload')));
  });

  test('parses unknown and rejected responses', () async {
    final client = _FakeApiClient(
      responses: [
        {
          'status': 'unknown',
          'verified_count': 0,
          'rejected_count': 0,
          'unknown_count': 1,
          'reason': 'remote_record_missing',
        },
        {
          'status': 'rejected',
          'verified_count': 0,
          'rejected_count': 1,
          'unknown_count': 0,
          'reason': 'metadata_mismatch_or_other_owner',
        },
      ],
    );
    final dataSource = LegacyOwnershipVerificationApiDataSource(client);

    final unknown = await dataSource.verify(
      evidence: const [evidence],
      accessToken: 'token',
    );
    final rejected = await dataSource.verify(
      evidence: const [evidence],
      accessToken: 'token',
    );

    expect(unknown.outcome, LegacyOwnershipVerificationOutcome.unknown);
    expect(rejected.outcome, LegacyOwnershipVerificationOutcome.rejected);
  });

  test(
    'network failure can be retried without changing request semantics',
    () async {
      final client = _FakeApiClient(
        errors: [const ApiException(message: 'offline', isNetworkError: true)],
        responses: [
          {
            'status': 'verified',
            'verified_count': 1,
            'rejected_count': 0,
            'unknown_count': 0,
            'reason': 'all_evidence_matches_current_user',
          },
        ],
      );
      final dataSource = LegacyOwnershipVerificationApiDataSource(client);

      await expectLater(
        dataSource.verify(evidence: const [evidence], accessToken: 'token'),
        throwsA(isA<ApiException>()),
      );
      final retried = await dataSource.verify(
        evidence: const [evidence],
        accessToken: 'token',
      );

      expect(retried.isVerified, isTrue);
      expect(client.calls, 2);
    },
  );
}

final class _FakeApiClient implements ApiClient {
  _FakeApiClient({List<Map<String, Object?>>? responses, List<Object>? errors})
    : responses = [...?responses],
      errors = [...?errors];

  final List<Map<String, Object?>> responses;
  final List<Object> errors;
  int calls = 0;
  String? lastPath;
  String? lastToken;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) async {
    calls += 1;
    lastPath = path;
    lastToken = accessToken;
    lastBody = body;
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return responses.removeAt(0);
  }
}
