import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/remote_ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeApiClient api;
  late FakeSessionStore sessions;
  late RemoteAiGenerationGateway gateway;

  setUp(() {
    api = FakeApiClient();
    sessions = FakeSessionStore(session: _session());
    gateway = RemoteAiGenerationGateway(
      apiClient: api,
      sessionStore: sessions,
    );
  });

  test('capabilities require a current Rebirth session', () async {
    sessions.session = null;
    await expectLater(
      gateway.getCapabilities(),
      throwsA(
        isA<AiGenerationException>().having(
          (error) => error.code,
          'code',
          AiReportFailureCode.authenticationRequired,
        ),
      ),
    );
    expect(api.getCalls, 0);
  });

  test('enabled capabilities are decoded without provider secrets', () async {
    api.getResponse = _capabilities();
    final result = await gateway.getCapabilities();
    expect(result.enabled, isTrue);
    expect(result.provider, 'fake');
    expect(result.model, 'deterministic-test-provider');
    expect(api.lastAccessToken, 'access-token');
    expect(api.lastPath, '/ai/capabilities');
  });

  test('generation sends typed payload and hash exactly once', () async {
    final bundle = buildAiBundle();
    api.postResponse = _generation(bundle, requestId: 'local-report-id');
    final result = await gateway.generateWeekly(
      requestId: 'local-report-id',
      bundle: bundle,
    );

    expect(api.postCalls, 1);
    expect(api.lastPath, '/ai/reports/weekly/generate');
    expect(api.lastBody?['request_id'], 'local-report-id');
    expect(api.lastBody?['input_hash'], bundle.inputHash);
    expect(api.lastBody?['payload'], same(bundle.canonicalPayload));
    expect(api.lastBody, isNot(contains('canonical_json')));
    expect(result.completedResult?.provider, 'fake');
    expect(
      result.completedResult?.structuredOutputJson,
      contains('data_limitations'),
    );
  });

  for (final mismatch in ['request', 'hash', 'prompt', 'report']) {
    test('$mismatch mismatch rejects the response', () async {
      final bundle = buildAiBundle();
      final response = _generation(bundle, requestId: 'local-report-id');
      switch (mismatch) {
        case 'request':
          response['request_id'] = 'other';
        case 'hash':
          response['input_hash'] = '0' * 64;
        case 'prompt':
          response['prompt_version'] = 'weekly-report-v2';
        case 'report':
          response['report_type'] = 'daily_insight';
      }
      api.postResponse = response;
      await expectLater(
        gateway.generateWeekly(
          requestId: 'local-report-id',
          bundle: bundle,
        ),
        throwsA(
          isA<AiGenerationException>().having(
            (error) => error.code,
            'code',
            AiReportFailureCode.responseInvalid,
          ),
        ),
      );
      expect(api.postCalls, 1);
    });
  }

  test('empty report and invalid structured output are rejected', () async {
    final bundle = buildAiBundle();
    final response = _generation(bundle, requestId: 'local-report-id');
    response['report_content'] = '   ';
    api.postResponse = response;
    await expectLater(
      gateway.generateWeekly(requestId: 'local-report-id', bundle: bundle),
      throwsA(isA<AiGenerationException>()),
    );

    response['report_content'] = '# report';
    response['structured_output'] = {'title': 'missing fields'};
    await expectLater(
      gateway.generateWeekly(requestId: 'local-report-id', bundle: bundle),
      throwsA(isA<AiGenerationException>()),
    );
    expect(api.postCalls, 2);
  });

  test('unknown server errors map to one controlled failure', () async {
    api.postError = const ApiException(
      message: 'raw body omitted',
      statusCode: 500,
      errorCode: 'future_unknown_code',
    );
    final result = await gateway.generateWeekly(
      requestId: 'local-report-id',
      bundle: buildAiBundle(),
    );
    expect(result.status, AiRemoteRequestStatus.failed);
    expect(result.failureCode, AiReportFailureCode.requestFailed);
    expect(api.postCalls, 1);
  });

  test('status GET validates identity and decodes completed recovery', () async {
    final bundle = buildAiBundle();
    api.getResponse = {
      ..._generation(bundle, requestId: 'local-report-id'),
      'status': 'completed',
      'created_at': 1,
    };
    final result = await gateway.getRequestStatus(
      requestId: 'local-report-id',
      inputHash: bundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
    );
    expect(result.status, AiRemoteRequestStatus.completed);
    expect(result.completedResult?.reportContent, startsWith('#'));
    expect(api.lastPath, '/ai/requests/local-report-id');

    api.getResponse!['input_hash'] = '0' * 64;
    await expectLater(
      gateway.getRequestStatus(
        requestId: 'local-report-id',
        inputHash: bundle.inputHash,
        reportType: 'weekly_report',
        promptVersion: bundle.promptVersion,
      ),
      throwsA(
        isA<AiGenerationException>().having(
          (error) => error.code,
          'code',
          AiReportFailureCode.responseInvalid,
        ),
      ),
    );
  });

  test('status not found is safe and POST network loss is outcome unknown', () async {
    final bundle = buildAiBundle();
    api.getError = const ApiException(
      message: 'not found',
      statusCode: 404,
      errorCode: 'not_found',
    );
    final missing = await gateway.getRequestStatus(
      requestId: 'local-report-id',
      inputHash: bundle.inputHash,
      reportType: 'weekly_report',
      promptVersion: bundle.promptVersion,
    );
    expect(missing.status, AiRemoteRequestStatus.notFound);

    api.postError = const ApiException(
      message: 'connection lost',
      isNetworkError: true,
    );
    await expectLater(
      gateway.generateWeekly(requestId: 'local-report-id', bundle: bundle),
      throwsA(
        isA<AiGenerationException>().having(
          (error) => error.code,
          'code',
          AiReportFailureCode.networkOutcomeUnknown,
        ),
      ),
    );
    expect(api.postCalls, 1);
  });
}

Map<String, Object?> _capabilities() => {
  'enabled': true,
  'provider': 'fake',
  'provider_label': 'Development Fake',
  'model': 'deterministic-test-provider',
  'supported_report_types': ['weekly_report'],
  'prompt_versions': ['weekly-report-v1'],
  'input_schema_version': 1,
  'output_schema_version': 1,
  'streaming': false,
  'response_storage_requested': false,
  'durable_request_ledger': true,
  'request_status_recovery': true,
  'result_retention_hours': 24,
  'dedupe_retention_days': 30,
  'processing_lease_minutes': 5,
  'exactly_once_guaranteed': false,
};

Map<String, Object?> _generation(
  AiCoachInputBundle bundle, {
  required String requestId,
}) => {
  'request_id': requestId,
  'report_type': 'weekly_report',
  'prompt_version': 'weekly-report-v1',
  'input_hash': bundle.inputHash,
  'provider': 'fake',
  'model': 'deterministic-test-provider',
  'output_schema_version': 1,
  'report_content': '# 开发测试每周回顾',
  'structured_output': {
    'title': '开发测试每周回顾',
    'summary': '测试摘要',
    'observations': [],
    'suggestions': [],
    'data_limitations': [],
  },
};

AuthSession _session() => const AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  user: AuthUser(id: 'cloud-user', displayName: 'Test'),
);

final class FakeSessionStore implements AuthSessionStore {
  FakeSessionStore({this.session});

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

final class FakeApiClient implements ApiClient {
  Map<String, Object?>? getResponse;
  Map<String, Object?>? postResponse;
  Object? getError;
  Object? postError;
  int getCalls = 0;
  int postCalls = 0;
  String? lastPath;
  String? lastAccessToken;
  Map<String, Object?>? lastBody;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    String? accessToken,
    Duration? timeout,
  }) async {
    getCalls += 1;
    lastPath = path;
    lastAccessToken = accessToken;
    if (getError case final error?) throw error;
    return getResponse ?? _capabilities();
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? accessToken,
    Duration? timeout,
  }) async {
    postCalls += 1;
    lastPath = path;
    lastAccessToken = accessToken;
    lastBody = body;
    if (postError case final error?) throw error;
    return postResponse!;
  }
}
