import 'dart:convert';

import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_report_contract.dart';
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
  Future<AiRemoteRequestResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    return _generate(
      path: '/ai/reports/weekly/generate',
      requestId: requestId,
      bundle: bundle,
    );
  }

  @override
  Future<AiRemoteRequestResult> generateDaily({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    return _generate(
      path: '/ai/reports/daily/generate',
      requestId: requestId,
      bundle: bundle,
    );
  }

  Future<AiRemoteRequestResult> _generate({
    required String path,
    required String requestId,
    required AiCoachInputBundle bundle,
  }) async {
    final token = await _accessToken();
    try {
      final json = await apiClient.postJson(
        path,
        accessToken: token,
        timeout: generationTimeout,
        body: {
          'request_id': requestId,
          'input_hash': bundle.inputHash,
          'payload': bundle.canonicalPayload,
        },
      );
      return _decodeRemoteResult(
        json,
        requestId: requestId,
        inputHash: bundle.inputHash,
        reportType: bundle.reportType.databaseValue,
        promptVersion: bundle.promptVersion,
      );
    } on ApiException catch (error) {
      return _mapGenerateError(error, requestId: requestId, bundle: bundle);
    } on FormatException {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    } on TypeError {
      throw const AiGenerationException(AiReportFailureCode.responseInvalid);
    }
  }

  @override
  Future<AiRemoteRequestResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  }) async {
    final token = await _accessToken();
    try {
      final json = await apiClient.getJson(
        '/ai/requests/$requestId',
        accessToken: token,
      );
      return _decodeRemoteResult(
        json,
        requestId: requestId,
        inputHash: inputHash,
        reportType: reportType,
        promptVersion: promptVersion,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.errorCode == 'not_found') {
        return AiRemoteRequestResult(
          status: AiRemoteRequestStatus.notFound,
          requestId: requestId,
          inputHash: inputHash,
          reportType: reportType,
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
      reportContracts: _decodeReportContracts(json['report_contracts']),
      inputSchemaVersion: json['input_schema_version'] as int,
      outputSchemaVersion: json['output_schema_version'] as int,
      streaming: json['streaming'] as bool,
      responseStorageRequested: json['response_storage_requested'] as bool,
      durableRequestLedger: json['durable_request_ledger'] as bool,
      requestStatusRecovery: json['request_status_recovery'] as bool,
      resultRetentionHours: json['result_retention_hours'] as int,
      dedupeRetentionDays: json['dedupe_retention_days'] as int,
      processingLeaseMinutes: json['processing_lease_minutes'] as int,
      exactlyOnceGuaranteed: json['exactly_once_guaranteed'] as bool,
    );
  }

  AiRemoteRequestResult _decodeRemoteResult(
    Map<String, Object?> json, {
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  }) {
    final responseRequestId = json['request_id'] as String;
    final responseHash = json['input_hash'] as String;
    final responseReportType = json['report_type'] as String;
    final responsePromptVersion = json['prompt_version'] as String;
    if (responseRequestId != requestId ||
        responseHash != inputHash ||
        responseReportType != reportType ||
        responsePromptVersion != promptVersion) {
      throw const FormatException('Mismatched AI request status response.');
    }
    final status = json['status'] as String? ?? 'completed';
    if (status == 'completed') {
      final completed = _decodeResult(
        json,
        requestId: requestId,
        inputHash: inputHash,
        reportType: reportType,
        promptVersion: promptVersion,
      );
      return AiRemoteRequestResult(
        status: AiRemoteRequestStatus.completed,
        requestId: requestId,
        inputHash: inputHash,
        reportType: reportType,
        promptVersion: promptVersion,
        completedResult: completed,
      );
    }
    final mappedStatus = switch (status) {
      'processing' => AiRemoteRequestStatus.processing,
      'failed' => AiRemoteRequestStatus.failed,
      'outcome_unknown' => AiRemoteRequestStatus.outcomeUnknown,
      'result_expired' => AiRemoteRequestStatus.resultExpired,
      _ => throw const FormatException('Unknown AI request status.'),
    };
    return AiRemoteRequestResult(
      status: mappedStatus,
      requestId: requestId,
      inputHash: inputHash,
      reportType: reportType,
      promptVersion: promptVersion,
      failureCode: status == 'failed'
          ? _codeFromValue(json['error_code'] as String?)
          : null,
    );
  }

  AiGenerationResult _decodeResult(
    Map<String, Object?> json, {
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  }) {
    final responseRequestId = json['request_id'] as String;
    final responseReportType = json['report_type'] as String;
    final responsePromptVersion = json['prompt_version'] as String;
    final responseInputHash = json['input_hash'] as String;
    final content = (json['report_content'] as String).trim();
    final structured = json['structured_output'];
    if (responseRequestId != requestId ||
        responseReportType != reportType ||
        responsePromptVersion != promptVersion ||
        responseInputHash != inputHash ||
        content.isEmpty ||
        structured is! Map) {
      throw const FormatException('Mismatched AI generation response.');
    }
    final output = Map<String, Object?>.from(structured);
    _validateStructuredOutput(output, reportType: reportType);
    final outputSchemaVersion = json['output_schema_version'] as int;
    if (outputSchemaVersion != 1) {
      throw const FormatException('Unsupported AI output schema version.');
    }
    return AiGenerationResult(
      requestId: responseRequestId,
      reportType: responseReportType,
      promptVersion: responsePromptVersion,
      inputHash: responseInputHash,
      provider: json['provider'] as String,
      model: json['model'] as String,
      outputSchemaVersion: outputSchemaVersion,
      reportContent: content,
      structuredOutputJson: jsonEncode(output),
    );
  }

  AiRemoteRequestResult _mapGenerateError(
    ApiException error, {
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    final code = _failureCode(error);
    if (error.isNetworkError) {
      throw const AiGenerationException(
        AiReportFailureCode.networkOutcomeUnknown,
      );
    }
    final status = switch (code) {
      AiReportFailureCode.outcomeUnknown =>
        AiRemoteRequestStatus.outcomeUnknown,
      AiReportFailureCode.resultExpired => AiRemoteRequestStatus.resultExpired,
      AiReportFailureCode.providerAuthenticationFailed ||
      AiReportFailureCode.providerRateLimited ||
      AiReportFailureCode.providerTimeout ||
      AiReportFailureCode.providerUnavailable ||
      AiReportFailureCode.providerRefused ||
      AiReportFailureCode.responseInvalid ||
      AiReportFailureCode.requestFailed => AiRemoteRequestStatus.failed,
      _ => throw AiGenerationException(code),
    };
    return AiRemoteRequestResult(
      status: status,
      requestId: requestId,
      inputHash: bundle.inputHash,
      reportType: bundle.reportType.databaseValue,
      promptVersion: bundle.promptVersion,
      failureCode: status == AiRemoteRequestStatus.failed ? code : null,
    );
  }

  AiReportFailureCode _codeFromValue(String? value) {
    if (value == null) return AiReportFailureCode.requestFailed;
    return AiReportFailureCode.values.firstWhere(
      (code) => code.databaseValue == value,
      orElse: () => AiReportFailureCode.requestFailed,
    );
  }

  void _validateStructuredOutput(
    Map<String, Object?> value, {
    required String reportType,
  }) {
    if (reportType == 'daily_insight') {
      _validateDailyStructuredOutput(value);
      return;
    }
    if (reportType != 'weekly_report') {
      throw const FormatException('Unsupported AI report output.');
    }
    _validateWeeklyStructuredOutput(value);
  }

  void _validateWeeklyStructuredOutput(Map<String, Object?> value) {
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

  void _validateDailyStructuredOutput(Map<String, Object?> value) {
    const keys = {
      'title',
      'summary',
      'observations',
      'possible_factors',
      'tomorrow_adjustments',
      'data_limitations',
    };
    if (!_hasExactKeys(value.keys, keys) ||
        value['title'] is! String ||
        (value['title'] as String).trim().isEmpty ||
        value['summary'] is! String ||
        (value['summary'] as String).trim().isEmpty) {
      throw const FormatException('Invalid Daily Insight output.');
    }
    final observations = value['observations'];
    final factors = value['possible_factors'];
    final adjustments = value['tomorrow_adjustments'];
    final limitations = value['data_limitations'];
    if (observations is! List ||
        observations.length > 4 ||
        factors is! List ||
        factors.length > 3 ||
        adjustments is! List ||
        adjustments.length > 3 ||
        limitations is! List ||
        !limitations.every((item) => item is String)) {
      throw const FormatException('Invalid Daily Insight output.');
    }
    for (final item in observations) {
      if (item is! Map ||
          !_hasExactKeys(item.keys, {'statement', 'evidence'}) ||
          item['statement'] is! String ||
          (item['statement'] as String).trim().isEmpty ||
          item['evidence'] is! List ||
          !(item['evidence'] as List).every((value) => value is String)) {
        throw const FormatException('Invalid Daily Insight observation.');
      }
    }
    for (final item in factors) {
      if (item is! Map ||
          !_hasExactKeys(item.keys, {'factor', 'caveat'}) ||
          item['factor'] is! String ||
          (item['factor'] as String).trim().isEmpty ||
          item['caveat'] is! String ||
          (item['caveat'] as String).trim().isEmpty) {
        throw const FormatException('Invalid Daily Insight factor.');
      }
    }
    for (final item in adjustments) {
      if (item is! Map ||
          !_hasExactKeys(item.keys, {'action', 'reason'}) ||
          item['action'] is! String ||
          (item['action'] as String).trim().isEmpty ||
          item['reason'] is! String ||
          (item['reason'] as String).trim().isEmpty) {
        throw const FormatException('Invalid Daily Insight adjustment.');
      }
    }
  }

  bool _hasExactKeys(Iterable<Object?> actual, Set<String> expected) {
    final keys = actual.toSet();
    return keys.length == expected.length && keys.containsAll(expected);
  }

  List<AiGenerationReportContract> _decodeReportContracts(Object? value) {
    if (value is! List) {
      throw const FormatException('Missing AI report contracts.');
    }
    return value
        .map((item) {
          if (item is! Map ||
              !_hasExactKeys(item.keys, {
                'report_type',
                'prompt_versions',
                'input_schema_version',
                'output_schema_version',
                'period_kind',
                'supported_scopes',
              })) {
            throw const FormatException('Invalid AI report contract.');
          }
          return AiGenerationReportContract(
            reportType: item['report_type'] as String,
            promptVersions: _stringList(item['prompt_versions']),
            inputSchemaVersion: item['input_schema_version'] as int,
            outputSchemaVersion: item['output_schema_version'] as int,
            periodKind: AiReportPeriodKind.fromContractValue(
              item['period_kind'] as String,
            ),
            supportedScopes: _stringList(item['supported_scopes']),
          );
        })
        .toList(growable: false);
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
