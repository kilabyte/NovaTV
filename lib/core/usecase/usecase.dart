import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

/// Base class for all use cases in the application.
///
/// Use cases represent the business logic of the application and are
/// responsible for executing a single piece of functionality.
///
/// [T] is the return type of the use case.
/// [P] is the type of parameters required by the use case.
abstract class UseCase<T, P> {
  /// Executes the use case with the given parameters.
  ///
  /// Returns an [Either] containing either a [Failure] on the left
  /// or the result of type [T] on the right.
  Future<Either<Failure, T>> call(P params);
}

/// Parameter class for use cases that don't require any parameters.
class NoParams {
  const NoParams();
}

/// Base class for synchronous use cases.
abstract class SyncUseCase<T, P> {
  Either<Failure, T> call(P params);
}

/// Base class for stream-based use cases.
abstract class StreamUseCase<T, P> {
  Stream<Either<Failure, T>> call(P params);
}
