final class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.cause,
    this.isNetworkError = false,
    this.errorCode,
  });

  final String message;
  final int? statusCode;
  final Object? cause;
  final bool isNetworkError;
  final String? errorCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() {
    final status = statusCode;
    return status == null
        ? 'ApiException: $message'
        : 'ApiException($status): $message';
  }
}
