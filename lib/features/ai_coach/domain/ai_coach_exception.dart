sealed class AiCoachException implements Exception {
  const AiCoachException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class AiConsentRequiredException extends AiCoachException {
  const AiConsentRequiredException()
    : super('AI data authorization is required for this local operation.');
}

final class EmptyAiDataSelectionException extends AiCoachException {
  const EmptyAiDataSelectionException()
    : super('At least one AI data scope must be selected.');
}

final class UnsupportedAiReportTypeException extends AiCoachException {
  UnsupportedAiReportTypeException(String reportType)
    : super('AI report type "$reportType" is not supported.');
}

final class UnsupportedAiDataScopeException extends AiCoachException {
  UnsupportedAiDataScopeException(String scope)
    : super('AI data scope "$scope" is not supported.');
}

final class InvalidAiInputException extends AiCoachException {
  const InvalidAiInputException([
    super.message = 'The AI input contract is invalid.',
  ]);
}

final class AiReportNotFoundException extends AiCoachException {
  AiReportNotFoundException(String reportId)
    : super('No active AI report exists with ID $reportId.');
}

final class InvalidAiReportTransitionException extends AiCoachException {
  InvalidAiReportTransitionException({
    required String from,
    required String to,
  }) : super('AI report cannot transition from $from to $to.');
}
