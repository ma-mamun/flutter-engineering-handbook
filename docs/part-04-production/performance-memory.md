# Memory

Leaks, retained images, and reading the memory view without guessing.

## The recommendation

**Every leak in a Flutter app is something that outlived the widget that created it.** A
timer, a stream subscription, an animation controller, a listener on a global object. The fix
is always the same shape — release in `dispose` what you acquired in `initState` — and the
way to find them is a heap snapshot diff, not intuition.

## What a leak looks like

Dart is garbage collected, so a "leak" means an object is still *reachable* from a root when
it should not be. The chain is nearly always the same:

```text
Timer (alive, scheduled)
  -> the closure passed to it
    -> `this`, the State object
      -> its Element
        -> the whole subtree below it
```

One uncancelled timer retains an entire page. That is why memory climbs by a fixed amount
every time the user opens and closes a screen — the classic signature, and the one to look
for when someone says "the app gets slower the longer it runs".

## The usual sources

| Source | The mistake | The fix |
| --- | --- | --- |
| `Timer` / `Timer.periodic` | Never cancelled | `_timer?.cancel()` in `dispose` |
| `StreamSubscription` | Never cancelled | `_sub?.cancel()`; enable `cancel_subscriptions` |
| `StreamController` | Never closed | `close()`; enable `close_sinks` |
| `AnimationController`, `Ticker` | Never disposed | `dispose()`, and use `SingleTickerProviderStateMixin` |
| `TextEditingController`, `FocusNode`, `ScrollController` | Never disposed | `dispose()` |
| `addListener` on a shared notifier | Never removed | `removeListener` with the *same* function reference |
| `WidgetsBindingObserver` | Never removed | `removeObserver(this)` in `dispose` |
| A `GlobalKey` held in a long-lived object | Retains the element | Scope the key to the widget's lifetime |
| A static or singleton cache | Grows unbounded | Bound it — see [LRU](../part-01-foundations/dart-language-essentials.md#collections) |
| An isolate | Never killed | `worker.close()` |

The listener case has a subtlety worth knowing: `removeListener` compares by identity, so
`addListener(() => _onChange())` can never be removed — the closure is a new object each time.
Register a method reference (`addListener(_onChange)`) instead.

## Finding one with DevTools

The workflow that works, in profile mode on a real device:

1. Open **Memory**, and let the app settle on a stable screen.
2. **Take a snapshot.** This is the baseline.
3. **Do the suspect cycle several times** — open the screen, go back, repeat five times. Doing
   it more than once is what makes the leak stand out from noise.
4. Return to the same stable screen, press **GC**, and **take a second snapshot**.
5. **Diff the snapshots.** Five instances of `_OrderPageState` that should be zero is the
   leak, stated plainly.
6. **Select the retained instance and read the retaining path.** It names the object holding
   it — the timer, the subscription, the listener. That path is the answer; everything before
   this step was just locating it.

Two things that make the numbers readable: **press GC before snapshotting**, or you are
measuring garbage that has not been collected yet, and **watch the trend across cycles**
rather than the absolute number — Dart's heap grows in steps and a single rising line means
nothing.

## The image cache

Images are usually the largest thing in a Flutter app's memory, and they are cached
separately from the Dart heap:

```dart
// Defaults: 1000 images or 100 MB, whichever comes first.
PaintingBinding.instance.imageCache
  ..maximumSize = 200
  ..maximumSizeBytes = 50 << 20;   // 50 MB
```

The rules that matter more than the numbers:

- **Decode at display size.** A 4000×3000 photo in a 100×100 avatar occupies roughly 48 MB
  decoded regardless of the file size on disk. `cacheWidth`/`cacheHeight` or `ResizeImage`
  fixes it, and it is the single biggest memory win in most apps.
- **The cache holds decoded bitmaps**, so its cost is width × height × 4 bytes, not the JPEG
  size. A 2 MB file can be 40 MB in memory.
- **`evict` on logout** or when switching accounts, so one user's images are not held while
  another is signed in.
- **Do not raise the limits to fix jank.** A larger cache trades an out-of-memory kill for a
  decode. On low-end Android, the kill is the more likely outcome.

## Leak detection in tests

The cheapest way to keep leaks from coming back is to fail the build when one appears.

`flutter_test` (3.16+) can track disposable objects created during a test:

```dart
testWidgets('OrderPage disposes its controllers', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: OrderPage()));
  await tester.pumpWidget(const SizedBox.shrink());
  // The binding asserts that every Ticker created was disposed.
}, semanticsEnabled: false);
```

`leak_tracker` goes further and reports objects not disposed and not garbage collected after
a test. Turn it on for the widgets that own resources and treat a new leak as a failing test,
not a warning.

The pattern that catches the most, and needs no package: pump a widget, pump it away, and
assert that whatever it registered is gone — a controller's `hasListeners` is false, a fake
repository saw a `cancel`, a timer count is zero.

## Reading platform memory

Dart heap is not the whole picture. On Android, `adb shell dumpsys meminfo <package>` splits
Java heap, native heap, graphics and code — a Flutter app's *graphics* section is where image
and layer memory shows up, and a rising graphics number with a flat Dart heap points at the
image cache or too many layers rather than at your objects.

On iOS, Instruments' Allocations and VM Tracker do the same job. Xcode's memory gauge is
enough to notice a trend; Instruments is what tells you what.

## Interview angles

**"How do you detect a memory leak?"** Snapshot, repeat the suspect cycle several times, GC,
snapshot again, diff, and read the retaining path of the instances that should not be there.
The retaining path is the answer — everything else is locating.

**"What are the common leak sources in Flutter?"** Anything created in `initState` and not
released in `dispose`: timers, subscriptions, controllers, observers, listeners. Add the
identity detail about `removeListener` and closures — it shows you have actually chased one.

**"Why does memory grow each time a screen opens?"** Something in that screen is retained by
a longer-lived object, so the whole element subtree stays reachable. Give the timer → closure
→ State → element chain.

**"How do you reduce image memory?"** Decode at display size, ask the backend for thumbnails,
bound the cache, and evict on logout. Mention that decoded size is width × height × 4, not
the file size — that is the number people get wrong.

## See also

- [Widget lifecycle](../part-01-foundations/widget-lifecycle.md) — the dispose symmetry rule
- [Profiling](performance-profiling.md) — profile mode and the DevTools workflow
- [Rendering performance](performance-rendering.md) — image sizing from the frame angle
- [Anti-patterns](../part-02-professional/anti-patterns.md) — ignoring dispose
