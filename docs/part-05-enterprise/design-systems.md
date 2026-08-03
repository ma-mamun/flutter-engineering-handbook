# Design systems

One visual language across many teams and many screens — including white-label apps where the
brand is a configuration.

## The recommendation

**Tokens in `ThemeExtension`, components in a package, and a rule that no feature hardcodes a
colour or a spacing value.** The theme is the contract between design and engineering; the
component package is how it gets applied consistently. Without the rule, both decay into
suggestions within a quarter.

## Tokens as theme extensions

Material's `ThemeData` does not have a slot for your semantic colours, and hardcoding them
means a rebrand touches every file. `ThemeExtension` gives you typed, themed, interpolating
tokens:

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.surfaceElevated,
  });

  final Color success;
  final Color warning;
  final Color surfaceElevated;

  @override
  AppColors copyWith({Color? success, Color? warning, Color? surfaceElevated}) =>
      AppColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      );

  // Without lerp, a theme animation snaps instead of transitioning.
  @override
  AppColors lerp(AppColors? other, double t) => other == null
      ? this
      : AppColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
        );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
```

```dart
Container(color: context.colors.success)     // themed, brandable, dark-mode aware
Container(color: const Color(0xFF4CAF50))    // a rebrand now needs a grep
```

**Name tokens semantically, not visually.** `success`, `surfaceElevated`, `textMuted` — not
`green500` or `grey200`. Semantic names survive a redesign; visual ones produce
`green500` that is actually blue.

Spacing and radii deserve the same treatment: a `Spacing` extension with `xs`/`sm`/`md`/`lg`
means a density change is one edit, and it stops the drift between 12, 14 and 16 pixels of
padding that no reviewer catches.

## Components as a package

```text
packages/core_ui/
  lib/
    core_ui.dart              # the public API — nothing else is exported
    src/
      theme/                  # tokens, light and dark themes
      components/             # buttons, inputs, cards, dialogs
      foundations/            # spacing, typography, motion
```

Rules that keep it usable:

- **No business logic and no domain imports.** A component that knows what an `Order` is
  cannot be reused, and it drags the domain into the design system's dependencies.
- **Components take data and callbacks**, never repositories or providers.
- **Every component covers its states**: default, pressed, disabled, loading, error, focused.
  The missing loading state is why every team reimplements the button.
- **Golden tests per component, per state**, which is the only automated way to catch a visual
  regression — see [golden tests](../part-02-professional/testing-golden.md).

A widgetbook (`widgetbook` or `storybook_flutter`) gives designers and engineers one place to
see every component in every state. It is also the fastest way to review a design system
change without running the app.

## White labelling

The same codebase, several brands. The design system is what makes it tractable:

```dart
class Brand {
  const Brand({
    required this.id,
    required this.theme,
    required this.darkTheme,
    required this.logo,
    required this.features,
  });

  final String id;
  final ThemeData theme;
  final ThemeData darkTheme;
  final AssetImage logo;
  final Set<Feature> features;   // per-brand feature availability
}
```

Three levels of variation, and the cost rises steeply with each:

1. **Theme only** — colours, fonts, logo, app name. Cheap: one build per brand, one code path.
2. **Theme plus feature availability** — some brands lack loyalty, or use a different payment
   provider. Manageable behind flags and interfaces.
3. **Structural differences** — different navigation, different screens per brand. Expensive,
   and it is where white-label projects go wrong: the code fills with `if (brand == 'x')` and
   every change requires testing every brand.

Keep brands at level 1 or 2 by policy. When a brand needs a genuinely different screen, inject
it as a widget the app composes, rather than branching inside a shared screen. Each brand is
its own flavour with its own application id, signing and store listing — see
[flavors](../part-04-production/ci-flavors.md).

Test cost is what surprises teams: eight brands mean eight builds, eight sets of goldens and
eight store submissions. Automate the pipeline before the third brand, not after the sixth.

## Versioning a design system

The design system is a dependency for every feature team, so its releases are coordination
events:

- **Semantic versioning, strictly.** Renaming a token or changing a component's required
  parameters is a major bump.
- **Deprecate before removing.** `@Deprecated('Use PrimaryButton. Removed in 3.0')` and one
  release of overlap, so consuming teams migrate on their own schedule.
- **A changelog written for consumers**, describing what they must change, not what you
  refactored.
- **Visual changes are breaking in practice**, even when the API is unchanged. A restyled
  button changes eight teams' screens — announce it, and land it deliberately.

## Keeping design and code in sync

The recurring failure: design updates Figma, engineering does not notice, and the app drifts
brand by brand.

- **One source of truth for tokens.** Export from the design tool to JSON, generate the Dart
  from that. Style Dictionary and the Figma variables API both support this, and generation is
  what stops manual transcription errors.
- **Designers review the widgetbook**, not screenshots of screens. It is the same artefact
  engineers build against.
- **A shared vocabulary.** If design says "surface elevated" and code says `cardBackground`,
  every conversation costs a translation.
- **Goldens as the contract.** A visual change fails CI and gets reviewed as a visual change.

## Interview angles

**"How do you keep a consistent UI across many teams?"** Semantic tokens in `ThemeExtension`, a
component package with no business logic, golden tests per component state, and a rule that
features never hardcode colours or spacing. Then the human half: one vocabulary shared with
design, and a widgetbook both sides review.

**"How would you build a white-label app?"** Brand as configuration — theme, assets, feature
set — one flavour per brand, and a hard policy against structural branching. The cost is
multiplied testing and store submissions, which is what needs automating first.

**"How do you version a design system?"** Semver strictly, deprecate before removing, and
treat a visual change as breaking even when the API is not — because it changes every
consumer's screens.

**"How do you catch visual regressions?"** Golden tests per component per state, generated in
the CI environment, with failure diffs uploaded as artefacts.

## See also

- [Golden tests](../part-02-professional/testing-golden.md) — the automated visual contract
- [Modularization](modularization.md) — the design system as the first package to extract
- [Flavors](../part-04-production/ci-flavors.md) — one build per brand
- [Team workflow](team-workflow.md) — coordinating a shared dependency
