# Anti-patterns

The mistakes that show up in real Flutter codebases, why each one is wrong, and the smallest
fix for each. Most of them are not stylistic — they cause crashes, leaks or dropped frames.

## Business logic inside a widget

```dart
// The widget now needs a pumpWidget to test a tax calculation.
ElevatedButton(
  onPressed: () async {
    final response = await http.post(url, body: jsonEncode(cart.toJson()));
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final total = (json['subtotal'] as num) * 1.2 + shippingFor(cart.weight);
    setState(() => _total = total);
  },
  child: const Text('Checkout'),
)
```

**Why it hurts:** the rule is untestable without a widget, unreusable on any other screen,
and invisible to anyone reading the domain. It also gets duplicated the first time a second
screen needs the same total, and the two copies drift.

**The fix:** the widget calls one method. The repository owns the request, the domain owns
the arithmetic, and the test constructs a plain object.

```dart
onPressed: () => ref.read(checkoutProvider.notifier).submit(),
```

## API calls inside build

```dart
@override
Widget build(BuildContext context) {
  final orders = repository.fetchOrders();   // a new request every rebuild
  return FutureBuilder(future: orders, ...);
}
```

**Why it hurts:** `build` can run many times a second. Every parent rebuild, orientation
change and keyboard appearance fires another request. It also flashes a spinner each time,
because the future is a new object.

**The fix:** start the future once and store it — in `initState`, or in a provider whose
lifetime the framework manages.

```dart
late final Future<List<Order>> _orders = repository.fetchOrders();  // once
```

## Nested FutureBuilders

```dart
FutureBuilder(
  future: fetchUser(),
  builder: (context, userSnap) => FutureBuilder(
    future: fetchOrders(userSnap.data!.id),   // ! on data that may not exist yet
    builder: (context, orderSnap) => ...,
  ),
)
```

**Why it hurts:** three failure modes multiply into nine branches, the inner future restarts
whenever the outer rebuilds, and the `!` throws while the outer is still loading. The
indentation alone tells you the state model is wrong.

**The fix:** compose the async work *below* the widget layer, and give the widget one state
to render.

```dart
Future<Dashboard> loadDashboard() async {
  final user = await fetchUser();
  final orders = await fetchOrders(user.id);
  return Dashboard(user: user, orders: orders);
}
```

## BuildContext after dispose

```dart
await repository.save(form);
Navigator.of(context).pop();     // the user may already be gone
```

**Why it hurts:** the context is an element, and the element can be unmounted while the
future is in flight. It never reproduces on a fast network, which is why it ships.

**The fix:** capture before, guard after.

```dart
final navigator = Navigator.of(context);
await repository.save(form);
if (!mounted) return;
navigator.pop();
```

Keep the `use_build_context_synchronously` lint on — it is the only thing that catches this
reliably. Detail in [widget lifecycle](../part-01-foundations/widget-lifecycle.md).

## setState everywhere

**Why it hurts:** `setState` marks the *whole* `State` dirty, so a keystroke in one field
rebuilds an entire page — including the list below it and every widget that was not `const`.

**The fix:** shrink the scope rather than change frameworks.

- Split the subtree that changes into its own small `StatefulWidget`.
- `ValueListenableBuilder` around just the part that depends on the value.
- `const` on everything that does not depend on state.
- For shared state, a provider with `select` so only the dependent widget rebuilds.

The related smell is `setState(() {})` with an empty body and mutation outside it — it
works, and it hides what changed from every reader.

## Huge widgets

A 900-line `build` method with six levels of nesting.

**Why it hurts:** nothing in it can be `const`, so all of it rebuilds together; nothing can
be tested in isolation; and every merge touches the same file.

**The fix:** extract **widget classes**, not helper methods.

```dart
// A method: rebuilt with the parent, never const, no separate element.
Widget _buildHeader() => Padding(...);

// A class: can be const, has its own element, rebuilds independently.
class _Header extends StatelessWidget { const _Header(); ... }
```

That distinction is not cosmetic — a `const _Header()` short-circuits the parent's rebuild
diff, and a `_buildHeader()` cannot. See
[the three trees](../part-01-foundations/flutter-three-trees.md).

## Global mutable state

A singleton anyone can read and write, from anywhere.

**Why it hurts:** no compile-time seam, so tests need global setup and depend on execution
order; changes have no traceable origin; and two features silently couple through it.

**The fix:** scope it. Inject through the constructor, or hold it in a provider whose
lifetime is tied to something real — a session, a route, the app. See
[dependency injection](dependency-injection.md).

## Overusing GlobalKey

**Why it hurts:** each one is registered app-wide, moving an element through one forces a
deactivate/reactivate cycle, `currentState` is an escape hatch out of the declarative model,
and two live widgets sharing a key is a runtime error during transitions.

**The fix:** `GlobalKey` for `Form`, for measuring a render object, and for the rare case
where no context is available. For data down, use constructor parameters; for events up, use
callbacks.

## Ignoring dispose

```dart
_controller = AnimationController(vsync: this, ...);
_subscription = stream.listen(_onData);
// no dispose
```

**Why it hurts:** both hold a closure that holds the `State`, so the whole subtree stays
alive. The callback also keeps firing, and eventually calls `setState` on a disposed state.

**The fix:** the symmetry rule — anything created in `initState` is released in `dispose`.
Enable `cancel_subscriptions` and `close_sinks` so the analyzer checks it for you.

## Catching everything and doing nothing

```dart
try {
  await sync();
} catch (_) {}
```

**Why it hurts:** the bug report you will never receive. It also catches `Error` subtypes —
programming bugs — and keeps the app running in a state you did not design.

**The fix:** catch what you expect, map it to a typed failure, and report the rest. Never
write an empty catch block. See [error handling](error-handling.md).

## Unbounded lists

```dart
SingleChildScrollView(
  child: Column(children: orders.map(OrderTile.new).toList()),  // all 2,000
)
```

**Why it hurts:** every child is built, laid out and kept in memory whether or not it is on
screen. It is the single most common cause of "the list is janky".

**The fix:** `ListView.builder`, or slivers when the list shares a scroll view with other
content. `shrinkWrap: true` is not the fix — it makes the list measure all its children,
which is the same problem.

## Images at full resolution

A 4000×3000 photo in a 100×100 avatar decodes to roughly 48 MB of memory.

**The fix:** `cacheWidth`/`cacheHeight`, or `ResizeImage`, sized to the display size times
the device pixel ratio. Ask the backend for a thumbnail where you can. See
[memory](../part-04-production/performance-memory.md).

## Premature everything

Worth naming alongside the rest, because over-engineering costs real time:

- **Clean Architecture on a prototype** — six files per feature to isolate change that is
  not coming.
- **A use case per repository method**, forwarding a single call.
- **A provider for a checkbox.**
- **`RepaintBoundary` everywhere** — each one costs GPU memory and a compositing step, so
  wrapping everything is slower, not faster.
- **Micro-optimising before profiling.** Measure in profile mode on a device first;
  otherwise you are optimising the wrong thing with confidence.

The rule that covers all five: **add structure when a specific pain appears**, not because a
diagram or an article recommended it.

## Interview angles

Anti-patterns are a favourite senior interview question because they test judgement rather
than recall. Two things make an answer strong:

1. **Name the mechanism, not the rule.** Not "don't call APIs in build" but "build runs on
   every rebuild, so each rebuild starts a new request and restarts the spinner".
2. **Give the smallest fix.** Interviewers are listening for whether you would rewrite the
   app or move three lines.

The most commonly asked: business logic in widgets, `BuildContext` after an await, nested
`FutureBuilder`s, `setState` scope, and missing `dispose`. All five are on this page with
their mechanisms.

## See also

- [Widget lifecycle](../part-01-foundations/widget-lifecycle.md) — mounted and dispose
- [Rendering performance](../part-04-production/performance-rendering.md) — rebuild scope, measured
- [Clean Architecture](clean-architecture.md) — where the logic should have gone
- [Error handling](error-handling.md) — what to do instead of swallowing
