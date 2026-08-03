# Part 1 — Foundations

The language and the framework. Nothing in this part depends on an architectural opinion,
and everything in the rest of the handbook depends on this part.

If you are preparing for interviews, this is the material that separates a mid-level
answer from a senior one. Most candidates can describe *what* a widget is. Far fewer can
explain what happens between `setState` and a pixel, or why the order of two `Future`s is
not the order they were written in.

## The language

- **[Dart language essentials](dart-language-essentials.md)** — `const` versus `final`,
  closures and the leaks they cause, mixins versus inheritance, generics and variance,
  records, patterns, and sealed classes.
- **[Null safety](dart-null-safety.md)** — what soundness guarantees, where the guarantee
  stops, and how to restructure code so `!` is not needed.
- **[Async and concurrency](dart-async.md)** — the event loop, the microtask queue, Future
  versus Stream, `StreamController`, error propagation, and cancellation.
- **[Isolates](dart-isolates.md)** — the message-passing model, `Isolate.run` versus a
  long-lived worker, and how to measure whether you needed one.

## The framework

- **[Widgets, elements and render objects](flutter-three-trees.md)** — the three trees,
  what each one is for, and why widgets are cheap.
- **[Rendering pipeline](rendering-pipeline.md)** — build, layout, paint, composite, and
  where a dropped frame comes from.
- **[Widget lifecycle](widget-lifecycle.md)** — every callback in order, `mounted`, and why
  a `BuildContext` is dangerous after an `await`.
- **[Constraints and layout](constraints-and-layout.md)** — constraints go down, sizes go
  up, parent sets position; unbounded-constraint errors and custom layout.

## How to read this part

In order, once. The framework pages assume the language pages: the rendering pipeline is
explained in terms of the event loop, and the widget lifecycle is explained in terms of
what an `await` does to a `BuildContext`.

Every code sample in this part lives in `code/` in the repository and is formatted,
analyzed and tested by CI. The event loop ordering on the async page is not a claim — it is
an assertion in a passing test.
