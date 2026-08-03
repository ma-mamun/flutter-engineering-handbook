# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] — 2026-08-04

**Performance.** Measure, then fix — with the measuring given more space than
the fixing.

### Added

- `performance-profiling.md` — why debug numbers are not just scaled but
  distorted, the six-step workflow, what each DevTools view answers, frame
  budgets at 60/90/120 Hz, startup tracing, and automated regression checks that
  assert on percentiles rather than averages.
- `performance-rendering.md` — rebuild scope first (const, widget classes over
  helper methods, the `child` argument, `select`, moving `setState` down),
  `RepaintBoundary` with its cost and how to verify it earned its place, list and
  scroll rules, image decode sizing, a table of expensive effects and cheaper
  alternatives, and shader jank under Impeller.
- `performance-memory.md` — the retaining chain that makes one timer hold a whole
  page, a table of leak sources with fixes, the snapshot-diff workflow, the image
  cache and why decoded size is width × height × 4, leak detection in tests, and
  reading platform memory.
- `performance-build-size.md` — measuring and diffing with `--analyze-size`, what
  a Flutter app is made of, app bundles versus split APKs, assets and fonts as
  the usual largest win, dependency auditing, deferred components and when they
  are not repaid, and realistic targets.

## [0.6.0] — 2026-08-04

**Security.** The binary runs on the attacker's device; the pages are written
from that assumption.

### Added

- `security-storage.md` — what each store actually is, `flutter_secure_storage`
  options that are usually wrong (iOS accessibility, Android backing), handling
  an invalidated Keystore key, what to store and for how long, biometric gating
  and why the returned boolean is not a control, and five things encryption at
  rest does not protect.
- `security-network.md` — platform HTTPS enforcement on both sides, certificate
  pinning with its full operational cost (two pins, a kill switch, rehearsed
  rotation), why secrets cannot live in the client and what to do instead,
  detecting interception honestly, and a pre-release checklist.
- `security-hardening.md` — `--obfuscate --split-debug-info` and symbol
  management, R8 keep rules and the release-only crash they prevent, root
  detection's value and limits, Play Integrity and App Attest as the controls
  that verify server-side, and a ranked list of where security effort actually
  belongs.

## [0.5.0] — 2026-08-04

**Networking and data.** Part 3 in full — the layer where production bugs live.

### Added

- `networking.md` — choosing a client, one configured dio instance, how an
  interceptor works and why order is behaviour, single-flight token refresh,
  retry rules, timeouts versus cancellation, cursor pagination, serialisation at
  the boundary, ETags and `Cache-Control`, PUT versus PATCH.
- `offline-first.md` — local database as the source of truth, four read
  strategies, the outbox pattern with transactional enqueue and client-generated
  ids, optimistic updates with rollback, six conflict resolution policies, delta
  sync with tombstones and cursor ordering, surfacing sync state, and what to
  test.
- `sqlite.md` — schema decisions for mobile, WAL and foreign-key pragmas,
  append-only migrations and the copy-and-rename dance, indexing with
  `EXPLAIN QUERY PLAN`, transactions and batches, and where row mapping blocks
  the UI isolate.
- `drift.md` — tables and compile-checked queries, reactive streams and their
  cost, DAOs and companion semantics, the migration test harness, and running
  the database on its own isolate.
- `isar.md` — the document model, links and watchers, implicit migrations and
  what they do not cover, the maintenance question, and a migration route off it.
- `hive.md` — boxes and lazy boxes, the unforgiving adapter rules, encryption and
  where the key belongs, and the five signals that you have outgrown it.
- Samples with tests asserting the property rather than the happy path:
  `code/networking/retry.dart` (backoff, jitter, no retry on a 404, idempotency),
  `token_refresh.dart` (five concurrent 401s produce one refresh), and
  `paginator.dart` (concurrency guard, deduplication, failed page keeps prior
  pages).

## [0.4.0] — 2026-08-04

**Architecture.** Part 2's structure and state pages: how an app is put together
and how its state moves, with the cost of every recommendation named.

### Added

- `project-structure.md` — feature-first versus layer-first and why, the rules
  that keep it working, when to split into packages, naming conventions.
- `tooling.md` — a strict `analysis_options.yaml`, formatting in CI, code
  generation and its build-time cost, the CLI worth knowing.
- `clean-architecture.md` — the three layers and the inward dependency rule,
  entity versus DTO versus model, when use cases earn their keep, avoiding
  circular dependencies, SOLID in Flutter terms, and when it is all overkill.
- `dependency-injection.md` — constructor injection first, the composition root,
  `get_it` versus Riverpod providers, scoping and lifetimes, testing seams.
- `navigation.md` — Navigator 1.0 versus declarative, a full `go_router` table
  with guards, typed routes, deep links on both platforms, testing navigation.
- `error-handling.md` — exceptions inside a layer and `Result` at boundaries, a
  failure taxonomy, `FlutterError.onError` and `PlatformDispatcher.onError`,
  error boundaries in the widget tree.
- `state-management-choosing.md` — ephemeral versus shared state, a comparison
  across five approaches, the honest case against Provider and GetX, migration
  costs.
- `state-management-riverpod.md` — provider types, `watch`/`read`/`listen`,
  `AsyncValue`, scoping and disposal, testing, six anti-patterns.
- `state-management-bloc.md` — Cubit versus Bloc, event transformers, state
  design and equality, `BlocObserver`, and the cost stated plainly.
- `anti-patterns.md` — new page: twelve failures with their mechanisms and
  smallest fixes.
- Samples: `code/architecture/user_feature.dart` (one feature across all four
  layers), `riverpod_user.dart` (`AsyncNotifier` with optimistic update and
  rollback), `bloc_search.dart` (Cubit, plus a Bloc with a debounced
  `restartable` transformer). Tests cover the mapper boundary, cache-before-
  network, optimistic rollback, and that a burst of keystrokes produces one
  request.

### Changed

- Added `flutter_riverpod`, `flutter_bloc` and `bloc_concurrency` to the samples
  package so the state management code is compiled and tested, not illustrative.
- Part 2 index rewritten as a landing page.

## [0.3.0] — 2026-08-04

**Flutter Internals.** Part 1's framework half — the material senior interviews
actually probe.

### Added

- `part-01-foundations/flutter-three-trees.md` — widget, element and render
  object; why the element tree exists; `Element.updateChild` and what it implies
  about `const`; keys, including when each kind is right and what `GlobalKey`
  costs; `BuildContext` as an element; and `StatelessWidget` versus
  `StatefulWidget` internally.
- `part-01-foundations/rendering-pipeline.md` — vsync to pixels, the UI/raster
  thread split, `RepaintBoundary` and its cost, shader jank, frame budgets, and
  the ranked list of where dropped frames come from.
- `part-01-foundations/widget-lifecycle.md` — every `State` callback in order,
  what belongs in each, `didUpdateWidget` versus `initState`, the `deactivate`/
  `activate` branch, and why a `BuildContext` after an `await` crashes.
- `part-01-foundations/constraints-and-layout.md` — the constraint model, the two
  layout errors you will actually see, unbounded constraints, the cost of
  intrinsics, custom layout at three levels, and slivers.
- Samples: `code/flutter/lifecycle_probe.dart` (lifecycle order asserted by
  test, plus the `mounted` guard), `keys_demo.dart` (the reorderable-list bug in
  its smallest reproducing form), and `render_square.dart` (a complete custom
  `RenderBox`: layout, paint, hit test, and marking).

## [0.2.0] — 2026-08-04

**Dart Mastery.** Part 1's four language pages, written in full.

### Added

- `part-01-foundations/dart-language-essentials.md` — `const` versus `final`,
  closures and the leaks they cause, class modifiers and sealed hierarchies,
  mixins versus inheritance, extension methods, generics and variance, enums,
  records, patterns, and collections.
- `part-01-foundations/dart-null-safety.md` — what soundness guarantees and where
  it stops, flow analysis and why fields are not promoted, the legitimate uses of
  `!`, nullability in models, and migrating a legacy codebase.
- `part-01-foundations/dart-async.md` — the event loop and its two queues, the
  ordering of microtasks against the event queue, Future versus Stream,
  `StreamController` and its four callbacks, error propagation, and cancellation.
- `part-01-foundations/dart-isolates.md` — the message-passing model,
  `Isolate.run` versus a long-lived worker, what belongs on an isolate, and how
  to measure it.
- Runnable samples, all analyzed and tested by CI: `code/dart/event_loop.dart`,
  `lru_cache.dart`, `debounce_throttle.dart`, `stream_pipeline.dart` (hand-rolled
  `debounce` and `switchMap`), and `isolate_worker.dart`.
- `fake_async` as a dev dependency, so timer-driven samples are tested against
  virtual time instead of real delays.

### Changed

- Part 1 index rewritten as a real landing page rather than an outline.
- Pinned the docs toolchain: `pymdown-extensions` 11.0.1 and `pygments` 2.20.0.
  Older pymdown-extensions releases pass `filename=None` to Pygments, which
  Pygments 2.19+ rejects, failing the build with `'NoneType' object has no
  attribute 'replace'`.

## [0.1.0] — 2026-08-04

**Repository Foundation.** Scaffolding, so everything after it is writing rather
than plumbing.

### Added

- MkDocs Material site with the full six-part structure outlined.
- `code/` package for runnable samples embedded into pages.
- CI: code checks gate the site build, `main` deploys to GitHub Pages.
- MIT license, Code of Conduct, contributing guide, style guide.
- Issue and PR templates, CODEOWNERS, Dependabot.
- `scripts/` with serve, build, check, and new-page helpers.
- `docs/style-guide.md`, `docs/getting-started.md`, `docs/roadmap.md`.

### Changed

- Restructured the handbook into six numbered parts plus an appendix and
  cheatsheets, replacing the flat topic sections.
- Consolidated the docs and code workflows into a single `deploy.yml` where the
  code checks gate the site build.
- Moved diagrams and images under `docs/`, split `assets/` into logo, banner,
  and social.

[Unreleased]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ma-mamun/flutter-engineering-handbook/releases/tag/v0.1.0
