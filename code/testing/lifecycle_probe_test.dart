import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter/lifecycle_probe.dart';

void main() {
  group('lifecycle order', () {
    testWidgets('mounting runs initState, didChangeDependencies, build',
        (WidgetTester tester) async {
      final List<String> log = <String>[];

      await tester.pumpWidget(
        MaterialApp(home: LifecycleProbe(log: log, label: 'a')),
      );

      expect(log, <String>['initState', 'didChangeDependencies', 'build']);
    });

    testWidgets('a new configuration runs didUpdateWidget, then build',
        (WidgetTester tester) async {
      final List<String> log = <String>[];

      await tester.pumpWidget(
        MaterialApp(home: LifecycleProbe(log: log, label: 'a')),
      );
      log.clear();

      await tester.pumpWidget(
        MaterialApp(home: LifecycleProbe(log: log, label: 'b')),
      );

      // The State survived: no second initState, and the old label is still
      // available to compare against.
      expect(log, <String>['didUpdateWidget a->b', 'build']);
    });

    testWidgets('setState rebuilds without touching the rest of the lifecycle',
        (WidgetTester tester) async {
      final List<String> log = <String>[];

      await tester.pumpWidget(
        MaterialApp(home: LifecycleProbe(log: log, label: 'a')),
      );
      log.clear();

      tester.state<LifecycleProbeState>(find.byType(LifecycleProbe)).bump();
      await tester.pump();

      expect(log, <String>['build']);
    });

    testWidgets('a changed dependency runs didChangeDependencies again',
        (WidgetTester tester) async {
      final List<String> log = <String>[];

      Widget wrap(double textScale) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: LifecycleProbe(log: log, label: 'a'),
          );

      await tester.pumpWidget(wrap(1));
      log.clear();

      await tester.pumpWidget(wrap(2));

      // The probe reads MediaQuery in build, so it depends on it. The widget
      // itself did not change, yet the State is notified — this is the
      // callback initState cannot replace.
      expect(
        log,
        <String>['didUpdateWidget a->a', 'didChangeDependencies', 'build'],
      );
    });

    testWidgets('removal runs deactivate, then dispose',
        (WidgetTester tester) async {
      final List<String> log = <String>[];

      await tester.pumpWidget(
        MaterialApp(home: LifecycleProbe(log: log, label: 'a')),
      );
      log.clear();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(log, <String>['deactivate', 'dispose']);
    });
  });

  group('mounted guard', () {
    testWidgets('a late result is dropped instead of crashing',
        (WidgetTester tester) async {
      final Completer<String> completer = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(home: DelayedLoader(load: () => completer.future)),
      );
      expect(find.text('loading'), findsOneWidget);

      // The user navigates away while the request is in flight.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // The response arrives for a widget that no longer exists. Without the
      // `mounted` check in _load, this line throws
      // "setState() called after dispose()".
      completer.complete('done');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a result that arrives in time is rendered',
        (WidgetTester tester) async {
      final Completer<String> completer = Completer<String>();

      await tester.pumpWidget(
        MaterialApp(home: DelayedLoader(load: () => completer.future)),
      );

      completer.complete('done');
      await tester.pump();

      expect(find.text('done'), findsOneWidget);
    });
  });
}
