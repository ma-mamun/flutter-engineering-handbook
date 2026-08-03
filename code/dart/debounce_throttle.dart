/// Debounce and throttle: two answers to "this fires too often", with
/// different failure modes.
///
/// Debounce waits for quiet — good for a search field, wrong for a scroll
/// handler that must react while the user is still scrolling. Throttle runs
/// immediately and then ignores calls for a window — good for scroll and
/// resize, wrong for search because it fires on a half-typed query.
library;

import 'dart:async';

/// Runs the most recent action once [duration] has passed with no new call.
///
/// Every call cancels the pending one, so a fast typist produces exactly one
/// request: the one for the query they stopped on.
class Debouncer {
  Debouncer({required this.duration});

  final Duration duration;
  Timer? _timer;

  bool get isPending => _timer?.isActive ?? false;

  /// Schedules [action], replacing any action still waiting to run.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Runs the pending action now, if there is one.
  ///
  /// Wire this to "user pressed enter": they have told you they are done, and
  /// waiting out the remaining delay only looks like lag.
  void flush(void Function() action) {
    if (isPending) {
      _timer?.cancel();
      _timer = null;
      action();
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels the pending action.
  ///
  /// Call from `State.dispose`. A debouncer that fires after its widget is gone
  /// runs a callback that closes over a dead `BuildContext` — the crash is
  /// `setState() called after dispose()`, and it reproduces only when the user
  /// navigates back fast enough.
  void dispose() => cancel();
}

/// Runs an action immediately, then ignores calls for [duration].
///
/// This is the leading-edge variant: the first call in a burst wins. Set
/// [trailing] to also run the last call that arrived during the window, which
/// is what you want when the final value matters — the last scroll offset, the
/// final slider position.
class Throttler {
  Throttler({required this.duration, this.trailing = false});

  final Duration duration;
  final bool trailing;

  Timer? _cooldown;
  void Function()? _pending;

  bool get isThrottled => _cooldown?.isActive ?? false;

  void run(void Function() action) {
    if (isThrottled) {
      if (trailing) {
        _pending = action;
      }
      return;
    }

    action();
    _startCooldown();
  }

  void _startCooldown() {
    _cooldown = Timer(duration, () {
      final void Function()? pending = _pending;
      _pending = null;
      if (pending != null) {
        pending();
        // Restart the window so a steady stream of calls fires at most once per
        // duration rather than twice at the boundary.
        _startCooldown();
      }
    });
  }

  void cancel() {
    _cooldown?.cancel();
    _cooldown = null;
    _pending = null;
  }

  void dispose() => cancel();
}
