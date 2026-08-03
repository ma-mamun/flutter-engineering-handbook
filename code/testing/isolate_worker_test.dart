import 'package:flutter_test/flutter_test.dart';

import '../dart/isolate_worker.dart';

void main() {
  group('Isolate.run', () {
    test('parses JSON off the calling isolate', () async {
      const String payload =
          '[{"name":"Ada"},{"name":"Grace"},{"id":3},{"name":"Alan"}]';

      expect(
        await parseNamesOffThread(payload),
        <String>['Ada', 'Grace', 'Alan'],
      );
    });

    test('errors thrown inside the isolate surface at the await', () {
      expect(
        parseNamesOffThread('{"not":"an array"}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('IsolateWorker', () {
    test('answers repeated jobs over one spawn', () async {
      final IsolateWorker worker = await IsolateWorker.spawn();
      addTearDown(worker.close);

      expect(await worker.send(10), 55);
      expect(await worker.send(20), 6765);
      expect(await worker.send('{"ok":true}'), <String, Object?>{'ok': true});
    });

    test('reports a failing job instead of hanging', () async {
      final IsolateWorker worker = await IsolateWorker.spawn();
      addTearDown(worker.close);

      await expectLater(
        worker.send(3.14),
        throwsA(contains('unsupported job type')),
      );
      // The worker survives a failed job.
      expect(await worker.send(5), 5);
    });

    test('close fails requests still in flight', () async {
      final IsolateWorker worker = await IsolateWorker.spawn();

      final Future<Object?> inFlight = worker.send(30);
      worker.close();

      await expectLater(inFlight, throwsStateError);
      expect(() => worker.send(1), throwsStateError);
    });
  });
}
