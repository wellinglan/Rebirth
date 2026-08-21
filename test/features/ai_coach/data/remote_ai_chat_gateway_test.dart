import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/remote_ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

void main() {
  late _ApiClient api;
  late _SessionStore sessions;
  late RemoteAiChatGateway gateway;

  setUp(() {
    api = _ApiClient();
    sessions = _SessionStore();
    gateway = RemoteAiChatGateway(
      apiClient: api,
      sessionManager: AuthSessionManager.forTesting(sessionStore: sessions),
    );
  });

  test('chat POST sends one typed payload and decodes safe reply', () async {
    final bundle = _bundle();
    api.postResponse = _completed(
      requestId: '11111111-1111-4111-8111-111111111111',
      inputHash: bundle.inputHash,
    );

    final result = await gateway.sendTurn(
      requestId: '11111111-1111-4111-8111-111111111111',
      bundle: bundle,
    );

    expect(api.postCalls, 1);
    expect(api.lastPath, '/ai/chat/turns');
    expect(api.lastAccessToken, 'access-token');
    expect(api.lastBody?['input_hash'], bundle.inputHash);
    expect(api.lastBody?['payload'], same(bundle.canonicalPayload));
    expect(result.status, AiChatRemoteStatus.completed);
    expect(result.reply, 'A careful response.');
    expect(result.safetyCategory, AiChatSafetyCategory.caution);
  });

  test('status recovery accepts generic coach_chat ledger response', () async {
    final bundle = _bundle();
    api.getResponse = {
      ..._completed(
        requestId: '22222222-2222-4222-8222-222222222222',
        inputHash: bundle.inputHash,
      ),
      'request_type': null,
      'report_type': 'coach_chat',
      'status': 'completed',
      'report_content': 'A careful response.',
    }..remove('reply');

    final result = await gateway.getRequestStatus(
      requestId: '22222222-2222-4222-8222-222222222222',
      inputHash: bundle.inputHash,
      promptVersion: 'coach-chat-v1',
    );

    expect(api.getCalls, 1);
    expect(result.status, AiChatRemoteStatus.completed);
    expect(result.reply, 'A careful response.');
  });

  test('mismatched safety output fails closed', () async {
    final bundle = _bundle();
    api.postResponse = {
      ..._completed(
        requestId: '33333333-3333-4333-8333-333333333333',
        inputHash: bundle.inputHash,
      ),
      'safety_category': 'normal',
    };

    await expectLater(
      gateway.sendTurn(
        requestId: '33333333-3333-4333-8333-333333333333',
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
  });

  test('network loss is outcome unknown and is never auto-replayed', () async {
    api.postError = const ApiException(
      message: 'connection lost',
      isNetworkError: true,
    );

    await expectLater(
      gateway.sendTurn(
        requestId: '44444444-4444-4444-8444-444444444444',
        bundle: _bundle(),
      ),
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

AiChatInputBundle _bundle() {
  final payload = <String, Object?>{
    'schema_version': 1,
    'request_type': 'coach_chat',
    'prompt_version': 'coach-chat-v1',
    'messages': [
      {'role': 'user', 'content': 'hello'},
    ],
    'context_period': {'start_date': '2026-08-15', 'end_date': '2026-08-21'},
    'scopes': <String>[],
    'optional_context': <String, Object?>{},
    'sources': <Object?>[],
  };
  return AiChatInputBundle(
    periodStartDate: '2026-08-15',
    periodEndDate: '2026-08-21',
    scopes: const {},
    messages: const [
      AiChatPromptMessage(role: AiChatRole.user, content: 'hello'),
    ],
    sources: const [],
    canonicalPayload: payload,
    canonicalJson: '{}',
    inputHash: List.filled(64, 'a').join(),
  );
}

Map<String, Object?> _completed({
  required String requestId,
  required String inputHash,
}) => {
  'request_id': requestId,
  'request_type': 'coach_chat',
  'prompt_version': 'coach-chat-v1',
  'input_hash': inputHash,
  'provider': 'fake',
  'model': 'fake-chat',
  'output_schema_version': 1,
  'reply': 'A careful response.',
  'safety_category': 'caution',
  'structured_output': {
    'reply': 'A careful response.',
    'safety_category': 'caution',
  },
};

final class _SessionStore implements AuthSessionStore {
  AuthSession? session = const AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: AuthUser(id: 'cloud-user', displayName: 'Test'),
  );

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

final class _ApiClient implements ApiClient {
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
    return getResponse!;
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
