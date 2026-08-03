/// Stream operators worth understanding before reaching for a package.
///
/// `debounce` and `switchMap` are the two rxdart operators people install
/// rxdart for. Both are about forty lines of `StreamController` plumbing, and
/// writing them once is the fastest way to learn what a subscription actually
/// owns.
library;

import 'dart:async';

extension StreamPipeline<T> on Stream<T> {
  /// Emits an event only after [duration] has passed without a newer one.
  ///
  /// The last event before the source closes is always emitted, even if the
  /// timer has not fired yet — dropping it is the bug every hand-rolled
  /// debounce ships with first.
  Stream<T> debounce(Duration duration) {
    // `late final` rather than a nullable local: onListen cannot run before the
    // assignment below, so the null checks would be noise.
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    Timer? timer;
    bool hasPending = false;
    late T pending;

    void emitPending() {
      if (hasPending) {
        hasPending = false;
        controller.add(pending);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        subscription = listen(
          (T event) {
            pending = event;
            hasPending = true;
            timer?.cancel();
            timer = Timer(duration, emitPending);
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            // Drop the handle *before* closing. The close below cancels the
            // downstream listener, which runs onCancel, which would otherwise
            // cancel this subscription from inside its own onDone callback —
            // and a subscription cancelled that way never delivers its done
            // event, so the listener hangs open forever.
            subscription = null;
            emitPending();
            controller.close();
          },
        );
      },
      // Without these two, a paused listener keeps the source running and
      // events pile up in the controller's buffer.
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Maps each event to a stream and emits only the newest inner stream's
  /// events, cancelling the previous one.
  ///
  /// This is the correct operator for search-as-you-type: `asyncExpand` waits
  /// for the in-flight request to finish before starting the next, so a slow
  /// response for "fl" can overwrite the results for "flutter". `switchMap`
  /// cancels it instead.
  Stream<R> switchMap<R>(Stream<R> Function(T event) mapper) {
    late final StreamController<R> controller;
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    bool outerDone = false;

    void closeIfFinished() {
      if (outerDone && inner == null) {
        controller.close();
      }
    }

    controller = StreamController<R>(
      onListen: () {
        outer = listen(
          (T event) {
            // Cancelling here is the whole point: the previous request's
            // response can no longer reach the UI.
            unawaited(inner?.cancel());
            inner = mapper(event).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                inner = null;
                closeIfFinished();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            // Same reason as in debounce: this subscription is finished, and
            // cancelling it from inside its own onDone would swallow the done
            // event the listener is waiting for.
            outer = null;
            closeIfFinished();
          },
        );
      },
      onCancel: () async {
        await inner?.cancel();
        await outer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Emits each event alongside the previous one, so a listener can react to a
  /// transition rather than a value.
  Stream<(T? previous, T current)> withPrevious() {
    T? previous;
    return map((T current) {
      final (T?, T) pair = (previous, current);
      previous = current;
      return pair;
    });
  }
}

/// A search pipeline built from the operators above.
///
/// Debounce first, then drop repeats, then switch — in that order. Reversing
/// the first two lets a user who types "a", deletes it and retypes "a" fire two
/// identical requests.
Stream<List<String>> searchResults({
  required Stream<String> queries,
  required Future<List<String>> Function(String query) search,
  Duration debounce = const Duration(milliseconds: 300),
}) {
  return queries
      .map((String query) => query.trim())
      .debounce(debounce)
      .distinct()
      .switchMap(
        (String query) => query.isEmpty
            ? Stream<List<String>>.value(const <String>[])
            : Stream<List<String>>.fromFuture(search(query)),
      );
}
