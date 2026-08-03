# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ma-mamun/flutter-engineering-handbook/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ma-mamun/flutter-engineering-handbook/releases/tag/v0.1.0
