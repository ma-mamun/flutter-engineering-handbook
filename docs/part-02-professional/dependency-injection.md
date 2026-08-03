# Dependency injection

Wiring implementations to interfaces so tests can replace them and features cannot reach
past their boundary.

## The recommendation

**Constructor injection by default.** A class takes what it needs as parameters and never
reaches out for anything. Use a container — `get_it`, or Riverpod's providers — only at the
composition root, where widgets cannot pass constructor arguments through the tree.

```dart
// Testable: the dependency is visible in the signature and replaceable in one line.
class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl({required OrderApi api, required OrderCache cache})
      : _api = api, _cache = cache;
}

// Not testable: the dependency is hidden inside the implementation.
class OrderRepositoryImpl implements OrderRepository {
  final _api = GetIt.I<OrderApi>();   // every test now needs global setup
}
```

The difference is not style. In the first version a test constructs the object with fakes
and nothing global exists. In the second, every test — including tests of classes three
levels away — needs the container registered, and forgetting produces an error at runtime
rather than a compile error.

## The composition root

One place builds the object graph, and it is the only place that imports both the interface
and the implementation:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dio = buildDio(Environment.current);
  final database = await openDatabase();

  runApp(
    ProviderScope(
      overrides: [
        orderRepositoryProvider.overrideWithValue(
          OrderRepositoryImpl(api: OrderApi(dio), cache: OrderCache(database)),
        ),
      ],
      child: const App(),
    ),
  );
}
```

Everything below this point receives what it needs. Nothing below this point knows which
implementation it got, which is what makes flavours, offline modes and integration tests a
configuration change rather than a code change.

## The three approaches

| | Constructor | `get_it` (service locator) | Riverpod providers |
| --- | --- | --- | --- |
| Dependency is visible | Yes, in the signature | No, hidden in the body | In the `ref.watch` call |
| Compile-time safety | Full | None — missing registration fails at runtime | Full, with typed providers |
| Test replacement | Pass a fake | `GetIt.I.reset()` plus re-register | `overrides` on the container |
| Scoping | Manual | Scopes, manually pushed and popped | Automatic, tied to the widget tree |
| Async dependencies | Awkward — pass a future or an initialised value | `registerSingletonAsync` | `FutureProvider`, natively |
| Works outside widgets | Yes | Yes | Yes, via `ProviderContainer` |

**Use `get_it` when** you want DI independent of the state management approach, or you have
non-widget code (background isolates, plugins) that needs the graph.
**Use Riverpod providers when** you are already using Riverpod — a second container is a
second source of truth about lifetimes.

### get_it in practice

```dart
final locator = GetIt.instance;

void configureDependencies(Environment env) {
  // Lazy: created on first resolve, then cached.
  locator.registerLazySingleton<Dio>(() => buildDio(env));
  locator.registerLazySingleton<OrderApi>(() => OrderApi(locator<Dio>()));
  locator.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(api: locator(), cache: locator()),
  );

  // Factory: a new instance per resolve. Right for anything holding per-use state.
  locator.registerFactory<OrderNotifier>(() => OrderNotifier(locator()));
}
```

Three rules that keep a service locator from becoming a global variable with a nicer name:

1. **Resolve at construction, not at use.** Widgets and repositories should still take
   constructor parameters; the locator supplies them at the composition root.
2. **Register interfaces, not implementations.** `registerLazySingleton<OrderRepository>`,
   never `<OrderRepositoryImpl>`, or the point is lost.
3. **Reset between tests.** `setUp(() => locator.reset())`, or state leaks across tests and
   produces the worst kind of flake — order-dependent failures.

`injectable` generates the registrations from annotations. It removes boilerplate and adds a
`build_runner` step; worth it past roughly thirty registrations, noise below that.

## Scoping and lifetimes

Getting lifetimes wrong is how DI leaks memory and how one user's data appears in another's
session.

| Lifetime | Right for | Wrong for |
| --- | --- | --- |
| App singleton | HTTP client, database, analytics | Anything holding user session state |
| Session-scoped | Auth token, current user, per-user cache | Global config |
| Feature/route-scoped | A wizard's in-progress state | Anything the next screen needs |
| Per-use factory | Notifiers, blocs, controllers | Expensive shared clients |

On logout, **dispose the session scope** rather than clearing fields one by one. With
`get_it` that is `pushNewScope`/`popScope`; with Riverpod it is invalidating the providers
that depend on the auth state, which happens automatically when the auth provider changes.
Manual field clearing is how the previous user's cached orders end up on the next user's
screen — the field somebody forgot.

## The testing seam

The whole point, in one test:

```dart
final container = ProviderContainer(
  overrides: [
    userRepositoryProvider.overrideWithValue(FakeUserRepository({'u1': ada})),
  ],
);
addTearDown(container.dispose);
```

That is from `code/testing/state_management_test.dart`, and it runs with no network, no
plugins, and no widget tree. The equivalent with constructor injection is
`UserCubit(FakeUserRepository(...))` — even simpler, which is why constructor injection is
the default recommendation.

**Fakes over mocks** wherever the interface is small enough. A fake is a real implementation
with simple behaviour, so it stays honest when the interface changes and reads as data
rather than as setup. Reach for a mock when you need to assert *how* something was called —
"exactly one request", "cancelled on dispose".

## Anti-patterns

**Service locator inside `build`.** `GetIt.I<Repository>()` in a build method resolves on
every rebuild and hides the dependency from the widget's signature. Resolve once, in the
constructor or in `initState`.

**Passing `BuildContext` into the domain.** A repository that takes a context can reach the
widget tree, the theme and the navigator — it is now untestable outside a `pumpWidget`, and
it will crash after the context is unmounted.

**A God container.** One `AppState` object holding every repository, injected everywhere.
Everything depends on everything, no test can construct a subset, and the file is a
permanent merge conflict.

**Registering concrete types.** If the container hands out `OrderRepositoryImpl`, the
interface is decorative and nothing can be swapped.

## Interview angles

**"How do you do dependency injection in Flutter?"** Constructor injection by default,
wired at a composition root, with a container only where constructors cannot reach. Then
name the seam it buys: flavours, offline modes, and tests that need no network.

**"get_it versus Riverpod for DI?"** `get_it` is a service locator — flexible, framework
independent, and resolves at runtime with no compile-time guarantee. Riverpod providers are
typed, scoped to the widget tree, and override cleanly in tests, but tie DI to the state
management choice.

**"How do you test a class with dependencies?"** Pass fakes through the constructor. If you
cannot, the class is reaching for its dependencies instead of receiving them, and that is
the bug to fix before writing the test.

**"How do you handle logout?"** Dispose the session scope, so every per-user object is
rebuilt on next login. Clearing fields by hand leaks the one you forget.

## See also

- [Clean Architecture](clean-architecture.md) — why the interface lives in the domain
- [Project structure](project-structure.md) — where the composition root sits
- [Riverpod](state-management-riverpod.md) — providers as both state and DI
- [Unit tests](testing-unit.md) — fakes versus mocks in practice
