import 'dart:convert';

import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

final class RemoteAiGenerationGateway implements AiGenerationGateway {
  const RemoteAiGenerationGateway({
    required this.apiClient,
    required this.sessionStore,
    this.generationTimeout = const Duration(seconds: 100),
  });

  final ApiClient apiClient;
  final AuthSessionStore sessionStore;
  final Duration generationTimeout;

  @override
  Future<AiGenerationCapabilities> getCapabilities() async {
    final token = await _accessToken();
    try {
      final json = await apiClient.getJson(
        '/ai/capabilities',
        accessToken: token,
      );
      return _decodeCapabilities(json);
    } on ApiException catch (error) {
      throw AiGenerationException(_failureCode(error));
    } on FormatException {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    } on TypeError {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    }
  }

  @override
  Future<AiGenerationResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) async {
    final token = await _accessToken();
    try {
      final json = await apiClient.postJson(
        '/ai/reports/weekly/generate',
        accessToken: token,
        timeout: generationTimeout,
        body: {
          'request_id': requestId,
          'input_hash': bundle.inputHash,
          'payload': bundle.canonicalPayload,
        },
      );
      return _decodeResult(json, requestId: requestId, bundle: bundle);
    } on ApiException catch (error) {
      throw AiGenerationException(_failureCode(error));
    } on FormatException {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    } on TypeError {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    }
  }

  Future<String> _accessToken() async {
    final session = await sessionStore.read();
    if (session == null || session.accessToken.isEmpty) {
      throw const AiGenerationException(
        AiReportFailureCode.authenticationRequired,
      );
    }
    return session.accessToken;
  }

  AiGenerationCapabilities _decodeCapabilities(Map<String, Object?> json) {
    return AiGenerationCapabilities(
      enabled: json['enabled'] as bool,
      provider: json['provider'] as String,
      providerLabel: json['provider_label'] as String,
      model: json['model'] as String?,
      supportedReportTypes: _stringList(json['supported_report_types']),
      promptVersions: _stringList(json['prompt_versions']),
      inputSchemaVersion: json['input_schema_version'] as int,
      outputSchemaVersion: json['output_schema_version'] as int,
      streaming: json['streaming'] as bool,
      responseStorageRequested: json['response_storage_requested'] as bool,
    );
  }

  AiGenerationResult _decodeResult(
    Map<String, Object?> json, {
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    final responseRequestId = json['request_id'] as String;
    final reportType = json['report_type'] as String;
    final promptVersion = json['prompt_version'] as String;
    final inputHash = json['input_hash'] as String;
    final content = (json['report_content'] as String).trim();
    final structured = json['structured_output'];
    if (responseRequestId != requestId ||
        reportType != bundle.reportType.databaseValue ||
        promptVersion != bundle.promptVersion ||
        inputHash != bundle.inputHash ||
        content.isEmpty ||
        structured is! Map) {
      throw const FormatException('Mismatched AI generation response.');
    }
    final output = Map<String, Object?>.from(structured);
    _validateStructuredOutput(output);
    return AiGenerationResult(
      requestId: responseRequestId,
      reportType: reportType,
      promptVersion: promptVersion,
      inputHash: inputHash,
      provider: json['provider'] as String,
      model: json['model'] as String,
      outputSchemaVersion: json['output_schema_version'] as int,
      reportContent: content,
      structuredOutputJson: jsonEncode(output),
    );
  }

  void _validateStructuredOutput(Map<String, Object?> value) {
    const keys = {
      'title',
      'summary',
      'observations',
      'suggestions',
      'data_limitations',
    };
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        !value.keys.toSet().containsAll(keys) ||
        (value['title'] as String).trim().isEmpty ||
        (value['summary'] as String).trim().isEmpty) {
      throw const FormatException('Invalid structured output.');
    }
    final observations = value['observations'];
    final suggestions = value['suggestions'];
    final limitations = value['data_limitations'];
    if (observations is! List ||
        observations.length > 5 ||
        suggestions is! List ||
        suggestions.length > 3 ||
        limitations is! List ||
        !limitations.every((item) => item is String)) {
      throw const FormatException('Invalid structured output.');
    }
    for (final item in observations) {
      if (item is! Map ||
          item.keys.toSet().difference({'statement', 'evidence'}).isNotEmpty ||
          item['statement'] is! String ||
          item['evidence'] is! List ||
          !(item['evidence'] as List).every((value) => value is String)) {
        throw const FormatException('Invalid structured output.');
      }
    }
    for (final item in suggestions) {
      if (item is! Map ||
          item.keys.toSet().difference({'action', 'reason'}).isNotEmpty ||
          item['action'] is! String ||
          item['reason'] is! String) {
        throw const FormatException('Invalid structured output.');
      }
    }
  }

  List<String> _stringList(Object? value) {
    if (value is! List || !value.every((item) => item is String)) {
      throw const FormatException('Invalid string list.');
    }
    return value.cast<String>();
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
