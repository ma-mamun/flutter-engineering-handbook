/// The event loop, made observable.
///
/// Every claim on the async page is asserted by a test against these two
/// functions, so the ordering below is the ordering the Dart VM actually
/// produces rather than the ordering the page's author remembers.
library;

import 'dart:async';

/// Returns the order in which synchronous code, microtasks and event-queue
/// callbacks run, as a list you can assert against.
///
/// The rule the list demonstrates: the loop drains the *entire* microtask queue
/// before it takes one item from the event queue, and it never interleaves the
/// two.
Future<List<String>> eventLoopOrder() async {
  final List<String> log = <String>[];

  log.add('1 sync');

  // Microtask queue.
  scheduleMicrotask(() => log.add('3 scheduleMicrotask'));

  // Event queue: `Future(...)` is a zero-duration timer, not a microtask. This
  // is the single most common misconception about Dart async.
  unawaited(Future<void>(() => log.add('6 Future(...)')));

  // Microtask queue, queued behind the scheduleMicrotask above.
  unawaited(Future<void>.microtask(() => log.add('4 Future.microtask')));

  // Event queue, queued behind the `Future(...)` above.
  Timer.run(() => log.add('7 Timer.run'));

  log.add('2 sync');

  // `await null` is not a no-op. It suspends this function and schedules the
  // rest of the body as a microtask, so it lands behind the two already queued.
  await null;
  log.add('5 after await null');

  // A zero-duration timer created here is queued behind both event-queue
  // entries above, so by the time it fires the log is complete.
  await Future<void>.delayed(Duration.zero);
  return log;
}

/// Shows what "concurrent, not parallel" means on a single isolate.
///
/// Both calls run on the same thread. They interleave only at `await` points —
/// between two awaits, a function's code cannot be interrupted, which is why
/// you never need a mutex around synchronous Dart code.
Future<List<String>> interleavedAwaits() async {
  final List<String> log = <String>[];

  Future<void> task(String name) async {
    log.add('$name start');
    await null;
    log.add('$name middle');
    await null;
    log.add('$name end');
  }

  // Starting both before awaiting either is what makes them overlap. Awaiting
  // `task('A')` on this line instead would run A to completion first.
  final Future<void> a = task('A');
  final Future<void> b = task('B');
  await Future.wait<void>(<Future<void>>[a, b]);

  return log;
}

/// A microtask that schedules another microtask starves the event queue.
///
/// [rounds] recursive microtasks all run before a single timer that was
/// scheduled first. This is how an app locks up with a UI thread that is not
/// technically blocked: timers, I/O completions and, in Flutter, the next frame
/// all sit in the event queue behind the recursion.
Future<List<String>> microtaskStarvation({int rounds = 3}) async {
  final List<String> log = <String>[];
  final Completer<void> done = Completer<void>();

  Timer.run(() => log.add('timer (scheduled first, runs last)'));

  void recurse(int remaining) {
    log.add('microtask $remaining');
    if (remaining > 0) {
      scheduleMicrotask(() => recurse(remaining - 1));
    } else {
      Timer.run(done.complete);
    }
  }

  scheduleMicrotask(() => recurse(rounds));

  await done.future;
  return log;
}
