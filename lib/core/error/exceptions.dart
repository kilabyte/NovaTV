/// Base exception class for all application exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Exception thrown when a server request fails
class ServerException extends AppException {
  final int? statusCode;

  const ServerException(super.message, {super.code, this.statusCode});

  @override
  String toString() =>
      'ServerException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Exception thrown when a cache operation fails
class CacheException extends AppException {
  const CacheException(super.message, {super.code});

  @override
  String toString() => 'CacheException: $message';
}

/// Exception thrown when parsing fails
class ParseException extends AppException {
  const ParseException(super.message, {super.code});

  @override
  String toString() => 'ParseException: $message';
}

/// Exception thrown when network is unavailable
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception thrown when validation fails
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});

  @override
  String toString() => 'ValidationException: $message';
}

/// Exception thrown when resource is not found
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code});

  @override
  String toString() => 'NotFoundException: $message';
}
