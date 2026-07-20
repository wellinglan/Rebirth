import 'ai_coach_input_bundle.dart';
import 'ai_generation_report_contract.dart';
import 'ai_report_status.dart';

final class AiGenerationCapabilities {
  AiGenerationCapabilities({
    required this.enabled,
    required this.provider,
    required this.providerLabel,
    required this.model,
    required List<String> supportedReportTypes,
    required List<String> promptVersions,
    List<AiGenerationReportContract> reportContracts = const [],
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.streaming,
    required this.responseStorageRequested,
    this.durableRequestLedger = true,
    this.requestStatusRecovery = true,
    this.resultRetentionHours = 24,
    this.dedupeRetentionDays = 30,
    this.processingLeaseMinutes = 5,
    this.exactlyOnceGuaranteed = false,
  }) : supportedReportTypes = List.unmodifiable(supportedReportTypes),
       promptVersions = List.unmodifiable(promptVersions),
       reportContracts = List.unmodifiable(reportContracts) {
    if (provider.trim().isEmpty || providerLabel.trim().isEmpty) {
      throw const FormatException('Invalid AI capabilities.');
    }
    if (enabled && (model == null || model!.trim().isEmpty)) {
      throw const FormatException('Enabled AI capabilities require a model.');
    }
    if (resultRetentionHours <= 0 ||
        dedupeRetentionDays <= 0 ||
        processingLeaseMinutes <= 0 ||
        exactlyOnceGuaranteed ||
        reportContracts.map((item) => item.reportType).toSet().length !=
            reportContracts.length) {
      throw const FormatException('Invalid AI reliability capabilities.');
    }
  }

  final bool enabled;
  final String provider;
  final String providerLabel;
  final String? model;
  final List<String> supportedReportTypes;
  final List<String> promptVersions;
  final List<AiGenerationReportContract> reportContracts;
  final int inputSchemaVersion;
  final int outputSchemaVersion;
  final bool streaming;
  final bool responseStorageRequested;
  final bool durableRequestLedger;
  final bool requestStatusRecovery;
  final int resultRetentionHours;
  final int dedupeRetentionDays;
  final int processingLeaseMinutes;
  final bool exactlyOnceGuaranteed;

  AiGenerationReportContract? contractFor(String reportType) {
    for (final contract in reportContracts) {
      if (contract.reportType == reportType) return contract;
    }
    return null;
  }
}

enum AiRemoteRequestStatus {
  processing,
  completed,
  failed,
  outcomeUnknown,
  resultExpired,
  notFound,
}

final class AiRemoteRequestResult {
  const AiRemoteRequestResult({
    required this.status,
    required this.requestId,
    required this.inputHash,
    required this.reportType,
    required this.promptVersion,
    this.completedResult,
    this.failureCode,
  });

  final AiRemoteRequestStatus status;
  final String requestId;
  final String inputHash;
  final String reportType;
  final String promptVersion;
  final AiGenerationResult? completedResult;
  final AiReportFailureCode? failureCode;
}

final class AiGenerationResult {
  const AiGenerationResult({
    required this.requestId,
    required this.reportType,
    required this.promptVersion,
    required this.inputHash,
    required this.provider,
    required this.model,
    required this.outputSchemaVersion,
    required this.reportContent,
    required this.structuredOutputJson,
  });

  final String requestId;
  final String reportType;
  final String promptVersion;
  final String inputHash;
  final String provider;
  final String model;
  final int outputSchemaVersion;
  final String reportContent;
  final String structuredOutputJson;
}

final class AiGenerationException implements Exception {
  const AiGenerationException(this.code);

  final AiReportFailureCode code;

  @override
  String toString() => 'AiGenerationException(${code.databaseValue})';
}

abstract interface class AiGenerationGateway {
  Future<AiGenerationCapabilities> getCapabilities();

  Future<AiRemoteRequestResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  });

  Future<AiRemoteRequestResult> generateDaily({
    required String requestId,
    required AiCoachInputBundle bundle,
  });

  Future<AiRemoteRequestResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String reportType,
    required String promptVersion,
  });
}
