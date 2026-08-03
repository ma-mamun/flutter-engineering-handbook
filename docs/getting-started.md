# Getting Started

This page gets you a Flutter environment you can trust and shows you how the handbook is
put together. It takes about twenty minutes if you are starting from nothing.

## Install Flutter

Follow the [official install guide](https://docs.flutter.dev/get-started/install) for
your platform, then confirm the toolchain is complete:

```bash
flutter doctor -v
```

Fix everything it flags before going further. A half-configured Android SDK produces
errors much later that look like anything but a missing SDK.

!!! tip "Pin the version"
    On a team, pin the SDK with [FVM](https://fvm.app) and commit the pin. A `.fvmrc`
    in the repository means "works on my machine" stops being a category of bug.

    ```bash
    dart pub global activate fvm
    fvm use 3.24.0 --force
    ```

    The cost is one more tool in the chain and an `fvm` prefix on commands. On a solo
    project that is usually not worth it; on a team of four it pays for itself the first
    time someone upgrades.

## Read the handbook locally

The published site is the best reading experience, but you can run it yourself:

```bash
git clone https://github.com/ma-mamun/flutter-engineering-handbook.git
cd flutter-engineering-handbook

python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

mkdocs serve
```

Open <http://127.0.0.1:8000>. Edits to any page reload the browser immediately.

There are helper scripts for the common tasks:

```bash
./scripts/serve.sh    # live preview
./scripts/build.sh    # strict build into site/
./scripts/check.sh    # everything CI runs
```

## How the handbook is organised

Six parts, ordered by when you need them rather than by difficulty:

| Part | Covers | Read it when |
| --- | --- | --- |
| [1 — Foundations](part-01-foundations/index.md) | Dart, three trees, rendering, layout | You want to know why, not just how |
| [2 — Professional](part-02-professional/index.md) | Structure, architecture, state, testing | The app outgrew one file |
| [3 — Data](part-03-data/index.md) | Networking, offline, local databases | The network is unreliable |
| [4 — Production](part-04-production/index.md) | Security, performance, native, release | You are about to ship |
| [5 — Enterprise](part-05-enterprise/index.md) | Modularization, workflow, observability | The team grew past a handful |
| [6 — Interviews](part-06-interviews/index.md) | System design, coding, HR | You are hiring or being hired |

The [appendix](appendix/index.md) holds a glossary and reference material.
[Cheatsheets](cheatsheets/index.md) are one-page references with no prose — the things
you look up rather than read.

## How to read the code samples

Samples live in `code/` in the repository, grouped by topic, and are embedded into pages
rather than pasted. Every one is formatted, analyzed, and where sensible tested by CI, so
what you see on a page compiles.

To run them:

```bash
cd code
flutter pub get
flutter test testing
```

Sample code is MIT licensed — copy it into your project without attribution.

## Where to go next

- New to Flutter internals → [Part 1 — Foundations](part-01-foundations/index.md)
- Restructuring an existing app → [Project Structure](part-02-professional/project-structure.md)
- Chasing a performance problem → [Profiling](part-04-production/performance-profiling.md)
- Preparing for an interview → [Part 6 — Interviews](part-06-interviews/index.md)
- Wanting to contribute → [Contributing](contributing.md) and the [style guide](style-guide.md)
