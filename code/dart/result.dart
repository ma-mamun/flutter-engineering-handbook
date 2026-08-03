/// A sealed [Result] type: failures become values the compiler can see.
///
/// Exceptions are invisible in a signature — `Future<User> fetchUser()` tells a
/// caller nothing about what can go wrong. Returning `Future<Result<User>>` puts
/// the failure in the type, and the exhaustive `switch` below stops a new failure
/// mode from being silently ignored.
///
/// The cost: every call site must unwrap. That is worth it at layer boundaries
/// (data -> domain, domain -> presentation) and usually noise anywhere else.
library;

sealed class Result<T> {
  const Result();

  /// Runs [action] and captures any thrown object as a [Failure].
  ///
  /// Use this at the edge of the app — around an HTTP call or a database
  /// query — so exceptions never travel further inward than the data layer.
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error, stackTrace) {
      return Failure<T>(error, stackTrace);
    }
  }

  /// Transforms a success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success<R>(transform(value)),
        Failure<T>(:final error, :final stackTrace) =>
          Failure<R>(error, stackTrace),
      };

  /// Collapses both cases into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Object error, StackTrace stackTrace) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final error, :final stackTrace) =>
          onFailure(error, stackTrace),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
