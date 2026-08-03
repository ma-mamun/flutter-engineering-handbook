# Rendering performance

Finding the widget that rebuilds sixty times a second, and stopping it.

## The recommendation

**Shrink the rebuild scope before anything else.** Most Flutter jank is a large subtree
rebuilding for a change that affects a small part of it. `const`, smaller stateful widgets,
`select`, and a `child` passed to a builder cover the majority of cases and cost nothing.
Reach for `RepaintBoundary` and shader warm-up only after
[profiling](performance-profiling.md) says the raster thread is the problem.

## Rebuild scope

Every technique here is the same idea: make the part that changes as small as possible.

**`const` everywhere it compiles.** A `const` widget is the same instance as last frame, so
the element diff short-circuits and the subtree is skipped entirely — the mechanism is in
[the three trees](../part-01-foundations/flutter-three-trees.md). Turn on `prefer_const_constructors`
and let the analyzer find them.

**Extract widget classes, not helper methods.**

```dart
// A method: no separate element, cannot be const, rebuilds with the parent.
Widget _buildHeader() => Padding(padding: ..., child: Text(title));

// A class: its own element, can be const, rebuilds independently.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: ..., child: Text(title));
}
```

This is the highest-value refactor in a slow screen and it looks like a style change, which
is why it gets skipped.

**Pass the expensive subtree as `child`.**

```dart
// The chart is built once, then handed back untouched on every animation tick.
AnimatedBuilder(
  animation: controller,
  child: const ExpensiveChart(),
  builder: (context, child) => Opacity(opacity: controller.value, child: child),
)
```

Same for `ValueListenableBuilder`, `StreamBuilder` and `Consumer`. Without the `child`
argument, an animation rebuilds its whole subtree 60 times a second.

**Depend on one field, not the whole object.**

```dart
final name = ref.watch(userProvider.select((u) => u.value?.name));   // Riverpod
context.select<Cart, int>((c) => c.itemCount);                        // Provider
BlocSelector<CartBloc, CartState, int>(selector: (s) => s.itemCount)  // BLoC
```

A page watching a whole state object rebuilds when any field changes, including fields it
does not render.

**Move `setState` down.** A `setState` at the top of a page rebuilds the page. If only a
counter changed, the counter should be its own small stateful widget — or a `ValueNotifier`
with a `ValueListenableBuilder` around only the text.

## RepaintBoundary

A `RepaintBoundary` gives its subtree a separate layer, so repainting it does not repaint its
neighbours, and a layer that only moved can be composited from its cached raster instead of
being repainted.

```dart
// The badge animates over a static list. Without the boundary, the list's layer
// is invalidated on every frame of the animation.
Stack(
  children: [
    const OrderList(),
    RepaintBoundary(child: PulsingBadge()),
  ],
)
```

**The cost is real:** each boundary consumes GPU memory for its layer and adds a compositing
step. Wrapping everything makes an app slower, not faster, and it is a common
over-application of otherwise good advice.

Add one where something animates *over* stable content, and verify with
`debugRepaintRainbowEnabled = true`: if a region changes colour every frame while nothing in
it visibly changed, it is repainting unnecessarily. If the colours do not change, the boundary
you added bought nothing — remove it.

Note that `ListView` already wraps its children in repaint boundaries by default, so adding
your own inside a list item is usually redundant.

## List and scroll performance

The largest single win available in most apps, in order:

**`ListView.builder`, never `ListView(children: [...])` for long lists.** The builder form
builds only what is visible plus a cache window; the other form builds everything, including
the 480 items nobody scrolled to.

**Never put a `Column` of many children in a `SingleChildScrollView`.** Same problem, less
obvious. Use slivers when the list shares a scroll view with other content.

**Avoid `shrinkWrap: true`.** It makes the list lay out all its children to measure itself,
which is exactly what lazy building exists to avoid. If you reached for it to nest a list in
a `Column`, wrap the list in `Expanded` instead — see
[constraints and layout](../part-01-foundations/constraints-and-layout.md).

**Give items a fixed extent when they have one.** `itemExtent` or `prototypeItem` lets the
scroll machinery skip measuring each child, which makes scroll-to-index and fast flings
dramatically cheaper.

**Keep item builders cheap.** No date formatting, no sorting, no `Intl` construction, no
regex compilation inside `itemBuilder` — it runs per item per scroll. Precompute in the model.

**Watch `addAutomaticKeepAlives`.** Keeping every scrolled-past item alive defeats recycling
and grows memory with scroll distance. Keep alive only what genuinely needs it — a playing
video, a loaded map.

## Images

Images are the most common raster-thread problem and the easiest to fix:

```dart
Image.network(
  url,
  // Decode at display size. A 4000x3000 photo in a 100x100 avatar otherwise
  // decodes to ~48 MB and rasterises slowly.
  cacheWidth: (100 * MediaQuery.devicePixelRatioOf(context)).round(),
)
```

- **Ask the backend for a thumbnail.** Resizing on device is a workaround for shipping the
  wrong bytes over the network.
- **`cached_network_image`** for disk caching and placeholders, which also stops a scroll
  from re-downloading.
- **Fade in with a placeholder of the final size**, or the list reflows as images land and
  the user loses their place.

## Expensive effects

| Effect | Why it costs | Cheaper option |
| --- | --- | --- |
| `Opacity` on a large subtree | Forces an offscreen layer (`saveLayer`) | `AnimatedOpacity`, `FadeTransition`, or a colour with alpha |
| `ClipRRect` on scrolling items | Clip per frame per item | A pre-rounded image, or a decoration |
| `BackdropFilter` | Reads back the framebuffer | Use sparingly, never in a list |
| Large `BoxShadow` blurs | Blur is fill-rate heavy | Smaller blur radius, or a nine-patch asset |
| Deep `Stack` overdraw | Painting the same pixels repeatedly | Flatten, or clip to what is visible |

`saveLayer` is the operation to recognise in a raster profile: it allocates an offscreen
buffer, draws into it, then composites. `Opacity`, clips with anti-aliasing and blend modes
all trigger it.

## Shader jank

The first time an animation uses a shader, it is compiled on the spot — one long frame, once
per session, exactly when the user first opens a screen.

**Impeller is the fix**, and it is the default on iOS since Flutter 3.10 and on Android since
3.29. It compiles shaders ahead of time and the class of jank disappears. On a version or
platform still using Skia, the workaround is SkSL warm-up — capture during a run and bundle
the result — which is fiddly and now largely historical.

If you see one long frame the first time a specific animation plays and never again, that is
this, and no amount of rebuild-scope work will change it.

## Measuring the effect

Every claim on this page should be checked the same way: profile mode, real device, one
change, both numbers. The debug flags that shorten the loop:

```dart
debugRepaintRainbowEnabled = true;   // did this layer repaint?
debugPaintSizeEnabled = true;        // what is actually being laid out
debugProfileBuildsEnabled = true;    // per-widget build events in the timeline
timeDilation = 5.0;                  // slow animations to see what moves
```

## Interview angles

**"Why is the app dropping frames?"** Start by splitting UI thread from raster thread, then
name the usual causes per side: rebuild scope and work in `build` on the UI side; images,
`saveLayer` effects and shaders on the raster side. Refusing to guess before profiling is the
answer they are listening for.

**"How can an unnecessary rebuild happen?"** A parent rebuilding a subtree that did not
change: no `const`, a builder without a `child`, a provider watched wholesale instead of by
field, a `setState` too high in the tree. Give the fix per cause.

**"What is RepaintBoundary and when does it hurt?"** It isolates a subtree into its own layer
so repaints and moves are cheap; it hurts when overused, because each layer costs GPU memory
and a compositing step. Mention `debugRepaintRainbowEnabled` as the way to verify.

**"How do you make a long list smooth?"** `ListView.builder`, fixed extents where possible,
cheap item builders, images decoded at display size, and no `shrinkWrap`. Then measure with a
fling in an integration test so it stays smooth.

## See also

- [Rendering pipeline](../part-01-foundations/rendering-pipeline.md) — the phases involved
- [Profiling](performance-profiling.md) — the measure/change/measure loop
- [Memory](performance-memory.md) — the image cache
- [Anti-patterns](../part-02-professional/anti-patterns.md) — the same mistakes, catalogued
