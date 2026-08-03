# Roadmap

Ten releases, each one a coherent slice a reader can use on its own. Progress is tracked
in GitHub milestones; this file is the plan of record.

| Version | Theme | Covers | Branch | Status |
| --- | --- | --- | --- | --- |
| [v0.1](#v01-repository-foundation) | Repository Foundation | Structure, tooling, CI | `main` | ✅ Done |
| [v0.2](#v02-dart-mastery) | Dart Mastery | Part 1 — language | `feature/chapter-01` | ✅ Done |
| [v0.3](#v03-flutter-internals) | Flutter Internals | Part 1 — framework | `feature/chapter-01` | ✅ Done |
| [v0.4](#v04-architecture) | Architecture | Part 2 — structure, layers, state | `feature/chapter-02` | ✅ Done |
| [v0.5](#v05-networking) | Networking | Part 3 — data and persistence | `feature/chapter-02` | ✅ Done |
| [v0.6](#v06-security) | Security | Part 4 — security | `feature/chapter-03` | ✅ Done |
| [v0.7](#v07-performance) | Performance | Part 4 — performance | `feature/chapter-03` | ✅ Done |
| [v0.8](#v08-testing) | Testing | Part 2 — testing | `feature/chapter-03` | ✅ Done |
| [v0.9](#v09-enterprise-flutter) | Enterprise Flutter | Part 5, native, CI/CD, release | `release/v1.0` | ✅ Done |
| [v1.0](#v10-complete-engineering-handbook) | Complete Handbook | Part 6, appendix, editorial pass | `release/v1.0` | 🚧 Next |

Each release ships when its **done when** line is true, not when its checkboxes are all
ticked — a page that exists but says nothing useful does not count.

---

## v0.1 — Repository Foundation

> Branch: `main` · **Complete**

The scaffolding that lets everything else be written without further plumbing.

- [x] MkDocs Material site with the full six-part structure outlined
- [x] `code/` package for runnable samples embedded into pages
- [x] CI: code checks gate the site build, `main` deploys to Pages
- [x] MIT license, Code of Conduct, contributing guide, style guide
- [x] Issue and PR templates, CODEOWNERS, Dependabot
- [x] Helper scripts: `serve`, `build`, `check`, `new-page`

**Done when:** a contributor can clone, run `./scripts/check.sh`, and open a PR without
asking how anything works. ✅

---

## v0.2 — Dart Mastery

> Branch: `feature/chapter-01` · Part 1

The language, and specifically the parts Flutter leans on hardest.

- [x] Language essentials — records, patterns, sealed classes, extensions
- [x] Null safety — soundness, `late`, migration, why `!` is a design smell
- [x] Async and concurrency — event loop, microtask queue, Future vs Stream
- [x] Isolates — the model, `compute()` vs long-lived, when you actually need one

**Done when:** a reader can predict the output order of interleaved `await`, microtask,
and timer callbacks, and explain why. ✅ — the ordering is asserted by a test, not claimed.

---

## v0.3 — Flutter Internals

> Branch: `feature/chapter-01` · Part 1, plus native integration

How a frame is produced, and what happens at the edge of the framework.

- [x] Widgets, elements and render objects — the three trees
- [x] Rendering pipeline — build, layout, paint, composite
- [x] Widget lifecycle — every callback, in order, with its correct use
- [x] Constraints and layout — the constraint model, unbounded errors, custom layout

Native integration moved to v0.9, where it sits with the rest of the platform work.

**Done when:** a reader can explain what happens between `setState` and a pixel, and why
a given widget rebuilt. ✅

---

## v0.4 — Architecture

> Branch: `feature/chapter-02` · Part 2

How an app is put together and how its state moves.

- [x] Project structure — feature-first vs layer-first, when to split packages
- [x] Tooling — analyzer, formatter, code generation
- [x] Clean Architecture — layers, entities vs DTOs, when it is overkill
- [x] Dependency injection — constructor first, get_it, scoping, testing seams
- [x] Navigation — go_router, deep links, auth guards
- [x] Error handling — Result vs exceptions, zone guards, crash reporting
- [x] Choosing a state management approach — the decision guide
- [x] Riverpod — providers, AsyncNotifier, scoping, anti-patterns
- [x] BLoC — Cubit vs Bloc, event transformers, when the ceremony pays off
- [x] Anti-patterns — added to scope: the failures, their mechanisms, and the fixes

**Done when:** a reader can defend a layering and a state management choice against the
alternatives, with tradeoffs named rather than asserted. ✅

---

## v0.5 — Networking

> Branch: `feature/chapter-02` · Part 3

The data layer, where most production bugs live.

- [x] Networking — dio vs http, interceptors, timeouts, serialization
- [x] Offline first — cache strategies, outbox pattern, conflict resolution
- [x] SQLite — schema design, migrations without data loss, indexing
- [x] Drift — type-safe SQL, DAOs, schema versioning, reactive queries
- [x] Isar — collections, indexes, watchers, migration strategy
- [x] Hive — boxes, adapters, encryption, where it stops scaling

**Done when:** a reader can design a sync layer that survives a flaky network without
losing a write, and pick a local database for a stated workload. ✅

---

## v0.6 — Security

> Branch: `feature/chapter-03` · Part 4

The binary runs on the attacker's device. Plan accordingly.

- [x] Secure storage — Keychain, Keystore, token rotation, biometric gating
- [x] Network security — TLS, pinning and its rotation risk, secrets off the client
- [x] Obfuscation and hardening — symbol files, integrity checks and their limits

**Done when:** a reader can state what each measure does and does not prevent, and
name the operational cost of pinning before shipping it. ✅

---

## v0.7 — Performance

> Branch: `feature/chapter-03` · Part 4

Measure, then fix. Mostly about measuring.

- [x] Rendering — rebuild scope, RepaintBoundary, shader jank, list performance
- [x] Memory — leak sources, image cache, DevTools memory view, leak tests
- [x] Build size — `--analyze-size`, split ABIs, asset subsetting, deferred components
- [x] Profiling — the reproduce/measure/change-one-thing loop, UI vs raster thread

**Done when:** a reader has a repeatable workflow for finding the cause of a dropped
frame, and reports numbers with the device named. ✅

---

## v0.8 — Testing

> Branch: `feature/chapter-03` · Part 2

A suite people trust and actually run.

- [x] Unit tests — testable structure, mocks vs fakes, async, coverage as signal
- [x] Widget tests — finders, matchers, pump vs pumpAndSettle, injecting dependencies
- [x] Integration tests — real flows, device farms, reducing flakiness
- [x] Golden tests — setup, font loading, CI rendering differences, updating goldens

**Done when:** a reader can diagnose a flaky test rather than retry it, and knows which
level to test a given behaviour at. ✅

---

## v0.9 — Enterprise Flutter

> Branch: `release/v1.0` · Part 5, plus CI/CD

What changes at forty engineers and a five-year horizon.

- [x] Modularization — Melos, package boundaries, build times, dependency rules
- [x] Team workflow — branching, review standards, ADRs, onboarding
- [x] Observability — crash symbolication, structured logging, analytics, feature flags
- [x] Design systems — theme extensions, component packages, versioning, white label
- [x] GitHub Actions — caching, matrix builds, keeping CI under ten minutes
- [x] Flavors — Android flavors, iOS schemes, `--dart-define`, per-flavor config
- [x] Release process — versioning, signing, staged rollout, rollback
- [x] Platform channels, Dart FFI and writing plugins — moved here from v0.3

**Done when:** a reader can take a green commit to a store listing without a
release-day scramble, and roll it back if it goes wrong. ✅

---

## v1.0 — Complete Engineering Handbook

> Branch: `release/v1.0` · Part 6, appendix, cheatsheets

- [ ] Mobile system design — a framework plus worked examples
- [ ] Coding round — live tasks, take-homes, internals questions
- [ ] Question bank — by level, each with what a strong answer contains
- [ ] HR round — STAR answers, levelling, negotiation
- [ ] Appendix — glossary, further reading, tooling reference
- [ ] Cheatsheets — lifecycle, testing, performance checklist
- [ ] Full editorial pass against the style guide

**Done when:** every page has content, no page is marked *Draft*, and `mkdocs build
--strict` is clean.

---

## Ongoing

Not tied to a release, welcome at any time:

- Corrections and version updates as Flutter releases land
- Measured numbers replacing assertions
- Diagrams for sections that currently explain in prose only
- Translations, once the English content settles

---

## Branch strategy

```
main                 Stable, published site. Protected — PRs only.
develop              Integration branch. Chapters merge here first.
feature/chapter-01   v0.2 – v0.3   Foundations
feature/chapter-02   v0.4 – v0.5   Architecture and data
feature/chapter-03   v0.6 – v0.8   Production concerns
release/v1.0         v0.9 – v1.0   Stabilisation, then tag and merge to main
```

Day to day:

```bash
git switch develop
git switch -c feature/chapter-01
# ... work, commit with Conventional Commits ...
git push -u origin feature/chapter-01
# open a PR into develop
```

Each version is tagged on `main` once its **done when** line is true:

```bash
git switch main
git merge --no-ff release/v1.0
git tag -a v1.0.0 -m "Complete Engineering Handbook"
git push origin main --tags
```

Smaller work that does not belong to a release — a correction, a CI fix — branches from
`develop` as `fix/...`, `docs/...`, or `chore/...` and merges back the same way.
