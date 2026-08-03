# Constraints and layout

"Constraints go down, sizes go up, parent sets position" — the sentence that explains every
layout error Flutter will ever show you.

## The recommendation

When a layout misbehaves, do not start changing widgets. Ask two questions in order: **what
constraints is this widget receiving**, and **what size is it choosing within them**. A
`LayoutBuilder` or a `debugPrint(constraints.toString())` answers the first in thirty
seconds, and the answer is almost always the whole diagnosis.

## The model

A parent passes each child a `BoxConstraints` — four numbers:

```dart
BoxConstraints(minWidth: 0, maxWidth: 300, minHeight: 0, maxHeight: double.infinity)
```

The child must choose a size inside that box, and hands it back. The parent then positions
it. One pass down, one pass up, no negotiation and no second guess — which is what keeps
layout linear in the number of render objects rather than quadratic.

Three shapes of constraint, and the vocabulary matters because the error messages use it:

| Shape | Means | Example source |
| --- | --- | --- |
| **Tight** | min equals max — the size is dictated | `SizedBox(width: 100, height: 100)` |
| **Loose** | min is 0, max is finite — "up to this big" | `Center`, `Align`, `Padding` |
| **Unbounded** | max is `double.infinity` | `ListView`, `Column`, `SingleChildScrollView` along their axis |

The consequence people trip over: **a widget cannot choose its own size if its parent gave
it tight constraints.** `Container(width: 100)` inside a parent that says "you are exactly
300 wide" is 300 wide. This is not a bug and there is no flag to change it — wrap in
`Center`, `Align` or `UnconstrainedBox` to loosen the constraint first.

## Reading the two errors you will actually see

### "RenderFlex children have non-zero flex but incoming height constraints are unbounded"

An `Expanded` or `Flexible` inside a `Column` that is itself inside something unbounded —
usually a `SingleChildScrollView` or another `Column` in a scroll view. `Expanded` means
"take the remaining space", and there is no remaining space when the available space is
infinite.

```dart
// Broken: the Column has infinite height to work with.
SingleChildScrollView(
  child: Column(
    children: [Expanded(child: Text('hi'))],
  ),
)
```

Fixes, in order of preference:

1. **Do you actually need the scroll view?** If the content fits, drop it and `Expanded`
   works against the real screen height.
2. **`ConstrainedBox`/`SizedBox`** to give a real bound where one genuinely exists.
3. **`CustomScrollView` with slivers**, when you want scrolling *and* a section that fills
   the viewport — `SliverFillRemaining` is the correct tool for that.
4. **`shrinkWrap: true`** on the inner list. This works and is the expensive option: the
   list lays out all its children to measure itself, which defeats lazy building. Acceptable
   for ten items, wrong for a thousand.

### "A RenderFlex overflowed by N pixels"

A child chose a size larger than the space the parent has. The yellow-and-black stripes name
the axis and the amount; the fix depends on intent:

- The child should shrink → wrap it in `Flexible` or `Expanded`.
- The text should wrap or ellipsize → give it bounded width and set `overflow`.
- The content should scroll → make the parent scrollable.
- The layout should adapt → `Wrap`, or a `LayoutBuilder` branch.

## Unbounded constraints and why they exist

`ListView` gives its children unbounded constraints along the scroll axis because that is
what scrolling means: there is no maximum height, the viewport just shows a window into it.
The same is true of `Column` in the vertical direction when it is inside a scroll view.

This is why a `ListView` inside a `Column` fails without help — the list wants a bounded
height to know how much to build, and the `Column` offers infinity. Give it a bound:

```dart
Column(
  children: [
    const Header(),
    // Expanded turns the leftover space into a tight constraint for the list.
    Expanded(child: ListView.builder(itemBuilder: ...)),
  ],
)
```

And for a list inside a scroll view, prefer slivers over nesting scrollables:

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar(),
    SliverList.builder(itemBuilder: ...),   // lazy, and scrolls with the app bar
  ],
)
```

## Intrinsics and their cost

`IntrinsicWidth` and `IntrinsicHeight` ask a subtree "how wide would you like to be,
ignoring constraints?" — and to answer, the framework runs an **extra layout pass** over
that subtree.

```dart
// Every row measures its whole subtree twice.
IntrinsicHeight(
  child: Row(children: [LeftPanel(), VerticalDivider(), RightPanel()]),
)
```

The documented cost is "relatively expensive"; in practice it is a second walk of the
subtree per layout, and it can nest. Inside a list item, an `IntrinsicHeight` around a
subtree that itself contains one turns list scrolling quadratic.

**Alternatives, in order:**

1. `Row` with `crossAxisAlignment: CrossAxisAlignment.stretch` — free, and covers the common
   "make these the same height" case.
2. A fixed size, when the design actually has one.
3. `LayoutBuilder` plus arithmetic, when the sizes are computable.
4. `IntrinsicHeight` — when the content genuinely determines the size and the subtree is
   small.

Some widgets do not support intrinsics at all and will assert if you ask — a `RenderBox`
must implement `computeMinIntrinsicWidth` and friends for them to work.

## Custom layout, when composition runs out

Three levels, cheapest first.

**`LayoutBuilder`** gives you the incoming constraints as data, so you can *choose* a widget
tree based on them. It is not a layout algorithm — it rebuilds during layout, so keep the
builder cheap and do not `setState` from it.

```dart
LayoutBuilder(
  builder: (context, constraints) => constraints.maxWidth > 600
      ? const TwoColumnLayout()
      : const SingleColumnLayout(),
)
```

**`CustomMultiChildLayout`** positions a fixed set of named children with a delegate. Use it
when children's positions depend on each other's sizes:

```dart
class _ChatBubbleLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    // Measure the timestamp first, then give the message the rest.
    final stampSize = layoutChild(#stamp, BoxConstraints.loose(size));
    final messageSize = layoutChild(
      #message,
      BoxConstraints.loose(Size(size.width - stampSize.width, size.height)),
    );
    positionChild(#message, Offset.zero);
    positionChild(#stamp, Offset(messageSize.width, 0));
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}
```

**A custom `RenderObject`** when you need the full contract — sizing, positioning, painting
and hit testing, with control over relayout boundaries. That is the class in
[the three trees](flutter-three-trees.md), and the details that bite are listed there:
`markNeedsLayout` on property changes, `parentUsesSize` honesty, and applying the paint
offset in `hitTestChildren`.

## Slivers, briefly

Inside a scroll view the protocol changes: instead of `BoxConstraints` in and a `Size` out,
it is `SliverConstraints` in and `SliverGeometry` out, carrying scroll offset, remaining
paint extent and cache extent. That is what allows a sliver to build only what is visible
plus a cache window.

You need this vocabulary when a `SliverAppBar` behaves oddly or when you mix boxes and
slivers: `SliverToBoxAdapter` wraps a box widget for a sliver context, and `SliverList`,
`SliverGrid` and `SliverFillRemaining` are the sliver-native equivalents. Wrapping a big
list in `SliverToBoxAdapter` re-introduces the eager-build problem that slivers exist to
avoid.

## Debugging layout in practice

```dart
debugPaintSizeEnabled = true;   // draw every box, padding and spacer
debugDumpRenderTree();          // sizes and constraints for the whole tree, in the log
```

The render tree dump is the fastest tool for "why is this 300 wide". Each line carries the
constraints the object received and the size it chose, so the mismatch is visible without
guessing. In DevTools, the **Layout Explorer** shows the same information interactively for
flex layouts, including which child took which share.

And when you only need one number:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    debugPrint('$constraints');   // BoxConstraints(w=..., h=...)
    return child;
  },
)
```

## Interview angles

**"Explain Flutter's layout algorithm."** Constraints down, sizes up, parent sets position,
single pass. Then the payoff: because it is single-pass with no negotiation, layout is
linear in the number of render objects, which is what makes deep widget trees affordable.

**"Why does my Container ignore its width?"** Because the parent passed tight constraints,
and a child cannot choose a size outside the constraints it was given. Wrap in `Center` or
`Align` to loosen them.

**"What is an unbounded constraint error?"** A widget asked for "the remaining space" inside
a parent that has infinite space to give — usually `Expanded` inside a `Column` inside a
`SingleChildScrollView`. Name the four fixes and which one you would pick.

**"When would you write a custom RenderObject?"** When the layout cannot be composed from
existing widgets and the composition is measurably expensive. Mention `LayoutBuilder` and
`CustomMultiChildLayout` first — reaching for a `RenderObject` straight away signals you do
not know they exist.

**"Why is IntrinsicHeight expensive?"** It adds a layout pass over the subtree to measure it
before laying it out, and the cost compounds when nested or used inside a list item.

## See also

- [Widgets, elements and render objects](flutter-three-trees.md) — the render object contract
- [Rendering pipeline](rendering-pipeline.md) — where layout sits in a frame
- [Rendering performance](../part-04-production/performance-rendering.md) — list performance
- [Profiling](../part-04-production/performance-profiling.md) — measuring a layout cost
