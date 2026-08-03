import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter/counter_controller.dart';

void main() {
  group('CounterController', () {
    test('increments and resets', () {
      final CounterController controller = CounterController();
      addTearDown(controller.dispose);

      expect(controller.value, 0);

      controller.increment();
      controller.increment();
      expect(controller.value, 2);

      controller.reset();
      expect(controller.value, 0);
    });

    test('notifies listeners once per change', () {
      final CounterController controller = CounterController();
      addTearDown(controller.dispose);

      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.increment();
      // ValueNotifier skips notification when the value is unchanged — asserting
      // that is what stops a redundant rebuild from creeping back in later.
      controller.value = controller.value;

      expect(notifications, 1);
    });
  });

  testWidgets('CounterPage renders and increments on tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CounterPage()));

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });
}
