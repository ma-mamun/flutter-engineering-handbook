# Unit tests

Fast, isolated tests over logic that has no widget in sight — the layer where most of your
coverage should be.

## The recommendation

**Test behaviour through public APIs, with fakes rather than mocks wherever the interface is
small enough.** A unit test that needs elaborate mock setup is telling you the class has too
many collaborators. Keep the suite fast enough that developers run it without being asked;
that speed is what makes it useful.

## Structure logic so it can be tested

Testability is a design property, not a testing technique. Three rules cover most of it:

**Dependencies arrive through the constructor.** A class that reaches for a singleton, a
`GetIt` instance or a `BuildContext` cannot be constructed in a test without global setup.

**Time, randomness and IDs are injected.** `DateTime.now()`, `Random()` and `Uuid().v4()`
inside a method make output unrepeatable:

```dart
class OrderService {
  const OrderService({
    required this.repository,
    required this.clock,        // DateTime Function()
    required this.newId,        // String Function()
  });
}

// In a test:
final service = OrderService(
  repository: FakeOrderRepository(),
  clock: () => DateTime.utc(2026, 1, 1),
  newId: () => 'fixed-id',
);
```

**No Flutter import in the domain.** If a class imports `package:flutter/material.dart`, it
belongs in the presentation layer and needs a widget test instead.

## Fakes versus mocks

| | Fake | Mock |
| --- | --- | --- |
| What it is | A working implementation, simplified | A recording stub with programmed answers |
| Reads as | Data and behaviour | Setup |
| Survives interface changes | Fails to compile — you fix it once | Compiles and silently lies |
| Asserts on | Resulting state | Calls, arguments, counts |
| Best for | Repositories, stores, clients | "Was this called exactly once?" |

**Prefer fakes.** The handbook's samples use them throughout — `FakeUserApi` and
`FakeUserRepository` in `code/testing/` are ordinary classes backed by a map, and they read
as scenarios rather than as instructions to a framework.

Reach for a mock when the *interaction* is the behaviour under test: that a cancel token was
cancelled on dispose, that the network was called exactly once, that a retry happened three
times. `mocktail` is the current default — no code generation, and no `@GenerateMocks`
annotation to keep in sync:

```dart
class MockAnalytics extends Mock implements Analytics {}

test('logs checkout exactly once', () async {
  final analytics = MockAnalytics();
  when(() => analytics.log(any())).thenAnswer((_) async {});

  await CheckoutService(analytics: analytics).submit(cart);

  verify(() => analytics.log('checkout_completed')).called(1);
});
```

The failure mode to avoid: a test that mocks the thing it is testing, then asserts the mock
was called. It passes forever and proves nothing.

## Testing async code

```dart
test('rejects a name that is too short before calling the API', () async {
  final result = await renameUser('u1', ' A ');

  expect(result, isA<Failure<User>>());
  expect(api.calls, isEmpty, reason: 'validation runs before the network');
});
```

Patterns worth knowing:

- **`expectLater` for futures and streams.** `await expectLater(future, throwsStateError)`.
- **`emitsInOrder` for streams**, which is how the Cubit tests in this repository assert a
  loading-then-loaded sequence.
- **`Completer` to control timing.** Hold a response open, assert the intermediate state,
  then complete it. This is how the optimistic-update test proves the UI moved before the
  server answered.
- **`fake_async` for anything with a timer.** Debounce, throttle and retry backoff are tested
  against virtual time in `code/testing/`, so a 30-second backoff is asserted in
  microseconds and never flakes.

```dart
fakeAsync((async) {
  final debouncer = Debouncer(duration: const Duration(milliseconds: 300));
  var calls = 0;
  debouncer.run(() => calls++);
  async.elapse(const Duration(milliseconds: 299));
  expect(calls, 0);
  async.elapse(const Duration(milliseconds: 1));
  expect(calls, 1);
});
```

**Never `await Future.delayed` in a test to "let things settle".** It is slow, and it is the
main source of tests that pass locally and fail on a loaded CI machine.

## Organisation

```dart
group('OrderRepository', () {
  late FakeOrderApi api;
  late OrderRepository repository;

  setUp(() {                       // runs before EVERY test — fresh state each time
    api = FakeOrderApi();
    repository = OrderRepositoryImpl(api: api, cache: InMemoryCache());
  });

  test('answers from the cache without hitting the network', () async { ... });
});
```

- **`setUp`, not `setUpAll`.** `setUpAll` shares state between tests, and shared state makes
  failures depend on execution order — the worst kind of flake to diagnose.
- **`addTearDown`** next to the thing it cleans up, rather than a distant `tearDown` block.
  `addTearDown(container.dispose)` on the line after the container is created cannot be
  forgotten when the test is copied.
- **One behaviour per test**, and a name that states it. `'a failed rename rolls the
  optimistic edit back'` tells you what broke from the CI log alone.

## Coverage: signal, not target

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

Coverage tells you what is **not** tested, which is genuinely useful — an uncovered branch in
a mapper or an error path is a real gap. It does not tell you what is tested *well*: a test
that executes a function and asserts nothing counts the same as a good one.

Use it this way:

- **Look at uncovered lines in the diff of a PR**, not at the project percentage.
- **Do not gate on a number.** A team told to hit 80% writes tests that execute code without
  asserting on it, and now you have a slower suite and the same defects.
- **Exclude generated files** — `*.g.dart`, `*.freezed.dart` — or the number measures your
  code generator.

The number worth watching is trend on new code. A PR that adds a hundred uncovered lines is a
conversation; a project sitting at 62% is not.

## What to test at this level

**Yes:** mappers and parsers (especially the failure paths), business rules, state
transitions in notifiers and blocs, repositories against fake data sources, pure utilities,
retry and pagination logic.

**No:** widget layout, navigation, plugin behaviour, whether the framework works. Those are
[widget](testing-widget.md) and [integration](testing-integration.md) tests, and trying to
force them into unit tests produces the mock-heavy suite everyone hates.

## Interview angles

**"Difference between a unit test and a widget test?"** A unit test constructs plain objects
and asserts on returned state, running in milliseconds with no rendering; a widget test pumps
a widget tree into a test binding and asserts on rendered output and interaction. The
practical tell: if it needs `pumpWidget`, it is not a unit test.

**"Mocks or fakes?"** Fakes by default, because they read as behaviour and break loudly when
the interface changes. Mocks when the interaction itself is the assertion — called once,
cancelled on dispose.

**"How do you test time-dependent code?"** Inject the clock, and use `fake_async` for timers.
Never sleep in a test.

**"Is 100% coverage a good goal?"** No. Coverage shows what is untested, which is useful;
mandating a percentage produces assertion-free tests. Watch uncovered lines in the diff
instead.

## See also

- [Widget tests](testing-widget.md) — the next level up
- [Dependency injection](dependency-injection.md) — why constructor injection makes this easy
- [Clean Architecture](clean-architecture.md) — layers that can be tested without a device
- [Tooling](tooling.md) — running the suite in CI
