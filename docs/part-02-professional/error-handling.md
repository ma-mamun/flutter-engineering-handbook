# Error handling

Turning failures into values where it helps, and making sure nothing fails silently
anywhere else.

## The recommendation

**Exceptions inside a layer, `Result` at layer boundaries.** Inside the data layer, let dio
and the database throw — that is what they do. At the boundary where the data layer answers
the domain, convert every throw into a typed value the signature admits. Then the domain and
the presentation layer handle failure as data, and the compiler checks that they did.

```dart
--8<-- "dart/result.dart"
```

## Why the boundary is the right place

A signature like `Future<User> fetchUser()` tells a caller nothing about what can go wrong.
Every call site has to guess whether to wrap it in a `try`, and the guess is usually "no",
which is how a `SocketException` reaches a widget and becomes a red screen.

`Future<Result<User>>` puts failure in the type. The caller cannot get the user without
deciding what happens when there isn't one, and an exhaustive `switch` means adding a new
failure mode breaks every incomplete handler at compile time.

**The cost:** every call site unwraps, and unwrapping is noise when there is nothing useful
to do with the failure. That is why the recommendation is *boundaries*, not everywhere.
Inside a function, `try`/`catch` is clearer and shorter.

## A failure taxonomy worth having

Errors from the network are not one thing, and mapping them once beats string-matching in
widgets:

```dart
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

final class NetworkFailure extends AppFailure {          // no connection, DNS, timeout
  const NetworkFailure([super.message = 'No connection']);
}
final class ServerFailure extends AppFailure {           // 5xx — retry may help
  const ServerFailure(super.message, this.statusCode);
  final int statusCode;
}
final class UnauthorizedFailure extends AppFailure {     // 401/403 — re-auth
  const UnauthorizedFailure([super.message = 'Session expired']);
}
final class ValidationFailure extends AppFailure {       // 422 — show per field
  const ValidationFailure(super.message, this.fieldErrors);
  final Map<String, String> fieldErrors;
}
final class CacheFailure extends AppFailure {
  const CacheFailure([super.message = 'Cache unavailable']);
}
final class UnexpectedFailure extends AppFailure {       // the bucket you must report
  const UnexpectedFailure(super.message, this.error, this.stackTrace);
  final Object error;
  final StackTrace stackTrace;
}
```

The mapping happens once, in the data layer, usually in a dio interceptor or a small
`mapDioException` function. After that no widget parses an error string, and the UI decides
what to show by switching over a closed set:

```dart
String messageFor(AppFailure failure) => switch (failure) {
      NetworkFailure() => 'You are offline. We will retry automatically.',
      UnauthorizedFailure() => 'Please sign in again.',
      ValidationFailure(:final message) => message,
      ServerFailure(statusCode: >= 500) => 'Something broke on our side.',
      _ => 'Something went wrong.',
    };
```

Two rules for these messages: **never show a raw exception to a user**, and **never discard
one from your logs**. `UnexpectedFailure` carries the original error and stack trace for
exactly that reason.

## What to catch, and what not to

```dart
try {
  return await api.fetch();
} on DioException catch (e) {
  return Failure(mapDioException(e), e.stackTrace);   // expected, mapped
} on FormatException catch (e, s) {
  return Failure(const UnexpectedFailure('bad payload'), s);  // a bug: report it
}
```

- **Catch `Exception` subtypes you expect.** Network, parsing, database.
- **Do not catch `Error`.** `StateError`, `TypeError`, `LateInitializationError` and
  assertion failures are programming bugs. Catching them hides the bug and keeps the app
  running in a state you did not design.
- **Never write a bare `catch (e) {}`.** A swallowed error is a bug report you will never
  receive. If you must catch broadly, log and rethrow, or convert to `UnexpectedFailure` and
  report it.
- **Preserve the stack trace.** `catch (e, s)` and pass `s` along, or `rethrow` — never
  `throw e`, which resets the trace to the current line.

## Catching what escapes

Three handlers, all installed in `main`, covering the three ways an error reaches the top:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 1. Errors thrown inside the framework: build, layout, paint, gestures.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);              // keep the console output
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // 2. Errors from the platform side and from outside the Flutter zone.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;   // handled — false lets it crash the process
  };

  runApp(const App());
}
```

`PlatformDispatcher.instance.onError` (Flutter 3.3+) replaces the old
`runZonedGuarded(runApp, ...)` wrapper for most cases and is simpler — no zone mismatch
between the binding and the app. Keep `runZonedGuarded` only if you have async work outside
the widget tree that must be captured in the same zone.

**Test that reporting works before you need it.** Throw deliberately from a debug-only
button, confirm the report arrives with a symbolicated stack, and confirm it is *not*
sampled away. A crash reporter nobody has verified is a checkbox, not a safety net. See
[observability](../part-05-enterprise/observability.md).

## Error boundaries in the widget tree

A thrown error during `build` produces the grey-or-red error widget. In release, replace it
with something a user can act on:

```dart
ErrorWidget.builder = (FlutterErrorDetails details) {
  if (kReleaseMode) {
    return const FriendlyErrorTile();   // stay inside the layout, no red
  }
  return ErrorWidget(details.exception); // loud in debug, where you want it loud
};
```

This is cosmetic, not a recovery mechanism — the subtree that threw is gone. For real
recovery, keep failure in the state model so the screen can render a retry:

```dart
switch (state) {
  AsyncData(:final value) => OrderList(orders: value),
  AsyncLoading() => const CenteredSpinner(),
  AsyncError(:final error) => RetryPanel(
      message: messageFor(error as AppFailure),
      onRetry: () => ref.invalidate(ordersProvider),
    ),
}
```

Every screen that loads anything needs all three branches. A design that only specifies the
happy path is an incomplete design, and asking for the empty, loading and error states early
is one of the highest-value habits a senior engineer brings to a team.

## Async errors that go nowhere

```dart
// The error surfaces asynchronously with a stack that points at the framework.
repository.sync();

// One of these, always.
unawaited(repository.sync().catchError(_report));
await repository.sync();
```

Keep the `unawaited_futures` lint on. It is the only thing that reliably catches the
fire-and-forget call whose failure nobody sees, and it makes the deliberate case explicit.

For streams, decide `cancelOnError` consciously — the default of `true` terminates the
subscription on the first error, which is right for a one-shot and wrong for a long-lived
watch that should survive a transient failure.

## Interview angles

**"Result or exceptions?"** Both, at different scopes: exceptions inside a layer, `Result`
at boundaries where the caller must decide. Give the reason — a signature that hides failure
makes every call site guess — and the cost: unwrapping noise if you use it everywhere.

**"How do you catch every error in a Flutter app?"** `FlutterError.onError` for framework
errors, `PlatformDispatcher.instance.onError` for everything else, both wired to a crash
reporter in `main`. Mention verifying the pipeline with a deliberate crash.

**"What do you do with an error in a widget?"** Nothing clever — the failure belongs in the
state, so the screen can render a retry. `ErrorWidget.builder` only changes what the broken
subtree looks like.

**"Why never catch `Error`?"** `Error` subtypes signal programming bugs. Catching them keeps
the app alive in an undefined state and hides the defect from your crash reports.

## See also

- [Dart language essentials](../part-01-foundations/dart-language-essentials.md) — sealed classes
- [Networking](../part-03-data/networking.md) — mapping dio exceptions
- [Async and concurrency](../part-01-foundations/dart-async.md) — errors across an `await`
- [Observability](../part-05-enterprise/observability.md) — symbolication and alerting
