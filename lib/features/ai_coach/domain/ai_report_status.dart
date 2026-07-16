enum AiReportStatus {
  pending('pending'),
  completed('completed'),
  failed('failed');

  const AiReportStatus(this.databaseValue);

  final String databaseValue;

  static AiReportStatus fromDatabaseValue(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}

enum AiReportFailureCode {
  providerUnavailable('provider_unavailable'),
  requestFailed('request_failed'),
  responseInvalid('response_invalid'),
  cancelled('cancelled'),
  unknown('unknown');

  const AiReportFailureCode(this.databaseValue);

  final String databaseValue;

  static bool isSupported(String value) {
    return values.any((code) => code.databaseValue == value);
  }
}
