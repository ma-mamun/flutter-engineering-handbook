# Navigation

Declarative routing, deep links, and keeping navigation something you can test.

## The recommendation

**`go_router` with a route table declared in one file.** Routes are data, guards are one
`redirect` function, and deep links are the same code path as in-app navigation. Use raw
`Navigator.push` only for things that are genuinely not addressable — a confirmation dialog,
a bottom sheet, a photo viewer opened from a specific widget.

## Navigator 1.0 versus 2.0

| | Navigator 1.0 (`push`/`pop`) | Declarative (Navigator 2.0, go_router) |
| --- | --- | --- |
| Model | Imperative stack operations | The stack is a function of state |
| Deep links | Manual parsing and a chain of pushes | The URL *is* the state |
| Web URLs | Do not reflect the screen | Correct by construction |
| Auth guarding | A check in every entry point | One `redirect` |
| Complexity | Low | Moderate — a real learning cost |

Navigator 1.0 is not deprecated and is still right for dialogs and sheets. What it cannot do
well is answer "the user opened `myapp://orders/42` from a push notification while logged
out" — that needs a rebuildable stack, which is exactly what the declarative API provides.

Raw Navigator 2.0 (`RouterDelegate`, `RouteInformationParser`) is powerful and unpleasant to
write by hand; roughly two hundred lines of boilerplate before the first screen. `go_router`
is the officially maintained wrapper, and it is the pragmatic answer.

## A route table

```dart
final router = GoRouter(
  initialLocation: '/orders',
  refreshListenable: authNotifier,        // re-runs redirect when auth changes
  redirect: (context, state) {
    final loggedIn = authNotifier.isLoggedIn;
    final goingToLogin = state.matchedLocation == '/login';

    if (!loggedIn && !goingToLogin) {
      // Remember where they were headed so login can return them there.
      return '/login?from=${Uri.encodeComponent(state.matchedLocation)}';
    }
    if (loggedIn && goingToLogin) {
      return state.uri.queryParameters['from'] ?? '/orders';
    }
    return null;                          // null means "no redirect"
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    ShellRoute(
      // The shell (bottom nav, side rail) is built once and survives tab changes.
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/orders',
          builder: (_, __) => const OrdersPage(),
          routes: [
            GoRoute(
              path: ':id',                // /orders/42 — nested, so back goes to the list
              builder: (_, state) => OrderPage(id: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
  ],
  errorBuilder: (_, state) => NotFoundPage(location: state.uri.toString()),
);
```

Four things that page carries:

- **Nesting expresses the back stack.** `/orders/42` as a child of `/orders` means back goes
  to the list, including when the route was opened from a cold-start deep link.
- **`ShellRoute` keeps persistent chrome.** The bottom bar is not rebuilt per tab, and each
  branch can keep its own navigation state with `StatefulShellRoute`.
- **`redirect` is the only guard.** One function, not a check in every screen's `initState`.
- **`refreshListenable`** re-evaluates redirects when auth changes, so logging out from any
  screen bounces to login without a manual `pop` chain.

## Typed routes

String paths are typos waiting to happen. `go_router_builder` generates typed routes from
annotations:

```dart
@TypedGoRoute<OrderRoute>(path: '/orders/:id')
class OrderRoute extends GoRouteData {
  const OrderRoute({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) => OrderPage(id: id);
}

// Call site: a rename is a compile error, not a 404 in production.
const OrderRoute(id: '42').go(context);
```

The cost is a `build_runner` step. On any app with more than a dozen routes it pays for
itself the first time a path changes.

## Deep links and app links

Routing is only half of it; the platform has to hand you the URL in the first place.

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="example.com" />
</intent-filter>
```

plus `assetlinks.json` served from `https://example.com/.well-known/assetlinks.json` with
your signing certificate's SHA-256 fingerprint.

**iOS** — the Associated Domains capability with `applinks:example.com`, plus
`apple-app-site-association` served from the same well-known path, as JSON, with no file
extension and no redirect.

The failure mode is identical on both platforms and worth knowing before you spend a day on
it: **the link opens the browser instead of the app.** Nearly always one of — the
well-known file is not reachable over HTTPS without a redirect, the fingerprint is for the
debug key rather than the upload key, or the OS cached a failed verification and needs a
reinstall. Verify with `adb shell pm get-app-links <package>` and Apple's
`swcd` diagnostics rather than by guessing.

Also decide **what a link means when the user is logged out**: store the target, run the
login flow, then continue. That is the `from` parameter in the route table above, and it is
the part most implementations forget.

## Passing data between routes

**Pass identifiers, not objects.** A route that takes an `Order` cannot be restored from a
cold-start deep link, because there is no order to pass — the URL only carries an id.

```dart
// Restorable from a URL.
context.go('/orders/42');

// Not restorable: works from the list, crashes from a notification.
context.go('/orders/detail', extra: order);
```

`extra` is fine as an optimisation — pass the object *and* the id, render immediately from
`extra` when present, and load by id when it is not. That is the only shape that works from
both entry points.

## Testing navigation

Routing is logic, and logic is testable without a device:

```dart
testWidgets('an unauthenticated deep link lands on login and returns', (tester) async {
  final auth = FakeAuth(loggedIn: false);
  final router = buildRouter(auth);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  router.go('/orders/42');
  await tester.pumpAndSettle();
  expect(find.byType(LoginPage), findsOneWidget);

  auth.logIn();                       // refreshListenable fires
  await tester.pumpAndSettle();
  expect(find.byType(OrderPage), findsOneWidget);
});
```

Extract `buildRouter(auth)` as a function rather than a global, so each test gets a fresh
router. A global `GoRouter` is a shared mutable state bug in every test after the first.

## Common mistakes

- **`Navigator.of(context)` after an `await`** without a `mounted` check. The most common
  navigation crash — see [widget lifecycle](../part-01-foundations/widget-lifecycle.md).
- **Guarding in `initState`** instead of `redirect`. It runs after the screen builds, so the
  user sees a flash of protected content, and every new screen has to remember to do it.
- **Mixing `push` and `go` carelessly.** `go` replaces the location; `push` stacks on top.
  Using `go` for a detail screen loses the back button.
- **Rebuilding the router in `build`.** Recreates all the state on every rebuild. Build it
  once, outside the widget tree.

## Interview angles

**"Navigator 1.0 versus 2.0?"** Imperative stack operations versus a stack derived from
state. The reason 2.0 exists is deep links and web URLs — cases where the app must construct
a stack it was not navigated through.

**"How do you handle deep links?"** Declarative routes so the URL is the state, platform
configuration on both sides with the well-known files, and a stored redirect target for the
logged-out case. Mention verifying with `adb shell pm get-app-links`.

**"How do you guard a route?"** One `redirect` with a `refreshListenable` on the auth state,
not a check per screen. Say why: guards in `initState` flash protected content and are
forgotten on the next new screen.

**"Why pass ids instead of objects?"** So the route can be rebuilt from a URL on cold start.

## See also

- [Project structure](project-structure.md) — where the router lives
- [Widget lifecycle](../part-01-foundations/widget-lifecycle.md) — context after an await
- [Riverpod](state-management-riverpod.md) — auth state driving `refreshListenable`
- [Release process](../part-04-production/release-process.md) — verifying links per flavour
