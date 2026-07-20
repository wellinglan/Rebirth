enum AiReportPeriodKind {
  singleDay('single_day'),
  sevenDays('seven_days');

  const AiReportPeriodKind(this.contractValue);

  final String contractValue;

  static AiReportPeriodKind fromContractValue(String value) {
    return values.firstWhere(
      (kind) => kind.contractValue == value,
      orElse: () =>
          throw FormatException('Unknown AI report period kind: $value'),
    );
  }
}

final class AiGenerationReportContract {
  AiGenerationReportContract({
    required this.reportType,
    required List<String> promptVersions,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.periodKind,
    required List<String> supportedScopes,
  }) : promptVersions = List.unmodifiable(promptVersions),
       supportedScopes = List.unmodifiable(supportedScopes) {
    if (reportType.trim().isEmpty ||
        promptVersions.isEmpty ||
        promptVersions.any((value) => value.trim().isEmpty) ||
        inputSchemaVersion <= 0 ||
        outputSchemaVersion <= 0 ||
        supportedScopes.isEmpty ||
        promptVersions.toSet().length != promptVersions.length ||
        supportedScopes.toSet().length != supportedScopes.length) {
      throw const FormatException('Invalid AI report contract.');
    }
  }

  final String reportType;
  final List<String> promptVersions;
  final int inputSchemaVersion;
  final int outputSchemaVersion;
  final AiReportPeriodKind periodKind;
  final List<String> supportedScopes;

  bool supportsPrompt(String promptVersion) =>
      promptVersions.contains(promptVersion);
}
