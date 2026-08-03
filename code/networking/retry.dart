/// Retry with exponential backoff and jitter.
///
/// The three things a naive retry gets wrong: it retries requests that will
/// never succeed, it retries non-idempotent writes and duplicates them, and it
/// retries on a fixed schedule so every client in a region hammers a recovering
/// server in lockstep. This handles all three.
library;

import 'dart:async';
import 'dart:math';

/// Decides whether a given failure is worth another attempt.
typedef RetryPredicate = bool Function(Object error);

/// A retry policy, separated from the call so it can be tested and reused.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.jitter = 0.3,
  })  : assert(maxAttempts > 0, 'maxAttempts must be at least 1'),
        assert(jitter >= 0 && jitter <= 1, 'jitter is a fraction of the delay');

  /// Total attempts, including the first. 3 means one call and two retries.
  final int maxAttempts;
  final Duration initialDelay;

  /// Ceiling for the computed delay. Without it, attempt 10 waits three hours.
  final Duration maxDelay;
  final double multiplier;

  /// Fraction of the delay to randomise, ±. Jitter is what stops every client
  /// that failed during an outage from retrying at the same instant and
  /// knocking the server over again as it recovers.
  final double jitter;

  /// Delay before [attempt] (1-based: the wait before attempt 2 is delayFor(2)).
  Duration delayFor(int attempt, {Random? random}) {
    final double exponential =
        initialDelay.inMilliseconds * pow(multiplier, attempt - 2).toDouble();
    final double capped = min(exponential, maxDelay.inMilliseconds.toDouble());
    final double spread = capped * jitter;
    final double randomised =
        capped - spread + (random ?? Random()).nextDouble() * spread * 2;
    return Duration(milliseconds: max(0, randomised.round()));
  }
}

/// Runs [action], retrying failures that [retryIf] accepts.
///
/// Rethrows the last error once attempts are exhausted, so the caller sees the
/// real failure rather than a wrapper that hides it.
Future<T> retry<T>(
  Future<T> Function() action, {
  RetryPolicy policy = const RetryPolicy(),
  RetryPredicate retryIf = isTransient,
  void Function(int attempt, Object error, Duration delay)? onRetry,
  Random? random,
}) async {
  for (int attempt = 1;; attempt++) {
    try {
      return await action();
    } on Object catch (error) {
      // Two reasons to stop: this failure will never succeed, or we are out of
      // attempts. Both rethrow, because swallowing here would hide a real bug.
      if (attempt >= policy.maxAttempts || !retryIf(error)) {
        rethrow;
      }
      final Duration delay = policy.delayFor(attempt + 1, random: random);
      onRetry?.call(attempt, error, delay);
      await Future<void>.delayed(delay);
    }
  }
}

/// The default predicate: retry what a later attempt could plausibly fix.
///
/// A 400 or a 404 is not transient — retrying it wastes battery and adds load
/// to a server that already gave its final answer.
bool isTransient(Object error) => switch (error) {
      HttpStatusException(:final statusCode) =>
        statusCode == 408 || statusCode == 429 || statusCode >= 500,
      TimeoutException() => true,
      // A socket error means the connection failed, not that the request was
      // rejected — always worth another attempt.
      _ => error.toString().contains('SocketException'),
    };

/// Minimal stand-in for a client's status exception, so this file stays
/// dependency free.
class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode, [this.body]);

  final int statusCode;
  final String? body;

  /// Whether repeating the request is safe without an idempotency key.
  ///
  /// Retrying a POST that already reached the server charges the card twice.
  /// The fix is an idempotency key the server deduplicates on, not a shorter
  /// timeout.
  static bool isIdempotent(String method) {
    const Set<String> safe = <String>{
      'GET',
      'HEAD',
      'PUT',
      'DELETE',
      'OPTIONS',
    };
    return safe.contains(method.toUpperCase());
  }

  @override
  String toString() => 'HttpStatusException($statusCode)';
}

/// Honours a `Retry-After` header when the server sent one.
///
/// A 429 with `Retry-After: 30` is the server telling you exactly when to come
/// back. Ignoring it in favour of your own backoff is how a client gets rate
/// limited for longer.
Duration? retryAfter(Map<String, String> headers) {
  final String? value = headers['retry-after'] ?? headers['Retry-After'];
  if (value == null) {
    return null;
  }
  final int? seconds = int.tryParse(value.trim());
  return seconds == null ? null : Duration(seconds: seconds);
}
