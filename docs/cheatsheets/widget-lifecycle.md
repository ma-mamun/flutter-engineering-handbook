# Widget lifecycle cheatsheet

Every callback in call order, with what belongs in it. Explanation on the
[lifecycle page](../part-01-foundations/widget-lifecycle.md).

## Call order

```text
createState
  ↓
initState                    once, before the first build
  ↓
didChangeDependencies        after initState, and on every dependency change
  ↓
build ←──────────────┐
  ↓                  │
[running]            │
  ├── setState ──────┤
  ├── new widget → didUpdateWidget ──┤
  └── dependency changed → didChangeDependencies ──┘
  ↓
deactivate                   removed from the tree
  ↓
  ├── reinserted this frame → activate → build
  └── not reinserted ↓
dispose                      last call; mounted is already false
```

## What belongs where

| Callback | Runs | Do | Never |
| --- | --- | --- | --- |
| `createState` | Once per element | Return a fresh `State` | Touch `context` or `widget` |
| `initState` | Once, before build | Controllers, subscriptions, one-shot futures | `Theme.of`, `MediaQuery.of`, `context.watch` |
| `didChangeDependencies` | After initState, and on each dependency change | Read inherited widgets, react to theme/locale | Unguarded expensive work — it fires repeatedly |
| `build` | Every dirty frame | Build widgets from state | Network calls, `setState`, timers, heavy computation |
| `didUpdateWidget` | New widget, same type and key | Re-subscribe when a widget field changed | React unconditionally — compare with `oldWidget` |
| `deactivate` | Removed from the tree | Almost nothing | Release resources — it may be reinserted |
| `activate` | Reinserted after deactivate | Re-establish anything deactivate stopped | — |
| `dispose` | Last, always | Cancel and dispose everything | `setState`, `context` |

## The dispose checklist

Anything created in `initState` or `didUpdateWidget` is released here:

```dart
@override
void dispose() {
  _subscription?.cancel();          // StreamSubscription
  _controller.dispose();            // AnimationController, TextEditingController
  _scrollController.dispose();      // ScrollController
  _focusNode.dispose();             // FocusNode
  _timer?.cancel();                 // Timer, Timer.periodic
  _debouncer.dispose();             // anything holding a Timer
  _notifier.removeListener(_onChange);            // same function reference
  WidgetsBinding.instance.removeObserver(this);   // WidgetsBindingObserver
  super.dispose();                  // last
}
```

## The mounted rule

```dart
Future<void> _save() async {
  final navigator = Navigator.of(context);        // capture BEFORE
  final messenger = ScaffoldMessenger.of(context);

  await repository.save(_form);
  if (!mounted) return;                            // guard AFTER

  navigator.pop();
  messenger.showSnackBar(const SnackBar(content: Text('Saved')));
}
```

In a widget with only a context and no `State`, use `context.mounted` (Flutter 3.7+).

## App lifecycle

Separate axis — the OS suspending and resuming the app.

| State | Meaning | Do |
| --- | --- | --- |
| `resumed` | Visible and interactive | Resume polling, refresh stale data |
| `inactive` | Transitional (call, control centre) | Nothing — it fires constantly |
| `hidden` | Not visible (all platforms, 3.13+) | Pause animations |
| `paused` | Backgrounded | Flush drafts, save cursors, stop timers |
| `detached` | Being destroyed | Nothing — **it may never run** |

Requires `WidgetsBindingObserver`, added in `initState` and **removed in `dispose`**.

## Common mistakes

| Mistake | Result |
| --- | --- |
| `Theme.of(context)` in `initState` | Throws, or silently registers no dependency |
| API call in `build` | A request per rebuild, spinner flashing |
| No `mounted` check after `await` | `setState() called after dispose()` |
| Missing `dispose` | Leak, plus a callback firing on a dead `State` |
| `didUpdateWidget` reacting unconditionally | Work restarts on every parent rebuild |
| Releasing resources in `deactivate` | Breaks when the element is reinserted |
| `setState` in `build` | Framework assertion |

## See also

- [Widget lifecycle](../part-01-foundations/widget-lifecycle.md) — the explanation
- [Memory](../part-04-production/performance-memory.md) — what a missing dispose costs
- [Anti-patterns](../part-02-professional/anti-patterns.md) — these mistakes, with mechanisms
