class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'ApiException$code: $message';
  }
}
