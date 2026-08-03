# Part 2 — Professional Flutter

How an app is put together, how its state moves, and how you keep it honest with tests.

Everything here is a **decision with a cost**. Part 1 described how the framework works,
which is not negotiable. This part is about choices — layering, state management, routing —
where the right answer depends on the size of the team, the age of the codebase, and how
long it has to live. Pages here name the cost of every recommendation, because a
recommendation without one cannot be applied.

## Structure

- **[Project structure](project-structure.md)** — feature-first versus layer-first, where
  shared code lives, and when a folder should become a package.
- **[Tooling](tooling.md)** — a strict analyzer, formatting in CI, and code generation that
  earns its build time.
- **[Clean Architecture](clean-architecture.md)** — the three layers, entity versus DTO, when
  use cases pay off, and when the whole thing is overkill.
- **[Dependency injection](dependency-injection.md)** — constructor injection first,
  containers at the composition root, scoping and lifetimes.
- **[Navigation](navigation.md)** — declarative routing, deep links, guards, and testing them.
- **[Error handling](error-handling.md)** — `Result` at boundaries, a failure taxonomy, and
  catching what escapes.

## State

- **[Choosing an approach](state-management-choosing.md)** — the decision guide, including
  the honest case against Provider and GetX.
- **[Riverpod](state-management-riverpod.md)** — providers, `AsyncNotifier`, scoping,
  testing, and the anti-patterns.
- **[BLoC](state-management-bloc.md)** — Cubit versus Bloc, event transformers, and where the
  ceremony pays for itself.

## Quality

- **[Anti-patterns](anti-patterns.md)** — the mistakes that cause crashes, leaks and jank,
  each with its mechanism and its smallest fix.
- **[Unit tests](testing-unit.md)**, **[widget tests](testing-widget.md)**,
  **[integration tests](testing-integration.md)** and **[golden tests](testing-golden.md)** —
  a suite people trust and actually run.

## The through-line

One feature — a user profile with search and rename — is implemented across these pages in
`code/architecture/`: entity, DTO, mapper, repository, use case, then the same feature in
both Riverpod and BLoC. The tests for it are in `code/testing/`, and they run with no
network and no widget tree, which is the practical measure of whether the layering worked.
