enum AiReportSensitivity {
  standard('standard'),
  high('high'),
  restricted('restricted');

  const AiReportSensitivity(this.databaseValue);

  final String databaseValue;

  static AiReportSensitivity fromDatabaseValue(String value) {
    return values.firstWhere(
      (item) => item.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}

enum AiReportQuality {
  unknown('unknown'),
  unreviewed('unreviewed'),
  validated('validated');

  const AiReportQuality(this.databaseValue);

  final String databaseValue;

  static AiReportQuality fromDatabaseValue(String value) {
    return values.firstWhere(
      (item) => item.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}
