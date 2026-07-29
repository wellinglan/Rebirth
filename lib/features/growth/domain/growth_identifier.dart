final class GrowthDimensionId implements Comparable<GrowthDimensionId> {
  GrowthDimensionId(String value)
    : value = _validateGrowthIdentifier(value, 'dimensionId');

  final String value;

  @override
  int compareTo(GrowthDimensionId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is GrowthDimensionId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class GrowthMetricId implements Comparable<GrowthMetricId> {
  GrowthMetricId(String value)
    : value = _validateGrowthIdentifier(value, 'metricId');

  final String value;

  @override
  int compareTo(GrowthMetricId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is GrowthMetricId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final RegExp _growthIdentifierPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
);

String _validateGrowthIdentifier(String value, String name) {
  if (value.trim() != value || !_growthIdentifierPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a stable lowercase namespaced identifier.',
    );
  }
  return value;
}
