# Build size

Where the megabytes are, and which ones you can actually remove.

## The recommendation

**Measure first with `--analyze-size`, then cut in this order: app bundle over APK, assets,
fonts, dependencies, deferred components.** Most apps find their largest win in assets rather
than in code, and most teams look at code first. Size matters commercially — install
conversion drops measurably as size grows, and on Android over 150 MB the base APK needs
expansion handling.

## Measure

```bash
flutter build appbundle --analyze-size --target-platform android-arm64
flutter build ipa --analyze-size
```

The output is a tree — Dart AOT snapshot, the Flutter engine, assets, native libraries — and
DevTools opens the same file interactively:

```bash
dart devtools --appSizeBase=build/app-size-analysis.json
```

Compare two builds to attribute growth to a change:

```bash
dart devtools --appSizeBase=before.json --appSizeTest=after.json
```

That diff is the tool that makes size a reviewable property rather than a periodic panic.
Wire it into CI and print the delta on every pull request — a 4 MB dependency is much easier
to reject before it is merged.

## What a Flutter app is made of

Rough shares for a typical release build, and what can be done about each:

| Part | Typical | What helps |
| --- | --- | --- |
| Flutter engine | 4–6 MB per ABI | Nothing — it is the floor |
| Dart AOT snapshot | 2–10 MB | Fewer and smaller dependencies; tree shaking does the rest |
| Assets | 1 MB – 50 MB+ | Compression, correct formats, removing unused ones |
| Fonts | 100 KB – 5 MB | Subsetting, fewer weights |
| Native libraries | Varies | Split per ABI |

The engine is the floor: a hello-world release APK is around 6–7 MB per ABI, and no amount of
work reduces it.

## Ship the right artefact

**Android: an app bundle, always.** Google Play generates a per-device APK containing one ABI
and the matching density resources, which typically takes 30–40% off what the user downloads.

```bash
flutter build appbundle --release
```

If you must ship APKs directly — enterprise distribution, another store — split them:

```bash
flutter build apk --release --split-per-abi
```

Never ship a universal APK to users. It contains every ABI, so every device downloads code
for architectures it cannot run.

**iOS:** App Store thinning handles this automatically. What you control is bitcode (removed
in Xcode 14), on-demand resources for large optional assets, and the asset catalogue.

## Assets

Usually the largest addressable win, and the one most easily neglected:

- **Audit for unused files.** Assets accumulate; nothing removes them. A quick grep of every
  filename against the source finds the ones no code references.
- **Right format.** WebP over PNG or JPEG — typically 25–35% smaller at the same quality, and
  supported on both platforms. SVG (via `flutter_svg`) for icons and simple illustrations,
  where one file replaces three resolutions.
- **Right resolutions.** Ship 2.0x and 3.0x; 1.0x devices are effectively gone, and 4.0x
  assets are wasted bytes.
- **Compress.** `pngquant`, `cwebp`, `jpegoptim` — routinely 50%+ with no visible difference.
  Put it in a script so it happens on every asset, not on the ones somebody remembered.
- **Do not bundle what can be downloaded.** Onboarding videos, large illustration sets and
  optional content belong behind a fetch, not in the install.

## Fonts

A full font family with four weights and italics is easily 2 MB. Two fixes:

**Subset to the glyphs you use.** Flutter does this automatically for icon fonts in release
builds — the `--no-tree-shake-icons` flag exists to turn it off, and there is rarely a reason
to. For text fonts, `fonttools`:

```bash
pyftsubset Font.ttf --unicodes="U+0000-00FF,U+2000-206F" --output-file=Font-subset.ttf
```

Be careful with subsetting when you support multiple scripts — dropping a range breaks that
language silently, and the failure is boxes on a user's screen rather than a build error.

**Ship fewer weights.** Regular and one bold covers most designs. Each additional weight is a
whole file.

## Dependencies

```bash
flutter pub deps --style=compact     # what is in here, and who pulled it in
```

Two habits keep this under control: check the size cost of a package before adding it — the
`--analyze-size` diff makes it a number — and periodically look for packages pulled in for one
function. A date formatting helper that drags in a full internationalisation dataset is worth
replacing with ten lines.

`intl` deserves specific mention: loading every locale's data when the app supports three is
common and avoidable.

## Deferred components

Deferred loading splits code out of the initial download and fetches it on demand. On Android
this is real (Play Feature Delivery); on iOS the code is still in the binary, so the win is
memory and startup rather than download size.

```dart
import 'package:my_app/features/reports.dart' deferred as reports;

Future<void> openReports() async {
  await reports.loadLibrary();     // downloads and links on first use
  runApp(reports.ReportsApp());
}
```

Worth it for a genuinely optional, genuinely large feature — an admin console, a rarely used
scanner, a heavy chart library. The cost is a loading state to design, an error path when the
download fails, and testing an install that has not fetched the module yet. For anything under
a couple of megabytes, that complexity is not repaid.

## Build flags

```bash
flutter build appbundle \
  --release \
  --obfuscate --split-debug-info=build/symbols/$VERSION   # smaller and unreadable
```

`--split-debug-info` alone removes debug symbols from the binary, which is a real size
reduction. Combine it with `--obfuscate` and archive the symbols — see
[obfuscation and hardening](security-hardening.md).

On Android, `minifyEnabled` and `shrinkResources` shrink the Java/Kotlin side and drop
unreferenced resources. They affect plugins rather than your Dart code, and they need keep
rules for anything used by reflection.

## A realistic target

For a normal app with images and a few dozen dependencies: **15–25 MB download on Android**
after bundle splitting, **30–50 MB on iOS** after thinning. Under 10 MB is achievable only
with very few assets. Above 60 MB, look at assets first — it is nearly always assets.

Track it per release. A number that grows 2 MB per release without anyone noticing is the
normal failure mode, and a CI check that prints the delta is what prevents it.

## Interview angles

**"How do you reduce APK size?"** Measure with `--analyze-size` first, ship an app bundle,
then assets — format, resolutions, compression, unused files — then fonts, then dependencies,
then deferred components for genuinely optional features. Naming the order matters; jumping
to deferred components signals guessing.

**"How does ProGuard/R8 work?"** It traces reachable code from entry points and removes the
rest, then obfuscates names. On a Flutter app it affects plugins and native code, not Dart —
and anything reached only by reflection needs a keep rule, which is why the crash it causes
appears in release only.

**"Why is a Flutter app bigger than a native one?"** It ships its own engine and rendering
stack — a fixed 4–6 MB per ABI. That is the floor, and it is the price of not depending on
platform UI toolkits.

**"How do you stop size from creeping?"** A CI job that runs `--analyze-size` and prints the
delta on every PR. A dependency is much easier to argue about before it is merged.

## See also

- [Release process](release-process.md) — building the artefacts you ship
- [Obfuscation and hardening](security-hardening.md) — the same flags, security angle
- [GitHub Actions](ci-github-actions.md) — automating the size check
- [Profiling](performance-profiling.md) — the measure-first habit, applied elsewhere
