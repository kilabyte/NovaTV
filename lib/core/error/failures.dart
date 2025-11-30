import 'package:equatable/equatable.dart';

/// Base failure class for all application failures
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Failure when server/network request fails
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {super.code, this.statusCode});

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Failure when local cache operation fails
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

/// Failure when parsing data fails
class ParseFailure extends Failure {
  const ParseFailure(super.message, {super.code});
}

/// Failure when network is unavailable
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// Failure when validation fails
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Failure when resource is not found
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

/// Failure for unknown errors
class UnknownFailure extends Failure {
  final Object? originalError;

  const UnknownFailure([
    super.message = 'An unexpected error occurred',
    this.originalError,
  ]);

  @override
  List<Object?> get props => [message, originalError];
}
