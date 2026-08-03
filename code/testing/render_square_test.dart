import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../flutter/render_square.dart';

void main() {
  group('RenderSquare', () {
    testWidgets('sizes the child to the largest square that fits',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            // Loose constraints, so the box is free to choose its own size.
            // Under a SizedBox the constraints are tight and `constrain` hands
            // back the parent's size no matter what performLayout wants.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
              child: const SquareBox(
                padding: 10,
                child: ColoredBox(color: Color(0xFF000000)),
              ),
            ),
          ),
        ),
      );

      // Shortest side is 200, minus 10 padding on each side.
      expect(tester.getSize(find.byType(ColoredBox)), const Size(180, 180));
      expect(tester.getSize(find.byType(SquareBox)), const Size(200, 200));
    });

    testWidgets('a changed property relayouts', (WidgetTester tester) async {
      Widget build(double padding) => Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 300,
                height: 200,
                child: SquareBox(
                  padding: padding,
                  child: const ColoredBox(color: Color(0xFF000000)),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(10));
      expect(tester.getSize(find.byType(ColoredBox)), const Size(180, 180));

      // updateRenderObject runs, the setter calls markNeedsLayout, and the box
      // is measured again. Without that call this assertion fails while the
      // widget tree looks correct.
      await tester.pumpWidget(build(40));
      expect(tester.getSize(find.byType(ColoredBox)), const Size(120, 120));
    });

    testWidgets('hit testing reaches the offset child',
        (WidgetTester tester) async {
      int taps = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: SquareBox(
                padding: 20,
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const ColoredBox(color: Color(0xFF000000)),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ColoredBox));
      expect(taps, 1, reason: 'hitTestChildren must apply the paint offset');
    });
  });
}
