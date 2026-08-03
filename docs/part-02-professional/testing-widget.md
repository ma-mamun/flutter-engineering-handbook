# Widget tests

Pumping widgets, finding them, and asserting behaviour rather than implementation.

## The recommendation

**Test what a user can observe and do.** Find widgets by the text and semantics a user sees,
drive them with taps and gestures, and assert on what appears. A widget test that reaches
into a `State` to check a private field will break on every refactor and catch nothing that
matters.

## The shape of one

```dart
testWidgets('shows the order list and opens a detail on tap', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ordersRepositoryProvider.overrideWithValue(FakeOrders([order1]))],
      child: const MaterialApp(home: OrdersPage()),
    ),
  );

  // The first pump builds the loading state; the fake resolves on the next frame.
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pumpAndSettle();

  expect(find.text('Order #1'), findsOneWidget);

  await tester.tap(find.text('Order #1'));
  await tester.pumpAndSettle();

  expect(find.byType(OrderDetailPage), findsOneWidget);
});
```

Widget tests run headless against a test binding at a default 800×600 logical surface, and
they are fast — hundreds of them run in seconds. This is the level where most UI regressions
should be caught.

## pump versus pumpAndSettle

The distinction that causes the most confusion, and the most flakes:

| | What it does |
| --- | --- |
| `pump()` | Builds exactly one frame |
| `pump(Duration)` | Advances virtual time, then builds one frame |
| `pumpAndSettle()` | Pumps repeatedly until no frames are scheduled, or it times out |

**Time in a widget test is virtual.** `pump(const Duration(seconds: 5))` returns instantly and
fires every timer due in that window. That is why timer-driven code is testable here without
waiting.

`pumpAndSettle` **times out on an indefinite animation** — a looping progress spinner never
settles, and you get "pumpAndSettle timed out" pointing at a widget that is working
correctly. In that case, pump a fixed number of frames instead:

```dart
await tester.pump();                                    // start the animation
await tester.pump(const Duration(milliseconds: 300));   // advance into it
```

Prefer explicit pumps when you know the timing; use `pumpAndSettle` for navigation
transitions where you do not want to encode the duration.

## Finders

```dart
find.text('Submit')                        // by rendered text
find.byIcon(Icons.add)
find.byType(OrderTile)
find.byKey(const ValueKey('submit'))       // stable across copy changes
find.bySemanticsLabel('Delete order')      // what a screen reader would find
find.widgetWithText(ElevatedButton, 'Submit')
find.descendant(of: find.byType(Card), matching: find.text('Total'))
find.text('Submit', skipOffstage: false)   // include off-screen widgets
```

**Prefer user-visible finders** — text, icon, semantics. They are what the user perceives, so
they break when the user experience breaks, which is the point.

Use a `ValueKey` when the text is localised or changes often. Use `find.byType` for structural
assertions, sparingly: it couples the test to the widget class, so a refactor that swaps a
`Card` for a `Container` fails a test that nothing user-visible changed.

Matchers: `findsOneWidget`, `findsNothing`, `findsWidgets`, `findsNWidgets(3)`,
`findsAtLeastNWidgets(1)`.

## Injecting dependencies

The whole reason the [DI page](dependency-injection.md) matters:

```dart
// Riverpod
ProviderScope(overrides: [repositoryProvider.overrideWithValue(fake)], child: app)

// BLoC
BlocProvider<OrderBloc>.value(value: fakeBloc, child: app)

// Constructor
OrdersPage(repository: FakeOrders([order1]))
```

Anything a widget test cannot replace, it cannot test. If a page constructs its own HTTP
client, the test hits the network — which fails in CI, slowly.

## Things that need setting up

**Screen size**, when testing responsive layouts:

```dart
tester.view.physicalSize = const Size(1200, 2000);
tester.view.devicePixelRatio = 2.0;
addTearDown(tester.view.resetPhysicalSize);   // or it leaks into the next test
```

**Scrolling to an off-screen widget** — a lazy list has not built it yet, so `tap` fails with
"could not find":

```dart
await tester.scrollUntilVisible(find.text('Order #50'), 200);
await tester.dragUntilVisible(find.text('Order #50'), find.byType(ListView), const Offset(0, -100));
```

**Text entry:**

```dart
await tester.enterText(find.byType(TextField), 'flutter');
await tester.testTextInput.receiveAction(TextInputAction.done);
await tester.pump();
```

**Plugins**, which have no platform side in a test. Stub the channel rather than letting the
call fail:

```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '/tmp/test');
```

**Network images**, which throw in tests by default. Use
`mockNetworkImagesFor` from `network_image_mock`, or inject an image provider — a real
request in a widget test is a flake and a slow one.

## Asserting behaviour, not implementation

```dart
// Implementation: breaks on any refactor, catches nothing a user would notice.
expect(tester.state<_OrdersPageState>(find.byType(OrdersPage)).isLoading, isFalse);

// Behaviour: survives refactors, fails when the user experience breaks.
expect(find.byType(CircularProgressIndicator), findsNothing);
expect(find.text('Order #1'), findsOneWidget);
```

The exception is a controller or notifier deliberately exposed for testing — the
`LifecycleProbeState.bump()` in `code/flutter/lifecycle_probe.dart` exists precisely so a test
can trigger a rebuild the way a callback would.

## Testing accessibility

Nearly free, and it catches real defects:

```dart
testWidgets('meets accessibility guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  handle.dispose();
});
```

`labeledTapTargetGuideline` finds icon buttons with no semantic label — the most common
accessibility bug in a Flutter app, and one nobody notices without a screen reader.

## Keeping them from becoming flaky

- **Fake everything asynchronous.** No real network, no real database, no real timers you did
  not control.
- **Reset global state** in `addTearDown` — view size, mock handlers, singletons.
- **Never use `pumpAndSettle` on an indefinite animation.**
- **Do not assert on exact pixel positions** unless that is the point; layout shifts with font
  and platform.
- **Prefer `pump(duration)` over `pumpAndSettle`** where you know the timing, so the test
  fails loudly rather than hanging.

## Interview angles

**"What is a widget test and when do you use one?"** A headless test that pumps a widget tree
into a test binding and asserts on rendered output and interaction — for anything involving
rendering, gestures or navigation, without a device. Fast enough to have hundreds.

**"`pump` versus `pumpAndSettle`?"** One frame versus repeated frames until nothing is
scheduled. `pumpAndSettle` times out on an indefinite animation, which is the most common
confusing failure.

**"How do you inject a dependency into a widget test?"** Override the provider, provide the
bloc, or pass it through the constructor. If it cannot be replaced, it cannot be tested — and
that is a design problem, not a testing one.

**"How do you test a screen that loads data?"** Fake the repository, assert the loading state
on the first pump, settle, then assert the loaded state. Also assert the error and empty
states — most bugs live there.

## See also

- [Unit tests](testing-unit.md) — the level below
- [Golden tests](testing-golden.md) — asserting appearance rather than structure
- [Integration tests](testing-integration.md) — the same flows on a real device
- [Widget lifecycle](../part-01-foundations/widget-lifecycle.md) — what a pump actually drives
