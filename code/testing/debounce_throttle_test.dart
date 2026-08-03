import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dart/debounce_throttle.dart';

void main() {
  const Duration window = Duration(milliseconds: 300);

  group('Debouncer', () {
    test('runs once after the burst stops', () {
      fakeAsync((FakeAsync async) {
        final Debouncer debouncer = Debouncer(duration: window);
        int calls = 0;

        for (int i = 0; i < 5; i++) {
          debouncer.run(() => calls++);
          async.elapse(const Duration(milliseconds: 100));
        }

        expect(calls, 0, reason: 'still typing');

        async.elapse(window);
        expect(calls, 1);
      });
    });

    test('flush runs the pending action immediately', () {
      fakeAsync((FakeAsync async) {
        final Debouncer debouncer = Debouncer(duration: window);
        int calls = 0;

        debouncer.run(() => calls++);
        debouncer.flush(() => calls++);
        expect(calls, 1);

        // The original timer must not fire as well.
        async.elapse(window);
        expect(calls, 1);
      });
    });

    test('dispose cancels the pending action', () {
      fakeAsync((FakeAsync async) {
        final Debouncer debouncer = Debouncer(duration: window);
        int calls = 0;

        debouncer.run(() => calls++);
        debouncer.dispose();
        async.elapse(window);

        expect(calls, 0);
      });
    });
  });

  group('Throttler', () {
    test('runs on the leading edge and drops the rest of the window', () {
      fakeAsync((FakeAsync async) {
        final Throttler throttler = Throttler(duration: window);
        int calls = 0;

        throttler.run(() => calls++);
        throttler.run(() => calls++);
        throttler.run(() => calls++);
        expect(calls, 1);

        async.elapse(window);
        throttler.run(() => calls++);
        expect(calls, 2);
      });
    });

    test('trailing mode also runs the last call of the window', () {
      fakeAsync((FakeAsync async) {
        final Throttler throttler = Throttler(duration: window, trailing: true);
        final List<int> seen = <int>[];

        throttler.run(() => seen.add(1));
        throttler.run(() => seen.add(2));
        throttler.run(() => seen.add(3));
        expect(seen, <int>[1], reason: 'leading edge only, so far');

        async.elapse(window);
        expect(seen, <int>[1, 3], reason: 'last call of the window, not 2');

        // The cooldown restarts after a trailing call, so a steady stream fires
        // at most once per window rather than twice at the boundary.
        async.elapse(window);
        expect(seen, <int>[1, 3]);
      });
    });
  });
}
