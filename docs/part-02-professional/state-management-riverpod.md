# Riverpod

Providers, notifiers, and the patterns that keep a large provider graph readable.

Written against `flutter_riverpod` 3.4. Riverpod 3 renamed and removed enough API that
tutorials written for 2.x will mislead you — check the version before copying anything.

## The recommendation

Use `AsyncNotifier` for state that loads, `Notifier` for state that does not, and plain
`Provider` for everything derived or injected. Watch in `build`, read in callbacks, and
never put a `BuildContext` in a notifier. Everything else on this page is detail.

## The provider types

| Provider | Holds | Use for |
| --- | --- | --- |
| `Provider` | A computed or injected value | Repositories, config, derived values |
| `FutureProvider` | A one-shot async value | Read-only data with no mutations |
| `StreamProvider` | A stream of values | Database watches, sockets, auth state |
| `NotifierProvider` | Sync state with methods | Filters, form state, selection |
| `AsyncNotifierProvider` | Async state with methods | The common case: load, then mutate |
| `.family` | One instance per argument | Per-id state — a details screen |
| `.autoDispose` | State disposed when unwatched | Anything scoped to a screen |

The version that matters in production code:

```dart
--8<-- "architecture/riverpod_user.dart"
```

Three things that sample is showing:

- **`ref.watch` inside `build` creates the graph.** Change `currentUserIdProvider` and the
  notifier re-runs, with loading and error handled — that handling is most of what a
  hand-rolled `ChangeNotifier` spends its lines on.
- **The repository provider throws by default.** A forgotten override fails loudly at
  startup rather than silently using a stub in production.
- **Optimistic update with rollback.** The UI moves first, and the previous value is
  restored when the server rejects it. Same shape as an offline mutation — see
  [offline first](../part-03-data/offline-first.md).

## watch, read and listen

The single most common source of Riverpod bugs.

| | Use in | Rebuilds on change | Use for |
| --- | --- | --- | --- |
| `ref.watch` | `build`, and provider bodies | Yes | Reading state you render |
| `ref.read` | Callbacks — `onPressed`, `initState` | No | Firing an action, one-off reads |
| `ref.listen` | `build`, as a side-effect hook | No, runs a callback | Snackbars, navigation, dialogs |

```dart
class OrderPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);          // rebuilds on change

    ref.listen(ordersProvider, (previous, next) {      // side effects, not rebuilds
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(...));
      }
    });

    return RefreshIndicator(
      // read: this is a callback, and watching here would be a rebuild loop
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
      child: orders.when(...),
    );
  }
}
```

**`ref.read` in `build` is almost always a bug**: the widget shows a value and never updates.
**`ref.watch` in a callback is worse**: it can create a dependency that rebuilds on every
tap. And navigation or a snackbar inside `build` runs on every rebuild — that is what
`ref.listen` exists to prevent.

## AsyncValue

`AsyncValue` is the union you would otherwise hand-roll, and its details matter:

```dart
switch (ordersState) {
  AsyncData(:final value) => OrderList(orders: value),
  AsyncLoading() => const CenteredSpinner(),
  AsyncError(:final error) => RetryPanel(error: error),
}
```

- **`value` is retained during a refresh.** `isRefreshing` plus the previous data is what
  lets pull-to-refresh keep showing the list instead of flashing a spinner.
- **`when` versus a `switch`.** Both work; a `switch` with patterns is exhaustive at compile
  time, which is the Dart 3 idiom this handbook prefers.
- **Errors are captured, not thrown.** An exception in `build` becomes `AsyncError`, so a
  failing load never takes down the widget tree.

## Scoping and disposal

**`autoDispose`** destroys state when the last listener goes away — the default worth
preferring for anything tied to a screen. Without it, a details screen's state for every
product the user has ever opened stays in memory for the session.

```dart
final orderProvider = AsyncNotifierProvider.autoDispose<OrderNotifier, Order>(
  OrderNotifier.new,
);
```

Two controls worth knowing:

- **`ref.keepAlive()`** inside a provider pins it after a successful load, so navigating back
  and forth does not refetch.
- **`ref.onDispose`** registers cleanup — cancel a subscription, close a socket. This is the
  `dispose` half of the pairing, and Riverpod calling it for you is a large part of why the
  leak class disappears.

For a per-argument instance, use a family. For state scoped to a subtree — a wizard, a
tenant, a locale — override the provider in a nested `ProviderScope`, which is the same
mechanism tests use.

## Testing

No widgets required:

```dart
final container = ProviderContainer(
  overrides: [
    userRepositoryProvider.overrideWithValue(FakeUserRepository({'u1': ada})),
    currentUserIdProvider.overrideWithValue('u1'),
  ],
);
addTearDown(container.dispose);

expect(container.read(userProvider), isA<AsyncLoading<User>>());
expect(await container.read(userProvider.future), ada);
```

`addTearDown(container.dispose)` is not optional — an undisposed container keeps its
providers, and their subscriptions, alive across tests. The full set, including the
optimistic-rollback test, is in `code/testing/state_management_test.dart`.

For widget tests, wrap in `ProviderScope(overrides: [...])` and everything below sees the
fakes.

## Anti-patterns

**A `BuildContext` in a notifier.** It cannot be unit tested and it will outlive its
element. Return state; let the widget navigate.

**Business logic in the widget, state in the provider.** If `onPressed` computes a total,
validates it, and then calls `setTotal`, the logic is untestable. Move the verb into the
notifier and let the widget call one method.

**A provider that watches everything.** `ref.watch(appStateProvider)` for one field rebuilds
on every unrelated change. Use `select`:

```dart
final name = ref.watch(userProvider.select((u) => u.value?.name));
```

**Creating providers inside `build`.** A provider is a global, immutable declaration. Created
in `build`, it is a new provider every frame, so state resets constantly.

**One giant provider.** A single `appProvider` holding user, cart, settings and feed
rebuilds every consumer on every change and cannot be tested in parts. Split by lifetime and
by what changes together.

**Ignoring `autoDispose`.** The default is to keep state forever. On a details screen reached
from a list, that is a slow leak the user creates by scrolling.

## Code generation

`riverpod_generator` replaces the declarations with annotations:

```dart
@riverpod
Future<User> user(Ref ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.byId(ref.watch(currentUserIdProvider)).unwrap();
}
```

It removes the type-parameter noise, makes families ordinary function parameters, and keeps
`autoDispose` on by default. The cost is a `build_runner` step in every developer's loop.
Worth it above roughly twenty providers; noise below that.

## Interview angles

**"What does Riverpod fix about Provider?"** Compile-time safety instead of runtime lookup,
no `BuildContext` requirement, `AsyncValue` for loading and error states, and automatic
disposal. Mention that it is by the same author, which is the strongest form of the argument.

**"`watch` versus `read`?"** `watch` subscribes and rebuilds — use it in `build`. `read` is a
one-off — use it in callbacks. `listen` runs a side effect without rebuilding, which is where
snackbars and navigation belong.

**"How do you test a notifier?"** `ProviderContainer` with overrides, disposed in a teardown.
No widget tree, no network. That is the whole answer, and the fact it is short is the point.

**"How do you avoid unnecessary rebuilds?"** `select` to depend on one field, split providers
by what changes together, and `autoDispose` so dead state is not recomputed.

## See also

- [Choosing a state management approach](state-management-choosing.md) — the decision
- [BLoC](state-management-bloc.md) — the alternative, and when it wins
- [Dependency injection](dependency-injection.md) — providers as a DI container
- [Anti-patterns](anti-patterns.md) — the failures that are not Riverpod-specific
