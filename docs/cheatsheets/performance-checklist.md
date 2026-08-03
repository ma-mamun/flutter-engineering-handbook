# Performance checklist

What to check, in order, when a screen feels slow. Explanation in
[Part 4](../part-04-production/performance-profiling.md).

## 0. Before you profile

- [ ] **Profile mode**, not debug. Debug numbers are distorted, not merely scaled.
- [ ] **A real device**, not a simulator. Prefer the slowest one you support.
- [ ] **A reproducible interaction**, written down: "scroll the order list fast with 200 items,
      Pixel 6a".
- [ ] **A number before you change anything.** Without it there is no result, only a feeling.

## 1. Which thread

DevTools → Performance → record the interaction → find the long frame.

| Long bar | Cause | Go to |
| --- | --- | --- |
| **UI** | Your Dart: build, layout, paint, parsing | Section 2 |
| **Raster** | Shaders, clips, overdraw, large images | Section 3 |
| **Both** | Usually a huge first frame | Section 5 |

Nothing below this line is worth doing before this line is answered.

## 2. UI thread

- [ ] **Rebuild scope.** Enable "Track widget builds". What rebuilds 60 times a second?
- [ ] **`const` everywhere it compiles.** Turn on `prefer_const_constructors`.
- [ ] **Widget classes, not helper methods.** A `_buildHeader()` cannot be `const`.
- [ ] **A `child` on every builder.** `AnimatedBuilder`, `ValueListenableBuilder`, `Consumer`.
- [ ] **`select` instead of watching whole objects.**
- [ ] **`setState` as low in the tree as possible.**
- [ ] **Nothing expensive in `build`** — no parsing, sorting, date formatting or `Intl`
      construction.
- [ ] **`ListView.builder`**, never a `Column` of many children in a scroll view.
- [ ] **No `shrinkWrap: true`** — use `Expanded` or slivers.
- [ ] **`itemExtent` or `prototypeItem`** when items are a fixed size.
- [ ] **Cheap `itemBuilder`.** It runs per item, per scroll.
- [ ] **CPU-bound work on an isolate** if any synchronous block exceeds ~1 ms.

## 3. Raster thread

- [ ] **Images decoded at display size** — `cacheWidth`/`cacheHeight` or `ResizeImage`.
- [ ] **`Opacity` on large subtrees replaced** by `AnimatedOpacity`, `FadeTransition`, or a
      colour with alpha.
- [ ] **Clips minimised**, especially per item in a list.
- [ ] **`BackdropFilter` sparingly**, never inside a list.
- [ ] **Shadow blur radii kept small.**
- [ ] **`RepaintBoundary` where something animates over stable content** — and verified with
      `debugRepaintRainbowEnabled`, then removed if it bought nothing.
- [ ] **Impeller enabled** (default on iOS 3.10+, Android 3.29+) for shader jank.

## 4. Memory

- [ ] **Snapshot → repeat the cycle five times → GC → snapshot → diff.**
- [ ] **Read the retaining path** of instances that should not exist. That is the answer.
- [ ] **Every `initState` acquisition released in `dispose`.**
- [ ] **`removeListener` with a method reference**, not a closure.
- [ ] **Image cache bounded** and evicted on logout.
- [ ] **Unbounded caches and static collections** given a limit.
- [ ] **Isolates closed.**

## 5. Startup

```bash
flutter run --profile --trace-startup
```

- [ ] **Nothing synchronous in `main` before `runApp`** that can be deferred.
- [ ] **SDKs initialised lazily**, not all at launch.
- [ ] **The first screen builds a shell**, with below-the-fold content deferred.
- [ ] **No large image decoded on the first frame.**

## 6. Build size

```bash
flutter build appbundle --analyze-size --target-platform android-arm64
```

- [ ] **App bundle**, or split-per-ABI. Never a universal APK.
- [ ] **Unused assets removed**; WebP over PNG/JPEG; compressed.
- [ ] **2.0x and 3.0x only.**
- [ ] **Fonts subset**, fewer weights.
- [ ] **Dependencies audited** for size with the analyze-size diff.
- [ ] **`--split-debug-info`**, symbols archived.
- [ ] **A CI check that prints the size delta per PR.**

## 7. Prove it

- [ ] **Same device, same interaction, measure again.**
- [ ] **One change at a time**, or you cannot attribute the result.
- [ ] **Write both numbers down with the device named.** "22 ms → 9 ms on a Pixel 6a."
- [ ] **An integration test asserting the 90th-percentile frame time**, so it stays fixed.

## Debug flags

```dart
debugRepaintRainbowEnabled = true;    // did this layer repaint?
debugPaintSizeEnabled = true;         // what is being laid out
debugProfileBuildsEnabled = true;     // per-widget build events
debugPrintBeginFrameBanner = true;    // frame boundaries in the log
timeDilation = 5.0;                   // slow animations to see what moves
debugDumpRenderTree();                // constraints and sizes for the whole tree
```

## Budgets

| Refresh rate | Per frame |
| --- | --- |
| 60 Hz | 16.7 ms |
| 90 Hz | 11.1 ms |
| 120 Hz | 8.3 ms |

Both threads must fit. A 12 ms UI frame is fine at 60 Hz and drops frames at 120 Hz.

## See also

- [Profiling](../part-04-production/performance-profiling.md) ·
  [Rendering](../part-04-production/performance-rendering.md) ·
  [Memory](../part-04-production/performance-memory.md) ·
  [Build size](../part-04-production/performance-build-size.md)
