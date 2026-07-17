import 'ai_coach_input_bundle.dart';
import 'ai_report_status.dart';

final class AiGenerationCapabilities {
  AiGenerationCapabilities({
    required this.enabled,
    required this.provider,
    required this.providerLabel,
    required this.model,
    required List<String> supportedReportTypes,
    required List<String> promptVersions,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.streaming,
    required this.responseStorageRequested,
  }) : supportedReportTypes = List.unmodifiable(supportedReportTypes),
       promptVersions = List.unmodifiable(promptVersions) {
    if (provider.trim().isEmpty || providerLabel.trim().isEmpty) {
      throw const FormatException('Invalid AI capabilities.');
    }
    if (enabled && (model == null || model!.trim().isEmpty)) {
      throw const FormatException('Enabled AI capabilities require a model.');
    }
  }

  final bool enabled;
  final String provider;
  final String providerLabel;
  final String? model;
  final List<String> supportedReportTypes;
  final List<String> promptVersions;
  final int inputSchemaVersion;
  final int outputSchemaVersion;
  final bool streaming;
  final bool responseStorageRequested;
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

  Future<AiGenerationResult> generateWeekly({
    required String requestId,
    required AiCoachInputBundle bundle,
  });
}
