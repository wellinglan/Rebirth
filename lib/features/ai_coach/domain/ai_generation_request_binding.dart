final class AiGenerationRequestBinding {
  const AiGenerationRequestBinding({
    required this.localReportId,
    required this.requestId,
    required this.normalizedEndpoint,
    required this.cloudUserId,
    required this.inputHash,
    required this.reportType,
    required this.promptVersion,
    required this.createdAt,
  });

  final String localReportId;
  final String requestId;
  final String normalizedEndpoint;
  final String cloudUserId;
  final String inputHash;
  final String reportType;
  final String promptVersion;
  final int createdAt;
}

abstract interface class AiGenerationRequestBindingStore {
  Future<void> save(AiGenerationRequestBinding binding);

  Future<AiGenerationRequestBinding?> read(String localReportId);

  Future<List<AiGenerationRequestBinding>> readAll();

  Future<void> delete(String localReportId);
}
