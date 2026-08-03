# Widgets, elements and render objects

Three trees and the contracts between them. This is the model everything else in the
handbook rests on, and it is the answer to most "why did this rebuild" questions.

## The recommendation

Think of a widget as a **description**, an element as the **instance** that manages a
position in the tree, and a render object as the **thing that measures, paints and gets
hit-tested**. Widgets are cheap and thrown away every frame; elements and render objects are
expensive and kept. Nearly every performance and identity bug in Flutter comes from
confusing which of the three you are actually talking about.

## The three trees

```mermaid
graph TD
  subgraph Widgets — immutable configuration, rebuilt constantly
    W1[Padding] --> W2[Text 'hello']
  end
  subgraph Elements — mutable, long-lived, own the State
    E1[SingleChildRenderObjectElement] --> E2[LeafRenderObjectElement]
  end
  subgraph Render objects — layout, paint, hit test
    R1[RenderPadding] --> R2[RenderParagraph]
  end
  W1 -. creates .-> E1
  E1 -. creates .-> R1
  W2 -. creates .-> E2
  E2 -. creates .-> R2
```

| | Widget | Element | RenderObject |
| --- | --- | --- | --- |
| Mutable | No, always immutable | Yes | Yes |
| Lifetime | One frame, typically | Until removed from the tree | Until its element is removed |
| Cost to create | Trivial — a few field writes | Moderate | Expensive |
| Holds `State` | No | Yes, for `StatefulWidget` | No |
| Does layout/paint | No | No | Yes |
| Your code touches | Constantly | Via `BuildContext` | Rarely, and deliberately |

Not every widget has a render object. `Padding`, `Text` and `ColoredBox` do.
`Column`, `Row` and `Opacity` do. `StatelessWidget`, `StatefulWidget`, `Builder`,
`Provider` and most of what you write do **not** — they are *composition*: they return other
widgets, and only the leaves of that expansion create render objects.

## Why the element tree exists

The widget tree is rebuilt constantly and is immutable, so it cannot hold state. The render
tree is expensive to build, so it must not be. The element tree is the layer in between that
**persists identity across rebuilds** and decides, for each position in the tree, whether the
new widget can update the existing render object or must replace it.

That decision is one method, and it is worth knowing by heart. When a parent rebuilds,
`Element.updateChild` compares the new widget with the old one at that position:

```text
old widget == new widget (identical instance)  -> do nothing at all
runtimeType and key both match                 -> update in place, keep element,
                                                  keep State, keep render object
otherwise                                      -> deactivate the old element subtree,
                                                  inflate a new one
```

Three consequences follow, and each one is a real bug people hit:

**`const` widgets short-circuit rebuilds.** An identical instance takes the first branch,
so the whole subtree is skipped. That is the mechanism behind "use `const` everywhere" —
not a micro-optimisation but an early exit in the diff.

**Changing a widget's type throws away its state.** Wrapping a subtree in an
`if (loading) ... else ...` that swaps `Container` for `SizedBox` discards everything
below, including scroll positions, animation controllers, and text field contents.

**Position is identity unless you supply a key.** Which is the next section.

## Keys

A key is how you tell the framework that a widget which *moved* is still the same widget.
Without one, the framework matches children by position and type — so reordering a list of
identical-looking stateful children keeps state in place while the data moves past it.

```dart
--8<-- "flutter/keys_demo.dart"
```

The behaviour is asserted rather than described: with keys, tapping the first tile twice and
then swapping leaves the count with its label; without keys the count stays in slot zero and
the labels slide past it.

### Which key to use

| Key | Identity is | Use for |
| --- | --- | --- |
| `ValueKey(id)` | A value, compared with `==` | List items with a stable id — the default choice |
| `ObjectKey(item)` | The object's identity | Items with no id, where the instance itself is stable |
| `UniqueKey()` | Nothing — never equal to anything | Forcing a rebuild from scratch, deliberately |
| `GlobalKey()` | App-wide unique | Reaching a `State` or a render object from outside |
| `PageStorageKey(id)` | A value, for scroll restoration | Preserving scroll offset across navigation |

**`ValueKey` is the answer 90% of the time.** Key list items by their stable id, not their
index — an index key is no better than no key, because index *is* position.

!!! warning "`UniqueKey` in a build method rebuilds everything, every frame"
    `UniqueKey()` is never equal to the previous one, so the subtree is destroyed and
    recreated on every build. State is lost, animations restart, and the cost is the whole
    subtree. Use it only when you *want* a fresh start — a deliberate "reset this form" —
    and store it in `State`, not in `build`.

### GlobalKey

A `GlobalKey` is unique across the whole app and gives you three things a normal key does
not: access to the `State` (`key.currentState`), access to the `BuildContext`
(`key.currentContext`), and the ability to **move a subtree to a different parent while
keeping its state**.

```dart
final _formKey = GlobalKey<FormState>();
// ...
if (_formKey.currentState!.validate()) { /* ... */ }
```

**The cost, and why "overusing GlobalKey" is on every anti-pattern list:**

- Each one is registered in a global registry, so it is heavier than a `ValueKey`.
- Moving an element via a GlobalKey forces the subtree to deactivate and reactivate, which
  is a full rebuild plus a layout of everything under it.
- `currentState` is an escape hatch out of the declarative model. Reaching up from a child
  to poke a parent's state is exactly the coupling the framework is designed to prevent.
- Two widgets alive at once with the same `GlobalKey` is a runtime error, and it happens
  during transitions when the old route has not been disposed yet.

Use `GlobalKey` for `Form`, for `Scaffold`/`Navigator` access where no context is available,
and for measuring a render object. For passing data down, use a constructor parameter or an
`InheritedWidget`; for passing events up, use a callback.

## BuildContext is an element

`BuildContext` is not a separate object — it is the `Element` itself, exposed through a
narrower interface. Every consequence of that is worth knowing:

- **It has a position in the tree.** `Theme.of(context)` walks *up* from that position, so a
  context taken above the widget you meant returns the wrong ancestor. This is the cause of
  "no Scaffold found" when calling `ScaffoldMessenger.of(context)` with the context of the
  widget that *created* the Scaffold.
- **It can die.** After the element is unmounted, the context is invalid, and using it
  throws. This is why an `await` before `Navigator.of(context)` needs a `mounted` check —
  see [widget lifecycle](widget-lifecycle.md).
- **Looking something up registers a dependency.** `of(context)` calls
  `dependOnInheritedWidgetOfExactType`, which subscribes this element to that inherited
  widget. When the inherited widget changes, every dependent element is marked dirty. That
  subscription is the whole mechanism behind Provider, and it is covered in
  [state management](../part-02-professional/state-management-choosing.md).

## RenderObject

A render object does four things: compute its size given constraints, position its
children, paint, and answer hit tests. Most apps never write one — `CustomPaint`,
`Flow`, `LayoutBuilder` and `CustomMultiChildLayout` cover nearly everything.

Write one when you need layout behaviour that cannot be expressed by composing existing
widgets, and when the cost of expressing it with them is measurable. Here is the whole
contract in one class:

```dart
--8<-- "flutter/render_square.dart"
```

The details that bite:

- **A property setter must mark what changed.** `markNeedsLayout` for anything affecting
  size or position, `markNeedsPaint` for anything visual only. Forgetting is the classic
  bug: the value updates, the screen does not.
- **`parentUsesSize`** tells the framework whether your layout depends on the child's size.
  Passing `true` when you do not need it forces this box to relayout whenever the child
  does, and that propagates up.
- **Hit testing is separate from painting.** A child painted at an offset that is not
  applied in `hitTestChildren` renders perfectly and ignores every tap.
- **Intrinsics are extra layout passes.** `IntrinsicHeight` measures the subtree before
  laying it out, which can turn linear layout into quadratic. See
  [constraints and layout](constraints-and-layout.md).

## Stateless versus stateful, internally

The difference is smaller than it looks, and it is entirely in the element:

- `StatelessWidget` creates a `StatelessElement`, which calls `widget.build(this)`.
- `StatefulWidget` creates a `StatefulElement`, which calls `createState()` once and then
  `state.build(this)`. The `State` object is held by the **element**, which is why it
  survives rebuilds of the widget, and why it dies when the element does.

So a `StatefulWidget` is still immutable. The mutable part is the `State` object hanging off
the element, and `setState` does one thing: mark the element dirty so the next frame calls
`build` again. Nothing else — it does not rebuild parents, and it does not rebuild children
that are `const` or otherwise identical.

## Interview angles

**"Difference between a widget and an element?"** A widget is immutable configuration,
recreated freely; an element is the mutable instance that occupies a position in the tree,
holds `State`, and decides whether to update or replace the render object beneath it. Add
the lifetimes — that is the part that shows you have used it.

**"Why does the element tree exist?"** Because widgets are immutable and rebuilt constantly
while render objects are expensive and must be reused. The element tree is the identity
layer that maps one onto the other across rebuilds.

**"What is a Key and when do you need one?"** An identity hint for element matching. You
need one when widgets of the same type change position among siblings — reorderable lists,
filtered lists, swapped children. `ValueKey` with a stable id by default.

**"Difference between LocalKey and GlobalKey?"** A `LocalKey` (`ValueKey`, `ObjectKey`,
`UniqueKey`) only has to be unique among siblings; a `GlobalKey` is unique app-wide, exposes
`currentState` and `currentContext`, and can move a subtree between parents while preserving
its state — at the cost of a deactivate/reactivate cycle.

**"What is a RenderObject?"** The object that actually does layout, painting and hit
testing. Widgets describe; render objects perform. Mention that most widgets you write do
not create one.

**"Difference between StatelessWidget and StatefulWidget internally?"** Which element is
created, and whether that element holds a `State` object across rebuilds. Both widgets are
immutable.

## See also

- [Rendering pipeline](rendering-pipeline.md) — what happens after the element is dirty
- [Widget lifecycle](widget-lifecycle.md) — the `State` callbacks, in order
- [Constraints and layout](constraints-and-layout.md) — how render objects negotiate size
- [Rendering performance](../part-04-production/performance-rendering.md) — measured effects
