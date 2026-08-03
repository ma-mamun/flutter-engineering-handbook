# Project structure

A folder layout that survives from one developer to twenty, and the reasoning behind each
boundary.

## The recommendation

**Feature-first.** Group by what the code is about, not by what kind of code it is. Inside
each feature, layer. Put anything two features need in `core/`, and split into packages only
when the build or the team makes you.

```text
lib/
  main.dart
  app/                        # composition root: DI, router, theme, bootstrap
    app.dart
    router.dart
    di.dart
  core/                       # shared by two or more features
    network/                  # dio client, interceptors
    storage/                  # database, secure storage
    error/                    # Result, failure types
    ui/                       # design system: buttons, spacing, theme extensions
    extensions/
  features/
    auth/
      domain/                 # entities, repository interfaces, use cases
      data/                   # DTOs, mappers, api clients, repository impls
      presentation/           # widgets, notifiers/blocs
    orders/
      domain/
      data/
      presentation/
  l10n/
test/
  features/                   # mirrors lib/ exactly
  core/
```

## Why feature-first beats layer-first

Layer-first (`lib/models`, `lib/services`, `lib/screens`) looks tidy on day one and gets
worse every week:

- **A change touches every folder.** "Add a field to Order" edits four directories, so the
  diff is unreadable and merge conflicts are guaranteed.
- **Nothing is deletable.** Removing a feature means hunting its pieces through five folders
  and hoping nothing else referenced them.
- **Coupling is invisible.** Everything is one import away, so everything eventually imports
  everything.
- **It does not scale down.** `lib/screens` with sixty files is not navigable.

Feature-first inverts all four. One feature is one folder: a change lives in one diff, a
deletion is `rm -rf`, and coupling between features is visible as an import across a folder
boundary — which is exactly what you want a reviewer to notice.

**The cost:** deciding what counts as a feature, and re-deciding when the product changes.
That argument is real, and it is cheaper than the layer-first alternative. Draw the boundary
around a **user-facing capability**, not a screen and not a data type: `checkout`, not
`CartScreen`, and not `Cart`.

## The rules that keep it working

**Features never import each other.** The one rule with teeth. Anything shared moves into
`core/`. When a feature genuinely needs another's behaviour, invert it behind an interface
declared where it is used, or publish an event — see
[Clean Architecture](clean-architecture.md#avoiding-circular-dependencies).

**`core/` is for things used by two or more features.** Used by one? It belongs to that
feature. `core/` becomes a junk drawer exactly when this is not enforced, and a junk drawer
is layer-first with extra steps.

**`app/` is the only place that knows everything.** The composition root wires
implementations to interfaces, builds the router, and starts the app. Being the one file
allowed to import from everywhere is what keeps everything else clean.

**Tests mirror `lib/`.** `test/features/auth/domain/login_test.dart` sits opposite
`lib/features/auth/domain/login.dart`. No thinking required to find a test, and gaps are
visible as missing files.

## Inside a feature

For a feature with real logic, the three layers:

```text
features/orders/
  domain/
    order.dart                 # entity
    order_repository.dart      # interface
    place_order.dart           # use case, if it has a rule of its own
  data/
    order_dto.dart
    order_api.dart
    order_repository_impl.dart
  presentation/
    orders_page.dart
    order_notifier.dart
    widgets/
      order_tile.dart
```

For a feature that is genuinely a screen over an endpoint, do not build all three. A
`presentation/` folder and a repository is enough, and adding the rest later is a move, not
a rewrite. **Match the structure to the complexity that exists**, not the complexity you
imagine.

## When to split into packages

Folders are conventions a reviewer must notice; packages are boundaries the compiler
enforces. Split when at least one of these is true, and not before:

| Signal | What a package buys you |
| --- | --- |
| The dependency rule keeps getting broken | The illegal import stops compiling |
| Two apps share code (white label, staff app) | One source of truth, versioned |
| Build times are painful | Melos and per-package test runs |
| A team owns a domain end-to-end | CODEOWNERS on a real boundary |
| A module could be open sourced | Clean seams and a public API |

A typical enterprise split:

```text
packages/
  design_system/     # theme, components — no business logic
  core_network/      # dio setup, interceptors, error mapping
  core_storage/      # database, secure storage
  feature_auth/      # one feature, all layers
  feature_orders/
apps/
  customer_app/      # composes packages, owns flavours and entry point
  staff_app/
```

**The cost is real:** version bumps across packages, slower cold builds, `melos bootstrap`
in every onboarding doc, and cross-package refactors that touch several `pubspec.yaml`
files. Do not pay it for a single app with four developers. Details in
[modularization](../part-05-enterprise/modularization.md).

## Naming and file conventions

- **`snake_case.dart`**, one primary class per file, filename matching the class.
- **Suffix by role**: `_page.dart`, `_notifier.dart`, `_repository.dart`, `_dto.dart`. It
  makes the fuzzy-file-open in an IDE do the navigation for you.
- **Barrel files sparingly.** `orders.dart` re-exporting a feature's public API is useful at
  a package boundary and a circular-import trap inside one. Never export a feature's
  internals through a barrel.
- **`part`/`part of` only for generated code** — `freezed`, `json_serializable`, `drift`.
  Hand-written `part` files hide dependencies from the import graph.

## Assets and localisation

```text
assets/
  images/
    2.0x/
    3.0x/
  fonts/
lib/l10n/
  app_en.arb
  app_bn.arb
```

Declare assets with directory paths in `pubspec.yaml` rather than listing files, and
generate typed references (`flutter_gen`) so a renamed image is a compile error rather than
a blank box in production.

## Interview angles

**"How do you structure a Flutter project?"** Feature-first with layers inside each feature,
`core/` for genuinely shared code, `app/` as the composition root, tests mirroring `lib/`.
Then the rule that matters: features never import each other.

**"Feature-first or layer-first?"** Feature-first, and give the reason rather than the
preference: a change should be one diff in one folder, a deletion should be one command, and
coupling should be visible at a folder boundary.

**"When do you split into packages?"** When a boundary needs enforcing by the compiler, when
two apps share code, when build times hurt, or when a team owns a domain. Name the cost —
versioning and slower cold builds — or the answer sounds like cargo cult.

## See also

- [Clean Architecture](clean-architecture.md) — what goes in each layer
- [Dependency injection](dependency-injection.md) — what the composition root does
- [Tooling](tooling.md) — analyzer, formatter, and code generation
- [Modularization](../part-05-enterprise/modularization.md) — packages, Melos, ownership
