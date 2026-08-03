import 'package:flutter_test/flutter_test.dart';

import '../flutter/keys_demo.dart';

void main() {
  group('keys and element matching', () {
    testWidgets('without keys, state stays with the position',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SwappableRow(keyed: false));

      // Tap the first tile twice: 'a' now shows a:2.
      await tester.tap(find.text('a:0'));
      await tester.pump();
      await tester.tap(find.text('a:1'));
      await tester.pump();
      expect(find.text('a:2'), findsOneWidget);

      tester.state<SwappableRowState>(find.byType(SwappableRow)).swap();
      await tester.pump();

      // The labels swapped but the counts did not follow them: the element in
      // slot 0 matched the new widget by type, kept its State, and simply took
      // the new label.
      expect(find.text('b:2'), findsOneWidget);
      expect(find.text('a:0'), findsOneWidget);
    });

    testWidgets('with keys, state follows the widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(const SwappableRow(keyed: true));

      await tester.tap(find.text('a:0'));
      await tester.pump();
      await tester.tap(find.text('a:1'));
      await tester.pump();
      expect(find.text('a:2'), findsOneWidget);

      tester.state<SwappableRowState>(find.byType(SwappableRow)).swap();
      await tester.pump();

      // Same two elements, reordered rather than reused in place.
      expect(find.text('a:2'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget);
    });
  });
}
