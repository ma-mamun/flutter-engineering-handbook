# Testing cheatsheet

Finders, matchers, pump semantics and the level to test at. Explanation in
[Part 2](../part-02-professional/testing-unit.md).

## Which level

| Test this | At this level |
| --- | --- |
| Business rules, mappers, parsers, state transitions | Unit |
| Rendering, gestures, navigation within the app | Widget |
| Appearance: spacing, colour, theming, overflow | Golden |
| Flows crossing platform boundaries, real plugins | Integration |

Many unit, a good number of widget, a handful of integration. Inverting that is the most common
testing mistake.

## Finders

```dart
find.text('Submit')
find.textContaining('Order #')
find.byIcon(Icons.add)
find.byType(OrderTile)
find.byKey(const ValueKey('submit'))
find.bySemanticsLabel('Delete order')
find.widgetWithText(ElevatedButton, 'Submit')
find.widgetWithIcon(IconButton, Icons.close)
find.descendant(of: find.byType(Card), matching: find.text('Total'))
find.ancestor(of: find.text('Total'), matching: find.byType(Card))
find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 24)
find.text('Submit', skipOffstage: false)     // include off-screen
```

Prefer user-visible finders — text, icon, semantics. `byType` couples the test to a class name.

## Matchers

```dart
expect(finder, findsOneWidget);
expect(finder, findsNothing);
expect(finder, findsWidgets);
expect(finder, findsNWidgets(3));
expect(finder, findsAtLeastNWidgets(1));

expect(value, isA<Failure<User>>());
expect(list, containsAllInOrder([a, b]));
expect(() => f(), throwsA(isA<FormatException>()));
await expectLater(future, throwsStateError);
await expectLater(stream, emitsInOrder([isA<Loading>(), isA<Loaded>()]));
```

## Pump semantics

| Call | Effect |
| --- | --- |
| `pump()` | Build exactly one frame |
| `pump(d)` | Advance virtual time by `d`, then build one frame |
| `pumpAndSettle()` | Pump until no frames are scheduled, or time out |
| `pumpWidget(w)` | Mount `w` as the root and pump one frame |

Time is **virtual** in a widget test: `pump(const Duration(seconds: 5))` returns instantly and
fires every timer due in that window.

`pumpAndSettle` **times out on an indefinite animation** — pump fixed durations instead.

## Interactions

```dart
await tester.tap(find.text('Submit'));
await tester.longPress(finder);
await tester.drag(finder, const Offset(0, -300));
await tester.fling(finder, const Offset(0, -500), 3000);
await tester.enterText(find.byType(TextField), 'flutter');
await tester.testTextInput.receiveAction(TextInputAction.done);
await tester.scrollUntilVisible(find.text('Order #50'), 200);
await tester.dragUntilVisible(finder, find.byType(ListView), const Offset(0, -100));
await tester.pageBack();
```

Every interaction needs a `pump` afterwards before asserting.

## Injecting dependencies

```dart
// Riverpod
ProviderScope(overrides: [repoProvider.overrideWithValue(fake)], child: app)

// BLoC
BlocProvider<OrderBloc>.value(value: fakeBloc, child: app)

// Constructor
OrdersPage(repository: FakeOrders([order1]))

// Plain unit test
final container = ProviderContainer(overrides: [...]);
addTearDown(container.dispose);
```

## Environment

```dart
// Screen size — reset it, or it leaks into the next test.
tester.view.physicalSize = const Size(1200, 2000);
tester.view.devicePixelRatio = 2.0;
addTearDown(tester.view.resetPhysicalSize);

// Plugin channel
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel('plugin/name'), (call) async => 'x');

// Virtual time for timers, outside a widget test
fakeAsync((async) {
  debouncer.run(() => calls++);
  async.elapse(const Duration(milliseconds: 300));
  expect(calls, 1);
});
```

## Accessibility

```dart
final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(textContrastGuideline));
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
handle.dispose();
```

## Goldens

```dart
await expectLater(find.byType(PrimaryButton), matchesGoldenFile('goldens/button.png'));
```

```bash
flutter test --update-goldens
```

Load real fonts in `test/flutter_test_config.dart`, or every glyph is a rectangle. Generate
goldens in the environment CI runs them in.

## Commands

```bash
flutter test
flutter test test/features/auth
flutter test --name "refreshes the token"
flutter test --coverage
flutter test --reporter=expanded
flutter test --update-goldens
flutter test integration_test
flutter test --total-shards=4 --shard-index=0
```

## Flake checklist

- [ ] No real network, database or plugin
- [ ] No `await Future.delayed` to "let things settle"
- [ ] `fake_async` or `pump(duration)` for anything timer-driven
- [ ] `setUp`, not `setUpAll` — no state shared between tests
- [ ] `addTearDown` for containers, controllers, view size, mock handlers
- [ ] No `pumpAndSettle` on an indefinite animation
- [ ] No dependence on test execution order

## See also

- [Unit](../part-02-professional/testing-unit.md) · [Widget](../part-02-professional/testing-widget.md) ·
  [Integration](../part-02-professional/testing-integration.md) ·
  [Golden](../part-02-professional/testing-golden.md)
