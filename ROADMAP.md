# Roadmap

The scope of v1.0 is the six parts of the handbook. This file breaks that into milestones
and maps each to a chapter branch.

Progress is tracked in GitHub milestones; this file is the plan of record.

---

## Milestone 1 — Foundations (`v0.1`)

> Branch: `feature/chapter-01` · Part 1

The language and framework layer. Nothing here depends on an architectural opinion.

- [ ] Dart — language essentials, null safety, async and concurrency, isolates
- [ ] Widgets, elements and render objects
- [ ] Rendering pipeline
- [ ] Widget lifecycle
- [ ] Constraints and layout

**Done when:** a reader can explain what happens between `setState` and a pixel, and why
a widget rebuilt.

---

## Milestone 2 — Professional Flutter (`v0.2`)

> Branch: `feature/chapter-02` · Parts 2 and 3

How an app is put together, how its state moves, and where its data lives.

- [ ] Project structure and tooling
- [ ] Clean Architecture, dependency injection, navigation, error handling
- [ ] State management — choosing, Riverpod, BLoC
- [ ] Testing — unit, widget, integration, golden
- [ ] Data — networking, offline first, SQLite, Drift, Isar, Hive

**Done when:** a reader can defend a layering and a state management choice against the
alternatives, with tradeoffs named.

---

## Milestone 3 — Production (`v0.3`)

> Branch: `feature/chapter-03` · Part 4

Everything between "it works on my machine" and "it works on a stranger's phone."

- [ ] Security — secure storage, network security, obfuscation and hardening
- [ ] Performance — rendering, memory, build size, profiling
- [ ] Native integration — platform channels, FFI, plugins
- [ ] CI/CD — GitHub Actions, flavors, release process

**Done when:** a reader has a repeatable workflow for finding and fixing a dropped frame,
a leak, and a flaky test.

---

## Milestone 4 — Scale & Careers (`v1.0`)

> Branch: `release/v1.0` · Parts 5 and 6, appendix

- [ ] Enterprise Flutter — modularization, team workflow, observability, design systems
- [ ] Interviews — system design, coding round, question bank, HR round
- [ ] Appendix — glossary, further reading, tooling reference
- [ ] Cheatsheets
- [ ] Full editorial pass against the style guide

**Done when:** every page has content, no page is marked *Draft*, and `mkdocs build
--strict` is clean.

---

## Ongoing

Not tied to a milestone, welcome at any time:

- Corrections and version updates as Flutter releases land
- Measured numbers replacing assertions
- Diagrams for sections that currently explain in prose only
- Translations, once the English content settles

---

## Branch strategy

```
main                 Stable, published site. Protected — PRs only.
develop              Integration branch. Chapters merge here first.
feature/chapter-NN   One milestone's content. Branched from develop.
release/v1.0         Release stabilisation. Branched from develop, merged to
                     main and back to develop, then tagged.
```

Day to day:

```bash
git switch develop
git switch -c feature/chapter-01
# ... work, commit with Conventional Commits ...
git push -u origin feature/chapter-01
# open a PR into develop
```

Smaller work that does not belong to a chapter — a correction, a CI fix — branches from
`develop` as `fix/...`, `docs/...`, or `chore/...` and merges back the same way.
