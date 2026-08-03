# BLoC

Events in, states out — with the boilerplate tradeoff stated honestly, and the case where
it pays for itself.

## The recommendation

**Start with Cubit.** It is BLoC without the event classes, and it covers the large majority
of screens. Move a Cubit to a Bloc when you need one of exactly two things: a traceable
event log, or an **event transformer** — debounce, throttle, or cancel-the-previous. Those
are capabilities a Cubit cannot express, and they are worth the extra file.

## Cubit and Bloc, side by side

```dart
--8<-- "architecture/bloc_search.dart"
```

`UserCubit` exposes a method. `SearchBloc` takes events, and its `on<SearchQueryChanged>`
registration carries a transformer that debounces the stream of events and cancels the
handler still running when a newer event arrives. That one line is the reason the file
exists.

| | Cubit | Bloc |
| --- | --- | --- |
| Trigger | A method call | An event object |
| Files per feature | State + cubit | State + events + bloc |
| Traceability | Method name in a stack trace | Every event and transition in `BlocObserver` |
| Concurrency control | None | Event transformers |
| Right for | Most screens | Search, forms with async validation, state machines |

## Event transformers

From `bloc_concurrency`, and the reason to reach for a Bloc:

| Transformer | Behaviour | Use for |
| --- | --- | --- |
| `concurrent()` | All handlers run at once (the default) | Independent events |
| `sequential()` | One at a time, queued in order | Writes that must not interleave |
| `restartable()` | Cancels the running handler on a new event | Search, autocomplete |
| `droppable()` | Ignores new events while one is running | Submit buttons, avoiding double-taps |

`droppable()` deserves its own mention: it is the correct fix for double-submitted orders,
and it is one line against the usual approach of a `_isSubmitting` boolean that someone
forgets to reset in an error path.

```dart
on<CheckoutSubmitted>(_onSubmit, transformer: droppable());
```

## State design

The two shapes, and when each is right:

**A sealed hierarchy** when the states are genuinely different and share little:

```dart
sealed class UserState {}
final class UserLoading extends UserState {}
final class UserLoaded extends UserState { const UserLoaded(this.user); final User user; }
final class UserFailed extends UserState { const UserFailed(this.message); final String message; }
```

Exhaustive `switch`, and impossible states cannot be constructed — `UserLoaded` always has a
user.

**A single class with `copyWith`** when the screen has several independent dimensions —
a search that has a query, results, a loading flag and an error at the same time. That is
`SearchState` in the sample. The tradeoff is that illegal combinations become representable,
so the discipline has to come from the handlers.

**Equality is not optional.** Bloc skips emitting a state equal to the current one, so
without `==` and `hashCode` — hand-written, from `equatable`, or from `freezed` — every emit
rebuilds every listener, including emits that changed nothing.

## Wiring it to widgets

```dart
BlocProvider(
  create: (context) => SearchBloc(context.read<UserRepository>()),
  child: const SearchView(),
)
```

- **`BlocBuilder`** rebuilds on state change. Use `buildWhen` to narrow it:
  `buildWhen: (prev, next) => prev.results != next.results`.
- **`BlocListener`** runs side effects — snackbars, navigation, dialogs — without rebuilding.
  Navigation inside a builder fires on every rebuild; this is the fix.
- **`BlocConsumer`** when a widget needs both.
- **`BlocSelector`** when a widget needs one field of a large state.

`BlocProvider` disposes the bloc when its widget is removed, which is the disposal story
handled for you. Providing an already-created bloc with `BlocProvider.value` does **not**
transfer ownership — you close it yourself, and forgetting is a leak.

## Testing

A bloc is a plain Dart object, so tests need no widget tree:

```dart
test('debounces a burst into a single search', () async {
  final repository = FakeUserRepository({'u1': ada});
  final bloc = SearchBloc(repository);
  addTearDown(bloc.close);

  bloc
    ..add(const SearchQueryChanged('a'))
    ..add(const SearchQueryChanged('ad'))
    ..add(const SearchQueryChanged('ada'));

  await bloc.stream.firstWhere((state) => state.results.isNotEmpty);

  expect(repository.searchCalls, 1);
});
```

That test — in `code/testing/state_management_test.dart` — is asserting the transformer, not
the repository. It is the kind of behaviour that is easy to claim and hard to verify in any
approach that does not model events as a stream.

`bloc_test` adds a declarative wrapper:

```dart
blocTest<UserCubit, UserState>(
  'emits loading then loaded',
  build: () => UserCubit(FakeUserRepository({'u1': ada})),
  act: (cubit) => cubit.load('u1'),
  expect: () => [isA<UserLoading>(), isA<UserLoaded>()],
);
```

It is convenient and it hides the async machinery, which makes debugging a failing
`blocTest` harder than debugging a plain one. Either is fine; do not mix both styles in one
file.

## BlocObserver

The feature nothing else gives you for free:

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    log('${bloc.runtimeType}: ${transition.event} -> ${transition.nextState}');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = AppBlocObserver();
  runApp(const App());
}
```

One place that sees every event and every transition in the app. Attached to your crash
reporter, it turns a bug report into a reproducible sequence of events — which is why
BLoC survives in regulated and enterprise codebases where "what did the user do" is a
requirement rather than a nice-to-have.

## The cost, stated plainly

- **Three files where Riverpod needs one.** State, events, bloc — plus the widget.
- **Event classes are ceremony** when the event carries no data and has exactly one handler.
- **Async state is manual.** Loading, error and empty are states you write and maintain;
  there is no `AsyncValue`.
- **Dependency injection is separate.** `BlocProvider` provides blocs; repositories need
  `RepositoryProvider` or `get_it`. Riverpod uses one mechanism for both.

What you get: an explicit, greppable state machine, a global event log, and precise control
over event concurrency. On a checkout flow or a regulated app, that is worth the files. On a
settings screen, it is not.

## Interview angles

**"Cubit versus Bloc?"** Cubit exposes methods and is less code; Bloc turns actions into
events, which buys `BlocObserver` traceability and event transformers. Recommend Cubit by
default and name the two reasons to upgrade.

**"When does BLoC's boilerplate pay off?"** Event-driven domains, and anywhere concurrency
matters — `restartable` for search, `droppable` for submit. Say that a Cubit cannot express
those, because that is the crisp technical difference.

**"How do you debounce in BLoC?"** A transformer on the event registration, not a timer in
the widget. Combine `debounce` with `restartable()` so the in-flight request is cancelled
too.

**"How do you test a bloc?"** Add events, assert the emitted state sequence — a plain unit
test with a fake repository, no widget tree. Mention that state equality must be implemented
or duplicate states are silently dropped.

**"Where do side effects go?"** `BlocListener`, never `BlocBuilder`. A builder runs on every
rebuild, so navigation inside one fires more than once.

## See also

- [Choosing a state management approach](state-management-choosing.md) — the decision
- [Riverpod](state-management-riverpod.md) — the alternative
- [Async and concurrency](../part-01-foundations/dart-async.md) — the debounce used above
- [Observability](../part-05-enterprise/observability.md) — `BlocObserver` into logging
