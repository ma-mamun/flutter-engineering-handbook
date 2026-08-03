# Flutter Engineering Handbook

> A comprehensive open-source handbook for Flutter engineers.

## Vision

Build the most comprehensive Flutter engineering handbook for developers ranging from
intermediate to staff engineer.

This project focuses on practical engineering rather than memorizing interview questions.

## Who it is for

- Flutter Developers
- Senior Software Engineers
- Mobile Architects
- Tech Leads
- Engineering Managers
- Interview Candidates

## The six parts

<div class="grid cards" markdown>

- :material-cube-outline: **[Part 1 — Foundations](part-01-foundations/index.md)**

    Dart, the three trees, the rendering pipeline, the widget lifecycle, layout.

- :material-layers-triple: **[Part 2 — Professional Flutter](part-02-professional/index.md)**

    Project structure, Clean Architecture, DI, navigation, state management, testing.

- :material-database: **[Part 3 — Data](part-03-data/index.md)**

    Networking, offline first, SQLite, Drift, Isar, Hive.

- :material-rocket-launch: **[Part 4 — Production](part-04-production/index.md)**

    Security, performance, native integration, CI/CD, release.

- :material-office-building: **[Part 5 — Enterprise Flutter](part-05-enterprise/index.md)**

    Modularization, team workflow, observability, design systems.

- :material-account-tie: **[Part 6 — Interviews](part-06-interviews/index.md)**

    System design, coding rounds, a question bank, the HR round.

</div>

Plus an [appendix](appendix/index.md) for reference material and
[cheatsheets](cheatsheets/index.md) for the things you look up rather than read.

## How to read it

Start with [Getting Started](getting-started.md) if you want the tour. Otherwise the
parts are independent — jump to whatever is on fire.

Two conventions run throughout, both spelled out in the [style guide](style-guide.md):

- **Recommendation first, justification second.** You should know what to do by the end
  of the opening paragraph.
- **Every technique names its cost.** A rule without a stated tradeoff is a rule nobody
  can apply, so if a page tells you to do something it also tells you when not to.

Code samples live under `code/` in the repository and are embedded into these pages, so
everything you see here is formatted and analyzed by CI rather than rotting in a Markdown
fence.

## Status

✅ **v1.0 — complete.** All six parts, the appendix and the cheatsheets are written; no page
is an outline. The handbook stays a living document: corrections, measured numbers replacing
assertions, and updates as Flutter releases land are all welcome. See the
[roadmap](roadmap.md) and the [contributing guide](contributing.md).

## License

Released under the [MIT License](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/LICENSE).
