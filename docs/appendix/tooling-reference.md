# Tooling reference

Commands and flags collected in one place, with a note on when each is the right one.

## Diagnosis

```bash
flutter doctor -v                    # first thing to run when anything is odd
flutter --version                    # exact SDK, channel and framework revision
dart pub deps --style=compact        # who pulled in that transitive package
dart pub outdated                    # what can move, and what is blocking it
flutter pub cache repair             # when dependencies are mysteriously broken
flutter clean                        # last resort; it costs a full rebuild
```

## Analysis and formatting

```bash
flutter analyze                      # the analyzer, non-interactively
flutter analyze --fatal-infos        # what CI should run
dart format .                        # format in place
dart format --output=none --set-exit-if-changed .   # CI check, no writes
dart fix --dry-run                   # what the machine can fix
dart fix --apply                     # apply it — makes new lints affordable
```

## Running

```bash
flutter run                          # debug: JIT, assertions, hot reload
flutter run --profile                # AOT plus tracing — all measurement
flutter run --release                # what users get
flutter run --flavor staging --dart-define-from-file=config/staging.json
flutter run --profile --trace-startup        # startup checkpoints, written to disk
flutter run -d chrome --web-renderer canvaskit
flutter devices                      # what is connected
```

`r` hot reload, `R` hot restart, `p` widget outlines, `o` toggle platform, `q` quit.

## Testing

```bash
flutter test                                 # everything under test/
flutter test test/features/auth              # one directory
flutter test --name "refreshes the token"    # by name
flutter test --coverage                      # writes coverage/lcov.info
flutter test --reporter=expanded             # readable failures in CI logs
flutter test --update-goldens                # rewrite golden images
flutter test --total-shards=4 --shard-index=0   # split a large suite
flutter test integration_test                # on a connected device
genhtml coverage/lcov.info -o coverage/html  # browsable coverage report
```

## Building

```bash
flutter build appbundle --release            # what you upload to Play
flutter build apk --release --split-per-abi  # direct distribution
flutter build ipa --release                  # iOS archive
flutter build web --release

# The release build worth actually shipping:
flutter build appbundle --release \
  --flavor prod \
  --dart-define-from-file=config/prod.json \
  --obfuscate --split-debug-info=build/symbols/$VERSION \
  --build-name=1.4.2 --build-number=$BUILD_NUMBER
```

Size analysis:

```bash
flutter build appbundle --analyze-size --target-platform android-arm64
dart devtools --appSizeBase=build/app-size-analysis.json
dart devtools --appSizeBase=before.json --appSizeTest=after.json   # attribute growth
```

## Symbolication

```bash
flutter symbolize -i crash.txt -d build/symbols/1.4.2/app.android-arm64.symbols
```

Archive `build/symbols/` per build, keyed by version and build number. They cannot be
regenerated, and without them crash reports from that build are unreadable.

## DevTools

```bash
dart devtools                        # standalone
flutter run                          # then open the printed DevTools URL
```

| View | Answers |
| --- | --- |
| Performance | Which thread and which phase is over budget |
| CPU profiler | Which function the Dart time is in |
| Memory | What is retained, and by what |
| Widget inspector | What the tree looks like, and what rebuilt |
| Network | Which requests, how long, what payload |
| Logging | Framework and app logs, filterable |
| App size | Where the megabytes are |

## Debug flags

```dart
import 'package:flutter/rendering.dart';

debugPaintSizeEnabled = true;         // layout boxes and padding
debugRepaintRainbowEnabled = true;    // a colour change means that layer repainted
debugPaintPointersEnabled = true;     // highlight tapped regions
debugPrintBeginFrameBanner = true;    // frame boundaries in the log
debugProfileBuildsEnabled = true;     // per-widget build events in the timeline
timeDilation = 5.0;                   // slow animations down
debugDumpRenderTree();                // sizes and constraints for the whole tree
debugDumpApp();                       // the widget tree
```

## Code generation

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
dart run build_runner clean

dart run pigeon --input pigeons/api.dart --dart_out lib/api.g.dart \
  --kotlin_out android/.../Api.kt --swift_out ios/Runner/Api.swift
dart run ffigen --config ffigen.yaml
dart run drift_dev schema dump lib/database.dart drift_schemas/
```

## Monorepo

```bash
dart pub global activate melos
melos bootstrap                      # link local packages
melos run test                       # a script from melos.yaml
melos exec --diff=origin/main -- flutter test    # only what changed
melos version                        # bump and changelog from commits
melos publish --dry-run
```

## Platform

```bash
# Android
adb devices
adb logcat -s flutter                     # Flutter logs only
adb shell dumpsys meminfo <package>       # native, graphics and Java memory
adb shell pm get-app-links <package>      # deep link verification state
adb shell pm grant <package> android.permission.CAMERA
adb uninstall <package>

# iOS
xcrun simctl list devices
xcrun simctl openurl booted "myapp://orders/42"        # test a deep link
xcrun simctl privacy booted grant photos <bundle-id>
open ios/Runner.xcworkspace                            # schemes and signing
pod install --repo-update                              # from ios/
```

## Git

```bash
git switch -c feat/order-filters main
git rebase main                      # your own branch only, never a shared one
git rebase -i HEAD~3                 # tidy commits before review
git cherry-pick <sha>                # one commit onto a release branch
git bisect start / bad / good <sha>  # find the commit that broke it
git log --oneline --graph --all
git log -S "searchTerm"              # commits that changed that string
```

## Release

```bash
# Fastlane
bundle exec fastlane android internal
bundle exec fastlane ios beta
bundle exec fastlane match development   # shared iOS certificates

# Versioning
BUILD_NUMBER=$(git rev-list --count HEAD)
git tag -a v1.4.2 -m "Release 1.4.2" && git push origin v1.4.2
```

## This repository

```bash
./scripts/serve.sh                   # mkdocs serve with live reload
./scripts/build.sh                   # mkdocs build --strict
./scripts/check.sh                   # everything CI runs, in one command
./scripts/new-page.sh part-03-data/caching.md "Caching"
```

## See also

- [Tooling](../part-02-professional/tooling.md) — why these settings, not just what
- [Profiling](../part-04-production/performance-profiling.md) — the DevTools workflow
- [Release process](../part-04-production/release-process.md) — what to run and when
- [Further reading](resources.md) — where the documentation lives
