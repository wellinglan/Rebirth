final class GrowthDataIntegrityException implements Exception {
  const GrowthDataIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'Growth data integrity error: $message';
}
