# Golden tests

Pixel-level regression tests, including the font and platform problems everyone hits in CI.

## The recommendation

**Golden test your design system components and a few complete screens, and generate the
goldens in the same environment CI uses.** They catch the regressions no other test level can
— spacing, colour, theming, overflow, dark mode — and they fail for environmental reasons
unless you control the environment. That control is the whole difficulty; the tests
themselves are three lines.

## The shape of one

```dart
testWidgets('primary button matches its golden', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: const Scaffold(body: Center(child: PrimaryButton(label: 'Submit'))),
    ),
  );

  await expectLater(
    find.byType(PrimaryButton),
    matchesGoldenFile('goldens/primary_button.png'),
  );
});
```

```bash
flutter test --update-goldens          # write or refresh the images
flutter test                           # compare against them
```

## What they catch that nothing else does

- **Spacing and alignment drift** from a padding change three layers up.
- **Theme regressions** — a colour token changed and eleven components moved with it.
- **Dark mode and text-scale breakage**, which is otherwise only found by a user.
- **Overflow**, which a structural widget test happily ignores because the widget is still
  there.

What they do not catch: behaviour, state, navigation. Goldens complement
[widget tests](testing-widget.md); they do not replace them.

## The font problem

The first golden test almost everyone writes produces a picture of rectangles. Flutter's test
environment ships with **Ahem**, a placeholder font where every glyph is a filled box, so no
real font is loaded unless you load it.

```dart
// test/flutter_test_config.dart — runs before every test in the suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();      // from golden_toolkit / alchemist
  return testMain();
}
```

Rolling it yourself is a dozen lines: read each font file from the asset bundle and register
it with `FontLoader`. Either way, the rule is that **the golden must be generated with the
same fonts CI loads**, or every run differs.

Material icons are a font too, and an unloaded icon font is why a golden shows an empty
square where a chevron should be.

## The platform problem

The same widget renders slightly differently on macOS and Linux — anti-aliasing, font
hinting, and shadow rasterisation all vary. A golden generated on a developer's Mac fails on a
Linux CI runner by a fraction of a percent, every time.

Three ways out, in order of preference:

**1. Generate goldens in the CI environment.** A container or CI job produces the images and
commits them. One environment, one truth, no drift.

```yaml
- name: Update goldens
  run: docker run --rm -v $PWD:/app -w /app ghcr.io/cirruslabs/flutter:3.24.0 \
       flutter test --update-goldens --tags golden
```

**2. Allow a small difference threshold.** Alchemist and custom comparators support a
tolerance, so sub-pixel differences pass while real changes fail. Keep it tight — a 5%
tolerance hides genuine regressions.

**3. Restrict goldens to one platform.** `@Tags(['golden'])` plus a CI job that only runs them
on Linux, skipped locally on macOS. Simple, and it means developers cannot check their own
changes before pushing — which is a real cost.

## Toolkits

| | Raw `matchesGoldenFile` | `golden_toolkit` | `alchemist` |
| --- | --- | --- | --- |
| Font loading | Manual | `loadAppFonts()` | Built in |
| Device variants | Manual | `multiScreenGolden` | Built in |
| Difference tolerance | No | No | Yes |
| CI/local separation | Manual | Manual | First class |
| Maintenance | n/a | Maintenance mode | Active |

`alchemist` is the current recommendation: it distinguishes CI goldens from local goldens
explicitly, which addresses the platform problem by design rather than by convention.

```dart
goldenTest(
  'PrimaryButton renders in every state',
  fileName: 'primary_button',
  builder: () => GoldenTestGroup(
    children: [
      GoldenTestScenario(name: 'default', child: const PrimaryButton(label: 'Submit')),
      GoldenTestScenario(name: 'loading', child: const PrimaryButton(label: 'Submit', isLoading: true)),
      GoldenTestScenario(name: 'disabled', child: const PrimaryButton(label: 'Submit', onPressed: null)),
    ],
  ),
);
```

One image with every state of a component is easier to review than five separate ones, and it
makes an unintended change to one state obvious.

## Reviewing and updating

**Treat a golden change like a code change.** A diff in a PNG is a visual change to your
product, and it should be looked at by a human. Two habits make that practical:

- **Never run `--update-goldens` to make a red build green** without looking at the image.
  That single habit is the difference between goldens catching regressions and goldens
  recording them.
- **Attach failure images to the CI run.** On failure Flutter writes
  `failures/*_testImage.png`, `*_masterImage.png` and `*_isolatedDiff.png` to the test
  directory. Upload them as artefacts, and the review happens in the browser rather than by
  checking out the branch.

```yaml
- uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: golden-failures
    path: '**/failures/*.png'
```

Keep goldens small and focused: one component, one state, a fixed surface size. A
full-screen golden fails whenever anything on that screen moves, which trains people to
update without looking.

## What to make deterministic

Anything non-deterministic produces a flaky golden:

- **Time** — inject a fixed clock, or "2 minutes ago" changes the image on every run.
- **Randomness** — a seeded `Random`, or fixed fixtures.
- **Animations** — pump to a known frame, or disable them.
- **Network images** — never in a golden; use a local asset or a fake provider.
- **Text scale and locale** — set them explicitly rather than inheriting the environment.

## Interview angles

**"Why golden tests?"** They catch visual regressions — spacing, colour, theming, dark mode,
overflow — that structural widget tests pass straight through. Then name the cost: they are
environment-sensitive, so goldens must be generated where CI runs them.

**"Why do goldens show rectangles?"** The test environment uses the Ahem placeholder font
unless you load real fonts, usually via `flutter_test_config.dart`.

**"Why do they fail on CI but pass locally?"** Font rendering and anti-aliasing differ between
macOS and Linux. Generate them in the CI environment, allow a tight tolerance, or restrict
them to one platform.

**"How do you review a golden change?"** As a visual change to the product: look at the diff
image, which CI uploads on failure. Never blind-update to go green.

## See also

- [Widget tests](testing-widget.md) — behaviour, where goldens cover appearance
- [Design systems](../part-05-enterprise/design-systems.md) — what to golden first
- [GitHub Actions](../part-04-production/ci-github-actions.md) — generating goldens in CI
- [Testing cheatsheet](../cheatsheets/testing.md) — the one-page version
