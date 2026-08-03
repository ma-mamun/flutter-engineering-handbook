# Tooling

Analyzer, formatter and code generation — the setup that catches mistakes before a reviewer
has to.

## The recommendation

Turn on a strict analyzer on day one and treat its output as build failure. Every lint you
enable later has to be applied to code that already exists, which is why teams stop at the
defaults. `flutter_lints` plus the three `strict-` language flags is the baseline worth
starting from.

## analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true       # no implicit dynamic -> T
    strict-inference: true   # no silently inferred dynamic
    strict-raw-types: true   # List, not List<dynamic>
  errors:
    invalid_annotation_target: ignore   # freezed noise
    todo: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/generated_plugin_registrant.dart"

linter:
  rules:
    - always_declare_return_types
    - avoid_print                    # use a logger; print survives into release
    - prefer_final_locals
    - prefer_single_quotes
    - require_trailing_commas        # stable formatting, smaller diffs
    - unawaited_futures              # catches fire-and-forget failures
    - use_build_context_synchronously # the async-gap crash
    - cancel_subscriptions
    - close_sinks
    - avoid_slow_async_io
```

The three that repay the most:

- **`strict-casts`** turns silent `dynamic` casts into compile errors, which is the entire
  class of "JSON gave me a String where I typed int".
- **`use_build_context_synchronously`** catches the context-after-await crash the
  [lifecycle page](../part-01-foundations/widget-lifecycle.md) describes.
- **`unawaited_futures`** finds the fire-and-forget call whose failure nobody sees.

**The cost:** on an existing codebase, enabling these produces hundreds of warnings.
Enable them one at a time, fix, and land each as its own commit — a single "fix all lints"
PR is unreviewable, and it is where behaviour changes hide.

### Excluding generated code

Generated files should never be linted or formatted; they are outputs. Exclude them in the
analyzer and add `*.g.dart` to `.gitignore` **only if** CI regenerates them. Committing
generated code makes builds reproducible and reviews noisier; regenerating keeps reviews
clean and makes a stale generator a broken build. Either is defensible — pick one and write
down which.

## Formatting

`dart format` has no options worth arguing about, which is the point. Run it in CI so the
argument never happens:

```bash
dart format --output=none --set-exit-if-changed .
```

Two supporting habits:

- **`require_trailing_commas`.** With a trailing comma the formatter breaks arguments one
  per line, which makes a one-argument change a one-line diff instead of a reflow.
- **Format on save** in every editor, checked into `.vscode/settings.json` and
  `.editorconfig` so it is not per-developer configuration.

As of Dart 3.7 the formatter reflows more aggressively than earlier versions. Bumping the
SDK reformats the codebase, so do it as a mechanical commit of its own — a formatting change
mixed into a feature PR makes the feature unreviewable.

## Code generation

`build_runner` drives every generator in the ecosystem:

```bash
dart run build_runner build --delete-conflicting-outputs   # once
dart run build_runner watch --delete-conflicting-outputs   # while developing
```

`--delete-conflicting-outputs` is not optional in practice; without it a renamed file
produces a conflict that stops the build with an unhelpful message.

| Generator | Generates | Worth it when |
| --- | --- | --- |
| `json_serializable` | `fromJson`/`toJson` | More than a handful of DTOs |
| `freezed` | Unions, `copyWith`, equality | You want sealed classes with less typing |
| `drift` | Type-safe SQL and DAOs | You are using Drift at all |
| `go_router_builder` | Typed routes | More than a dozen routes |
| `injectable` | `get_it` registrations | More than ~30 registrations |
| `flutter_gen` | Typed asset and font references | Any app with assets |
| `mockito` | Mocks | You prefer mocks to fakes |

**The cost is build time**, and it compounds: a large app can spend minutes in
`build_runner`. Two mitigations that matter — cache `.dart_tool/build` in CI, and prefer
generators that support incremental builds. Dart 3's records and sealed classes have made
`freezed` less necessary than it was; for a simple immutable class, hand-writing `copyWith`
is often cheaper than the generator round trip.

## The CLI worth knowing

```bash
flutter doctor -v                       # first thing to run when anything is odd
flutter analyze                         # the analyzer, non-interactively
flutter test --coverage                 # coverage/lcov.info
flutter test --reporter=expanded        # readable failures in CI logs
flutter build appbundle --analyze-size  # where the megabytes went
flutter run --profile --trace-startup   # startup timings on a real device
dart fix --apply                        # auto-fix lints that have a machine fix
dart pub outdated                       # what can move, and what is blocking it
dart pub deps --style=compact           # who pulled in that transitive package
flutter pub cache repair                # when dependencies are mysteriously broken
```

`dart fix --apply` is the tool that makes enabling a new lint affordable — it mechanically
fixes the majority, leaving you to review the rest.

## Pre-commit and CI

Run the same commands locally and in CI, from one script, so "works on my machine" cannot
happen. This repository's `scripts/check.sh` is exactly that: build the docs, format,
analyze, test — one command, and CI runs the same one.

```bash
#!/usr/bin/env bash
set -euo pipefail
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Prefer a CI gate over a git hook. Hooks are per-developer, skippable with `--no-verify`, and
silently absent for anyone who cloned before you added them. A hook that only runs `dart
format` on staged files is a reasonable convenience; a hook as the only enforcement is not
enforcement.

## Interview angles

**"How do you keep code quality consistent across a team?"** A strict analyzer treated as a
build failure, one formatter with no options, and one script that CI and developers both
run. Then the honest part: enable lints incrementally, because a thousand-warning PR gets
rubber-stamped.

**"What does `strict-casts` do?"** Turns implicit `dynamic` downcasts into compile errors —
the class of bug where a JSON field is the wrong type and fails three screens later.

**"Do you commit generated code?"** Either answer is fine if you can defend it: committing
makes builds reproducible and reviews noisy; regenerating keeps reviews clean and requires
CI to run the generator. What is not fine is not having decided.

## See also

- [Project structure](project-structure.md) — where configuration files live
- [Unit tests](testing-unit.md) — what the test command is checking
- [GitHub Actions](../part-04-production/ci-github-actions.md) — running this in CI
- [Tooling reference](../appendix/tooling-reference.md) — the full command list
