import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dart/stream_pipeline.dart';

void main() {
  const Duration window = Duration(milliseconds: 300);

  group('debounce', () {
    test('emits only the last event of a burst', () {
      fakeAsync((FakeAsync async) {
        final StreamController<String> source = StreamController<String>();
        final List<String> seen = <String>[];
        final StreamSubscription<String> subscription =
            source.stream.debounce(window).listen(seen.add);

        source
          ..add('f')
          ..add('fl')
          ..add('flu');
        async.elapse(window);

        expect(seen, <String>['flu']);

        unawaited(subscription.cancel());
        unawaited(source.close());
        async.flushMicrotasks();
      });
    });

    test('emits the pending event when the source closes early', () {
      fakeAsync((FakeAsync async) {
        final StreamController<String> source = StreamController<String>();
        final List<String> seen = <String>[];
        bool done = false;

        source.stream
            .debounce(window)
            .listen(seen.add, onDone: () => done = true);

        source.add('typed then submitted');
        unawaited(source.close());
        // Close travels through the source subscription, the debounce
        // controller and then the listener — more than one microtask hop, so
        // elapse rather than a single flush.
        async.elapse(window);

        expect(seen, <String>['typed then submitted']);
        expect(done, isTrue);
      });
    });
  });

  group('switchMap', () {
    test('cancels the previous inner stream', () async {
      final StreamController<int> outer = StreamController<int>();
      final StreamController<String> first = StreamController<String>();
      final StreamController<String> second = StreamController<String>();
      bool firstCancelled = false;
      first.onCancel = () => firstCancelled = true;

      final List<String> seen = <String>[];
      final StreamSubscription<String> subscription = outer.stream
          .switchMap<String>((int id) => id == 1 ? first.stream : second.stream)
          .listen(seen.add);

      outer.add(1);
      await pumpEventQueue();
      first.add('from first');
      await pumpEventQueue();

      outer.add(2);
      await pumpEventQueue();
      // The late reply from the first request must never reach the listener —
      // this is the ordering bug switchMap exists to prevent.
      first.add('stale');
      second.add('from second');
      await pumpEventQueue();

      expect(seen, <String>['from first', 'from second']);
      expect(firstCancelled, isTrue);

      await subscription.cancel();
      await outer.close();
      await first.close();
      await second.close();
    });
  });

  group('withPrevious', () {
    test('pairs each event with the one before it', () async {
      final List<(int?, int)> pairs =
          await Stream<int>.fromIterable(<int>[1, 2, 3])
              .withPrevious()
              .toList();

      expect(pairs, <(int?, int)>[(null, 1), (1, 2), (2, 3)]);
    });
  });

  group('searchResults', () {
    test('debounces, drops repeats, and keeps only the newest request', () {
      fakeAsync((FakeAsync async) {
        final StreamController<String> queries = StreamController<String>();
        final List<String> requested = <String>[];
        final List<List<String>> seen = <List<String>>[];

        final StreamSubscription<List<String>> subscription = searchResults(
          queries: queries.stream,
          search: (String query) async {
            requested.add(query);
            return <String>['$query result'];
          },
          debounce: window,
        ).listen(seen.add);

        queries.add('fl');
        async.elapse(const Duration(milliseconds: 100));
        queries.add('flut');
        async.elapse(const Duration(milliseconds: 100));
        queries.add('flutter');
        async.elapse(window);

        expect(requested, <String>['flutter'], reason: 'one request per pause');
        expect(seen, <List<String>>[
          <String>['flutter result'],
        ]);

        // A repeat of the same query does not hit the network again.
        queries.add('flutter');
        async.elapse(window);
        expect(requested, <String>['flutter']);

        unawaited(subscription.cancel());
        unawaited(queries.close());
        async.flushMicrotasks();
      });
    });
  });
}
