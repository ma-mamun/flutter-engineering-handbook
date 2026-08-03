# Integration tests

End-to-end flows on a real device, and keeping them from becoming the suite everyone ignores.

## The recommendation

**A handful of integration tests covering the flows that make money, and nothing else.** They
are slow, they need devices, and they fail for reasons unrelated to your code. Ten reliable
tests over sign-in, checkout and sync are worth more than two hundred that get rerun until
green — a suite people rerun is a suite people stop reading.

## Setup

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

```dart
// integration_test/checkout_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a signed-in user can complete a checkout', (tester) async {
    await tester.pumpWidget(const App());          // the real app
    await tester.pumpAndSettle();

    await signIn(tester, email: 'test@example.com');
    await addToCart(tester, 'Blue Shirt');
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(find.text('Order confirmed'), findsOneWidget);
  });
}
```

```bash
flutter test integration_test                     # on a connected device
flutter drive --driver=test_driver/integration_test.dart \
              --target=integration_test/checkout_test.dart --profile
```

The API is the same `WidgetTester` as a [widget test](testing-widget.md). The differences are
that the app is real, plugins actually work, and time is real rather than virtual — so
`pumpAndSettle` waits for genuine network calls and can genuinely time out.

## What belongs here, and what does not

**Yes:** sign-in and sign-out, the primary revenue flow, offline-to-online sync, deep link
entry points, permission prompts, anything crossing a platform channel, and a smoke test that
the app starts and reaches the home screen.

**No:** validation rules, formatting, error message wording, layout details, individual widget
behaviour. Every one of those is cheaper and more reliable one level down, and putting them
here is how a suite grows to forty minutes.

The proportions worth aiming for: many unit tests, a good number of widget tests, a handful of
integration tests. Inverting that pyramid is the single most common testing mistake, and it
shows up as a CI pipeline nobody trusts.

## Backend: fake, staging, or production

| Approach | Reliable | Realistic | Use for |
| --- | --- | --- | --- |
| Fakes in-process | High | Low | Most flows — the default |
| Local mock server | High | Medium | Contract-shaped tests |
| Staging backend | Medium | High | A nightly subset |
| Production | Low | Highest | Never in CI |

**Default to fakes**, injected the same way as in a widget test, with an entry point built for
it:

```dart
// integration_test/app_entry.dart
void bootstrap({required bool useFakes}) {
  runApp(ProviderScope(
    overrides: useFakes ? fakeOverrides : const [],
    child: const App(),
  ));
}
```

The realism you lose is mostly at the network boundary, which
[contract tests or a mock server](../part-03-data/networking.md) cover better anyway. Run the
staging-backed subset nightly rather than per-commit, so a backend deploy does not block a
frontend merge.

## Where the flakes come from

In roughly the order they appear:

**Waiting on wall-clock time.** `pumpAndSettle` with a real network can exceed its timeout on
a slow runner. Wait for a *condition*, not a duration:

```dart
Future<void> waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}
```

**State left behind by the previous test.** Reset storage, databases and caches between tests,
and never depend on execution order.

**Animations that never settle.** A looping indicator makes `pumpAndSettle` time out. Disable
non-essential animations under test, or pump fixed durations.

**Permission dialogs**, which are native and outside the widget tree. Grant them at launch:

```bash
adb shell pm grant com.example.app android.permission.CAMERA
xcrun simctl privacy booted grant photos com.example.app
```

**Shared test accounts.** Two runs using the same account race each other. Create an account
per run, or partition by run id.

**Keyboard timing.** After `enterText`, pump before tapping the button the keyboard was
covering.

## On CI and device farms

Emulators in CI are cheap and slower than real hardware; device farms — Firebase Test Lab,
BrowserStack, AWS Device Farm — are realistic and cost money per minute.

```yaml
- name: Integration tests
  run: |
    flutter build apk --debug
    flutter build apk --debug --target=integration_test/checkout_test.dart
    gcloud firebase test android run \
      --type instrumentation \
      --app build/app/outputs/apk/debug/app-debug.apk \
      --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
      --device model=redfin,version=30 \
      --timeout 10m
```

Two policies that keep this affordable and useful: **run the smoke test on every PR and the
full suite nightly**, and **pick two devices — the oldest supported Android and the newest
iOS** — rather than a matrix that costs more than it catches.

## Recording performance during a flow

Integration tests are also where you measure real interactions:

```dart
await binding.watchPerformance(() async {
  await tester.fling(find.byType(ListView), const Offset(0, -500), 3000);
  await tester.pumpAndSettle();
}, reportKey: 'scroll_timeline');
```

The resulting JSON carries frame build and raster times; assert on the 90th percentile and the
build fails when scrolling regresses. Details in [profiling](../part-04-production/performance-profiling.md).

## A rule about retries

Retrying a failed integration test in CI hides real bugs — race conditions in your app look
exactly like flakes. If you must retry to stay green, **track which tests retry and treat a
repeat offender as a bug ticket**, not as background noise. A suite where everything is
retried twice is a suite that tells you nothing.

## Interview angles

**"When do you write an integration test?"** For flows that cross layers and platform
boundaries where a failure costs money — sign-in, checkout, sync. Keep the count small,
because they are slow and environment-dependent.

**"How do you stop them being flaky?"** Wait for conditions rather than durations, reset state
between tests, fake the network by default, grant permissions at launch, and avoid shared
accounts. Then the honest part: track retries instead of hiding behind them.

**"Real backend or mocked?"** Fakes for the per-commit suite, staging nightly, never
production. You trade realism at the network boundary, which contract tests cover better.

**"How do you run them in CI?"** Emulator or device farm, smoke test per PR, full suite
nightly, on two devices chosen for coverage rather than a large matrix.

## See also

- [Widget tests](testing-widget.md) — the same API, without a device
- [Golden tests](testing-golden.md) — appearance regressions
- [GitHub Actions](../part-04-production/ci-github-actions.md) — wiring this into CI
- [Profiling](../part-04-production/performance-profiling.md) — performance in a real flow
