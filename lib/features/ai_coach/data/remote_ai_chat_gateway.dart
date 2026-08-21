import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

final class RemoteAiChatGateway implements AiChatGateway {
  const RemoteAiChatGateway({
    required this.apiClient,
    required this.sessionManager,
    this.generationTimeout = const Duration(seconds: 100),
  });

  final ApiClient apiClient;
  final AuthSessionManager sessionManager;
  final Duration generationTimeout;

  @override
  Future<AiChatRemoteResult> sendTurn({
    required String requestId,
    required AiChatInputBundle bundle,
  }) async {
    try {
      final json = await sessionManager.runAuthorized(
        (token) => apiClient.postJson(
          '/ai/chat/turns',
          accessToken: token,
          timeout: generationTimeout,
          body: {
            'request_id': requestId,
            'input_hash': bundle.inputHash,
            'payload': bundle.canonicalPayload,
          },
        ),
        canReplay: false,
      );
      return _decode(
        json,
        requestId: requestId,
        inputHash: bundle.inputHash,
        promptVersion: AiChatInputContract.promptVersion,
      );
    } on ApiException catch (error) {
      if (error.isNetworkError) {
        throw const AiGenerationException(
          AiReportFailureCode.networkOutcomeUnknown,
        );
      }
      return _mapSendFailure(
        error,
        requestId: requestId,
        inputHash: bundle.inputHash,
      );
    } on FormatException {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    } on TypeError {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    }
  }

  @override
  Future<AiChatRemoteResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String promptVersion,
  }) async {
    try {
      final json = await sessionManager.runAuthorized(
        (token) =>
            apiClient.getJson('/ai/requests/$requestId', accessToken: token),
      );
      return _decode(
        json,
        requestId: requestId,
        inputHash: inputHash,
        promptVersion: promptVersion,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.errorCode == 'not_found') {
        return AiChatRemoteResult(
          status: AiChatRemoteStatus.notFound,
          requestId: requestId,
          inputHash: inputHash,
          promptVersion: promptVersion,
        );
      }
      throw AiGenerationException(_failureCode(error));
    } on FormatException {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    } on TypeError {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    }
  }

  AiChatRemoteResult _decode(
    Map<String, Object?> json, {
    required String requestId,
    required String inputHash,
    required String promptVersion,
  }) {
    final responseRequestId = json['request_id'] as String;
    final responseInputHash = json['input_hash'] as String;
    final responsePromptVersion = json['prompt_version'] as String;
    final responseType = json['request_type'] ?? json['report_type'];
    if (responseRequestId != requestId ||
        responseInputHash != inputHash ||
        responsePromptVersion != promptVersion ||
        responseType != AiChatInputContract.requestType) {
      throw const FormatException('Mismatched AI chat response.');
    }
    final statusValue = json['status'] as String? ?? 'completed';
    if (statusValue == 'completed') {
      final structured = json['structured_output'];
      if (structured is! Map) {
        throw const FormatException('Missing AI chat structured output.');
      }
      final output = Map<String, Object?>.from(structured);
      if (output.keys.toSet().difference({
            'reply',
            'safety_category',
          }).isNotEmpty ||
          output.keys.length != 2) {
        throw const FormatException('Invalid AI chat structured output.');
      }
      final reply = ((json['reply'] ?? json['report_content']) as String)
          .trim();
      final structuredReply = (output['reply'] as String).trim();
      final safety = _safety(output['safety_category'] as String);
      final topLevelSafety = json['safety_category'];
      final provider = (json['provider'] as String?)?.trim();
      final model = (json['model'] as String?)?.trim();
      if (reply.isEmpty ||
          reply.length > 6000 ||
          structuredReply != reply ||
          provider == null ||
          provider.isEmpty ||
          model == null ||
          model.isEmpty ||
          (topLevelSafety != null &&
              _safety(topLevelSafety as String) != safety) ||
          json['output_schema_version'] != 1) {
        throw const FormatException('Invalid AI chat result.');
      }
      return AiChatRemoteResult(
        status: AiChatRemoteStatus.completed,
        requestId: requestId,
        inputHash: inputHash,
        promptVersion: promptVersion,
        reply: reply,
        safetyCategory: safety,
        provider: provider,
        model: model,
      );
    }
    final status = switch (statusValue) {
      'processing' => AiChatRemoteStatus.processing,
      'failed' => AiChatRemoteStatus.failed,
      'outcome_unknown' => AiChatRemoteStatus.outcomeUnknown,
      'result_expired' => AiChatRemoteStatus.resultExpired,
      _ => throw const FormatException('Unknown AI chat request status.'),
    };
    return AiChatRemoteResult(
      status: status,
      requestId: requestId,
      inputHash: inputHash,
      promptVersion: promptVersion,
      failureCode: status == AiChatRemoteStatus.failed
          ? _codeFromValue(json['error_code'] as String?)
          : null,
    );
  }

  AiChatRemoteResult _mapSendFailure(
    ApiException error, {
    required String requestId,
    required String inputHash,
  }) {
    final code = _failureCode(error);
    final status = switch (code) {
      AiReportFailureCode.outcomeUnknown => AiChatRemoteStatus.outcomeUnknown,
      AiReportFailureCode.resultExpired => AiChatRemoteStatus.resultExpired,
      AiReportFailureCode.aiDisabled ||
      AiReportFailureCode.usageLimitReached ||
      AiReportFailureCode.providerAuthenticationFailed ||
      AiReportFailureCode.providerAuthFailed ||
      AiReportFailureCode.providerRateLimited ||
      AiReportFailureCode.providerTimeout ||
      AiReportFailureCode.providerUnavailable ||
      AiReportFailureCode.providerRefused ||
      AiReportFailureCode.responseInvalid ||
      AiReportFailureCode.requestFailed => AiChatRemoteStatus.failed,
      _ => throw AiGenerationException(code),
    };
    return AiChatRemoteResult(
      status: status,
      requestId: requestId,
      inputHash: inputHash,
      promptVersion: AiChatInputContract.promptVersion,
      failureCode: status == AiChatRemoteStatus.failed ? code : null,
    );
  }

  AiChatSafetyCategory _safety(String value) => switch (value) {
    'normal' => AiChatSafetyCategory.normal,
    'caution' => AiChatSafetyCategory.caution,
    'high_risk' => AiChatSafetyCategory.highRisk,
    _ => throw const FormatException('Unknown AI chat safety category.'),
  };

  AiReportFailureCode _codeFromValue(String? value) {
    if (value == null) return AiReportFailureCode.requestFailed;
    return AiReportFailureCode.values.firstWhere(
      (code) => code.databaseValue == value,
      orElse: () => AiReportFailureCode.requestFailed,
    );
  }

  AiReportFailureCode _failureCode(ApiException error) {
    final serverCode = error.errorCode;
    for (final code in AiReportFailureCode.values) {
      if (code.databaseValue == serverCode) return code;
    }
    if (error.isUnauthorized) return AiReportFailureCode.authenticationRequired;
    if (error.isNetworkError) return AiReportFailureCode.providerUnavailable;
    return AiReportFailureCode.requestFailed;
  }
}
