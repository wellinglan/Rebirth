const int metricDescriptionMaxLength = 80;

String? normalizeMetricDescription(
  String? value, {
  String name = 'description',
}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > metricDescriptionMaxLength) {
    throw ArgumentError.value(
      value,
      name,
      'Description must not exceed $metricDescriptionMaxLength characters.',
    );
  }
  return normalized;
}
