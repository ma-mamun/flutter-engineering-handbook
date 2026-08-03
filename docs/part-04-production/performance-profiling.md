# Profiling

A repeatable workflow: reproduce, measure, change one thing, measure again. Mostly about
measuring.

## The recommendation

**Never optimise from a hypothesis.** Reproduce the problem in profile mode on a real
low-to-mid-range device, record it, read which thread is over budget, change exactly one
thing, and record again. Report numbers with the device named. Every step of that sentence is
load-bearing, and skipping any one of them is how an afternoon goes into an optimisation that
changed nothing.

## Profile mode, and why debug numbers are worthless

| Mode | Compilation | Assertions | Use for |
| --- | --- | --- | --- |
| Debug | JIT | On | Development, hot reload |
| Profile | AOT + tracing | Off | **All measurement** |
| Release | AOT | Off | Shipping |

Debug mode is often several times slower than release, and unevenly so: the parts that use
assertions and the JIT are penalised more than the rest, which means debug numbers do not
just have an offset — they have a *distorted shape*. An optimisation that helps in debug can
do nothing in release.

```bash
flutter run --profile                     # measurement build
flutter run --profile --trace-startup     # plus a startup trace written to disk
```

Two more rules that make numbers comparable:

- **A real device, not a simulator.** The iOS simulator uses your Mac's CPU and GPU; it
  cannot tell you anything about a phone. Prefer the *slowest* device you support, because
  that is where the problem is visible.
- **Same device, same build, same interaction, before and after.** A number without a named
  device is not a result.

## The workflow

**1. Reproduce deterministically.** A jank you cannot trigger on demand cannot be measured.
Write down the exact steps: "scroll the order list fast with 200 items loaded, on a Pixel 6a".

**2. Record.** DevTools → **Performance** → record → do the interaction → stop.

**3. Read which bar is long.** This is the branch point, and the fixes have nothing in common:

| Long bar | Meaning | Look at |
| --- | --- | --- |
| **UI** | Your Dart, build, layout, paint | Rebuild scope, work in `build`, parsing |
| **Raster** | Shaders, clips, overdraw, large images | Effects, image sizes, `saveLayer` |
| **Both** | Usually a huge first frame | Deferring work off startup |

**4. Find the cause inside that bar.** Expand the frame: it breaks down into build, layout,
paint and raster. Enable **Track widget builds** to see which widgets rebuilt and how often —
the widget rebuilding 60 times a second is usually the answer, and it is usually not the one
you suspected.

**5. Change one thing.** One `const`, one `RepaintBoundary`, one `select`. Two changes at
once and you cannot attribute the result — and one of them is often a regression the other
one masks.

**6. Measure again, and write both numbers down.** "22 ms → 9 ms on a Pixel 6a, scrolling 200
orders." That sentence is the deliverable. "Feels smoother" is not.

## The tools, and what each answers

**Performance view** — frame timeline. Answers *which thread and which phase*. Start here,
always.

**CPU profiler** — where Dart time goes, as a flame chart or a bottom-up table. Answers
*which function*. Record the specific interaction, not the whole session, or the signal
drowns.

**Memory view** — heap, allocations, and snapshot diffing. Answers *what is retained and by
whom*. See [memory](performance-memory.md).

**Widget rebuild stats** — count of rebuilds per widget per frame. Answers *what is rebuilding
that should not be*, and it is the fastest path to a rendering fix.

**`Timeline.timeSync`** — your own named spans in the timeline:

```dart
Timeline.timeSync('parseFeed', () => parseFeed(payload));
```

Wrap the code you suspect and the timeline stops being a guess. Cheap in profile mode,
compiled out of release.

**Performance overlay** — two graphs on the device, UI and raster, with a red bar per frame
that missed budget. Toggle it from DevTools for a quick pass with no recording.

```dart
MaterialApp(showPerformanceOverlay: true, ...)
```

## Frame budgets

| Refresh rate | Budget per frame |
| --- | --- |
| 60 Hz | 16.7 ms |
| 90 Hz | 11.1 ms |
| 120 Hz | 8.3 ms |

Both threads have to fit. A 12 ms UI frame is fine at 60 Hz and dropped frames on a 120 Hz
device — which is why testing on a high-refresh device catches problems a 60 Hz device hides,
and why the target must be stated with the rate.

## Startup time

Startup is measured differently and is worth its own pass, because it is the one performance
number every user experiences:

```bash
flutter run --profile --trace-startup
```

The trace reports four checkpoints — engine start, Dart VM start, framework init, first
frame — and the gaps between them tell you where the time went.

The usual causes, in the order they usually appear:

1. **Synchronous work in `main` before `runApp`.** Opening a database, reading preferences,
   initialising six SDKs. Move everything you can behind the first frame, and initialise the
   rest lazily.
2. **A first screen that builds too much.** Defer below-the-fold content; render the shell
   first.
3. **Shader compilation** on the first animation. Impeller removes this; on Skia it needs
   warm-up.
4. **Large images decoded on the first frame.** Pre-size them, or load after first paint.

## Automating regression checks

Manual profiling catches what you look at. Automated checks catch what you did not:

```dart
// integration_test/scroll_perf_test.dart
testWidgets('order list scroll stays within budget', (tester) async {
  await tester.pumpWidget(const App());
  await binding.watchPerformance(() async {
    await tester.fling(find.byType(ListView), const Offset(0, -500), 2000);
    await tester.pumpAndSettle();
  }, reportKey: 'scroll_timeline');
});
```

Run with `flutter drive --profile`, and the output JSON carries
`average_frame_build_time_millis`, `90th_percentile_frame_build_time_millis` and the raster
equivalents. Assert against a threshold in CI, and the build fails when a change makes
scrolling worse.

Two caveats that decide whether this is useful or noise: **run it on a dedicated physical
device**, because a shared CI runner's numbers vary by more than the regressions you are
looking for; and **assert on percentiles, not averages**, because jank is a tail
phenomenon — an average frame time can look fine while every tenth frame is dropped.

## Interview angles

**"How do you profile a Flutter app?"** Profile mode on a real low-end device, reproduce the
interaction, record in DevTools, read whether the UI or raster bar is over budget, change one
thing, measure again. Quote the budget: 16.7 ms at 60 Hz.

**"The app is dropping frames — where do you start?"** With which thread. UI-thread work and
raster-thread work have completely different fixes, and guessing without that split wastes
the afternoon. Then name the usual suspects per side.

**"Why not measure in debug mode?"** JIT plus assertions make it several times slower and
unevenly so, which distorts the shape of the profile, not just its scale.

**"How do you stop performance regressing?"** An integration test driving the interaction
under `--profile`, asserting on 90th-percentile frame times, on a dedicated device. Averages
hide jank because jank lives in the tail.

## See also

- [Rendering pipeline](../part-01-foundations/rendering-pipeline.md) — what the phases are
- [Rendering performance](performance-rendering.md) — the UI-thread fixes
- [Memory](performance-memory.md) — leaks and the memory view
- [Isolates](../part-01-foundations/dart-isolates.md) — moving CPU work off the UI isolate
