# Flutter Engineering Handbook

> A comprehensive open-source handbook for Flutter engineers.

Most Flutter material stops at "here is a widget." This handbook picks up where the
tutorials end: how to structure an app that four people work on for two years, how to
keep the test suite fast and honest, how to find the frame that drops, and how to get a
build into a store without a release-day scramble.

## Who it is for

- Flutter Developers
- Senior Software Engineers
- Mobile Architects
- Tech Leads
- Engineering Managers
- Interview Candidates

## How it is organised

<div class="grid cards" markdown>

- :material-rocket-launch: **[Getting Started](getting-started/index.md)**

    Environment, project layout, day-one tooling.

- :material-language-go: **[Dart](dart/index.md)**

    The language features Flutter actually leans on.

- :material-flutter: **[Flutter Framework](framework/index.md)**

    Three trees, the rendering pipeline, and the widget lifecycle.

- :material-layers-triple: **[Architecture](architecture/index.md)**

    Clean Architecture, dependency injection, navigation, error handling.

- :material-state-machine: **[State Management](state-management/index.md)**

    Choosing an approach, then living with it — Riverpod and BLoC.

- :material-database: **[Data](data/index.md)**

    Networking, offline first, SQLite, Drift, Isar, Hive.

- :material-shield-lock: **[Security](security/index.md)**

    Secure storage, network security, obfuscation and hardening.

- :material-speedometer: **[Performance](performance/index.md)**

    Rendering, memory, build size, profiling.

- :material-test-tube: **[Testing](testing/index.md)**

    Unit, widget, integration, golden.

- :material-cellphone-link: **[Native Integration](native/index.md)**

    Platform channels, FFI, writing plugins.

- :material-infinity: **[CI/CD](ci-cd/index.md)**

    GitHub Actions, flavors, release process.

- :material-office-building: **[Enterprise Flutter](enterprise/index.md)**

    Modularization, team workflow, observability.

- :material-account-tie: **[Interviews](interviews/index.md)**

    System design, coding rounds, HR rounds.

</div>

## How to read it

Sections are independent. Jump to whatever is on fire.

Two conventions run throughout:

- **Recommendation first, justification second.** You should know what to do by the end
  of the opening paragraph.
- **Every technique names its cost.** A rule without a stated tradeoff is a rule nobody
  can apply, so if a page tells you to do something it also tells you when not to.

Code samples live under `code/` in the repository and are embedded into these pages, so
everything you see here is formatted and analyzed by CI rather than rotting in a Markdown
fence.

## Status

🚧 **Work in progress.** The structure is complete; sections are being filled in. Pages
marked *Draft* are outlines — those are the easiest places to make a first contribution.
See [Contributing](contributing.md) and the
[roadmap](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/ROADMAP.md).

## License

Released under the [MIT License](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/LICENSE).
