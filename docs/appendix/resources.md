# Further reading

Sources worth your time, with a note on what each is actually good for — and what it is not.

## Read the source

The highest-value habit in Flutter, and the least used. The framework ships with its source, and
it is written to be read: `Element.updateChild`, `StatefulWidget`, `RenderBox.layout` and
`BuildOwner.buildScope` each answer a question no article answers as precisely.

- **Ctrl/Cmd-click any framework symbol in your IDE.** That is the whole technique.
- **`flutter/packages/flutter/lib/src/`** — the framework, organised by library.
- **The dartdoc on `Element`, `RenderObject` and `BuildOwner`** is a design document in comment
  form.

When a page in this handbook and the source disagree, the source is right and the page has a
bug — [please report it](https://github.com/ma-mamun/flutter-engineering-handbook/issues).

## Official documentation

- **[docs.flutter.dev](https://docs.flutter.dev)** — reference and tutorials. Best for API
  surface and setup, weakest on "why" and on tradeoffs.
- **[Flutter architectural overview](https://docs.flutter.dev/resources/architectural-overview)**
  — the closest official document to Part 1 of this handbook.
- **[dart.dev/language](https://dart.dev/language)** — the language tour, kept current with each
  release.
- **[Flutter release notes and breaking changes](https://docs.flutter.dev/release/breaking-changes)**
  — read before every SDK upgrade. This is the page that saves a day.
- **[api.flutter.dev](https://api.flutter.dev)** — the dartdoc, which is often more detailed
  than the guides.
- **[Flutter wiki](https://github.com/flutter/flutter/wiki)** — design docs and engine internals,
  for when the public documentation stops.

## Talks worth the hour

- **"Flutter's Rendering Pipeline"** (Adam Barth) — still the clearest explanation of the three
  trees, and the reason so much of Part 1 uses the same vocabulary.
- **"How Flutter Renders Widgets"** — the element tree, from the framework team.
- **Flutter Engage / Google I/O sessions on Impeller** — for the shader jank story and where
  rendering is going.
- **"Dart Isolates" and DartConf async talks** — the event loop, from the language team.

## Long-form and books

Flutter books date quickly; the ones that hold up are about engineering rather than API.

- **"Refactoring" (Fowler)** — the vocabulary for naming what is wrong with code in review.
- **"Designing Data-Intensive Applications" (Kleppmann)** — the sync, conflict and consistency
  chapters are directly applicable to offline-first mobile, and better than anything
  mobile-specific.
- **"Release It!" (Nygard)** — timeouts, retries, circuit breakers and failure modes.
- **"A Philosophy of Software Design" (Ousterhout)** — short, and the best available argument
  about where abstraction earns its cost.
- **"Accelerate" (Forsgren, Humble, Kim)** — what actually correlates with delivery performance,
  for the arguments in Part 5.

## Communities

- **[GitHub issues on flutter/flutter](https://github.com/flutter/flutter/issues)** — search here
  first when something behaves oddly. The answer is frequently an issue with a workaround.
- **[Stack Overflow, `flutter` tag](https://stackoverflow.com/questions/tagged/flutter)** — good
  for specific errors, less good for architecture opinions.
- **[r/FlutterDev](https://reddit.com/r/FlutterDev)** and the Flutter Discord — useful for
  ecosystem news and for finding out what people actually use.
- **[pub.dev](https://pub.dev)** — read the scores, but read the *issue tracker and last commit
  date* before depending on anything.

## Evaluating a package

Applying the same checklist every time is worth more than any list of recommended packages,
because the list ages and the checklist does not:

- **Last commit and open issue count.** Both, together — a busy issue tracker on an active
  project is healthy; an empty one on a stale project is not.
- **Bus factor.** One maintainer is a risk you can accept knowingly, not one to discover later.
- **How hard is it to leave?** A package behind an interface you own is replaceable. A package
  that is also your router and DI is not.
- **Size cost**, measured with `--analyze-size`, not guessed.
- **Test coverage in the package itself**, and whether it is testable from your side.
- **Null safety, current SDK support, and platform coverage** matching what you ship.

## Keeping current

- **Flutter release notes** on every stable release, which is roughly quarterly.
- **The breaking changes page** before upgrading, always.
- **`dart pub outdated`** on a schedule rather than in a panic before a release.
- **Test against beta in CI** on a nightly job, so a framework change is your problem before it
  is your users'.

## About this handbook

Corrections, measured numbers replacing assertions, and version updates as Flutter releases land
are all welcome. See the
[contributing guide](../contributing.md), the [style guide](../style-guide.md) and the
[roadmap](../roadmap.md).
