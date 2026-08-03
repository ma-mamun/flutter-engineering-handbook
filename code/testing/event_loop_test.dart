import 'package:flutter_test/flutter_test.dart';

import '../dart/event_loop.dart';

void main() {
  group('event loop ordering', () {
    test('microtasks run before anything in the event queue', () async {
      expect(await eventLoopOrder(), <String>[
        '1 sync',
        '2 sync',
        '3 scheduleMicrotask',
        '4 Future.microtask',
        '5 after await null',
        '6 Future(...)',
        '7 Timer.run',
      ]);
    });

    test('async functions interleave only at await points', () async {
      expect(await interleavedAwaits(), <String>[
        'A start',
        'B start',
        'A middle',
        'B middle',
        'A end',
        'B end',
      ]);
    });

    test('recursive microtasks starve the event queue', () async {
      expect(await microtaskStarvation(rounds: 3), <String>[
        'microtask 3',
        'microtask 2',
        'microtask 1',
        'microtask 0',
        'timer (scheduled first, runs last)',
      ]);
    });
  });
}
