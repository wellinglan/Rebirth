enum AiGenerationMode {
  manual('manual'),
  automatic('automatic');

  const AiGenerationMode(this.databaseValue);

  final String databaseValue;

  static AiGenerationMode fromDatabaseValue(String value) {
    return values.firstWhere(
      (mode) => mode.databaseValue == value,
      orElse: () => throw ArgumentError.value(value, 'value'),
    );
  }
}
