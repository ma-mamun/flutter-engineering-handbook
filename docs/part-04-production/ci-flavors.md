# Flavors

Dev, staging and production from one codebase — installable side by side, and impossible to
confuse.

## The recommendation

**Three flavors, different application ids, different app names and different icons.** The
application id is what makes them installable side by side; the name and icon are what stop
someone demoing staging to a customer. Configuration comes from `--dart-define`, never from a
file that could be committed with production values in it.

## Android

```gradle
// android/app/build.gradle
android {
    flavorDimensions "env"
    productFlavors {
        dev {
            dimension "env"
            applicationIdSuffix ".dev"        // com.example.app.dev
            resValue "string", "app_name", "MyApp Dev"
        }
        staging {
            dimension "env"
            applicationIdSuffix ".staging"
            resValue "string", "app_name", "MyApp Staging"
        }
        prod {
            dimension "env"
            resValue "string", "app_name", "MyApp"
        }
    }
}
```

`AndroidManifest.xml` then uses `android:label="@string/app_name"`.

Per-flavor resources live in `android/app/src/<flavor>/`, which is where a flavor-specific
`google-services.json` and launcher icon go:

```text
android/app/src/dev/google-services.json
android/app/src/staging/google-services.json
android/app/src/prod/google-services.json
```

```bash
flutter run --flavor dev
flutter build appbundle --flavor prod --release
```

## iOS

iOS calls them schemes and build configurations, and it needs Xcode rather than a text file:

1. **Duplicate the build configurations**: Debug-dev, Release-dev, Profile-dev, and the same
   for staging and prod. All nine, or `flutter run --profile --flavor dev` fails with an
   unhelpful message.
2. **Create a scheme per flavor**, each pointing at its configurations, and mark them
   **shared** — an unshared scheme is not in version control and works only on the machine
   that made it.
3. **Set the bundle identifier per configuration**:
   `PRODUCT_BUNDLE_IDENTIFIER = com.example.app$(BUNDLE_ID_SUFFIX)`.
4. **Add a per-flavor `GoogleService-Info.plist`** with a run script that copies the right one
   into place at build time.

The flavor name must match the scheme name exactly — `--flavor dev` requires a scheme called
`dev`. This is the single most common iOS flavor failure, and the error message does not say
so.

## Configuration with --dart-define

```bash
flutter run --flavor dev \
  --dart-define=ENV=dev \
  --dart-define=API_URL=https://api.dev.example.com
```

```dart
class AppConfig {
  // Compile-time constants: tree-shaken, so a branch for another environment is
  // removed from the binary rather than shipped and unused.
  static const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const apiUrl = String.fromEnvironment('API_URL');

  static bool get isProd => env == 'prod';
}
```

For more than a few values, use a file instead of a long command line:

```json
// config/dev.json
{ "ENV": "dev", "API_URL": "https://api.dev.example.com" }
```

```bash
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

!!! warning "`--dart-define` is not a secret store"
    The values are compiled into the binary and readable with `strings`. They are for
    *configuration* — endpoints, flags, environment names — not for API keys or credentials.
    See [network security](security-network.md).

## Entry points, and why one is better

The older approach uses `main_dev.dart`, `main_staging.dart`, `main_prod.dart` with
`--target`. It works, and it drifts: three files that must stay in sync, and the one nobody
runs is the one that breaks.

Prefer **one `main.dart`** that reads its configuration:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  await bootstrap(config);
  runApp(App(config: config));
}
```

One code path, three configurations. If a flavor needs genuinely different wiring — a
different DI graph, a mock backend — pass it as an override rather than as a separate `main`.

## Making the environment visible

The failure this prevents is real: someone demos staging data to a customer, or files a bug
against the wrong environment.

- **A banner in non-production builds.** `Banner` or a coloured `AppBar`, with the environment
  name.
- **Different icons.** Tint the dev and staging launcher icons; `flutter_launcher_icons`
  supports per-flavor configuration.
- **The environment in the about screen**, alongside version and build number, so a bug report
  screenshot carries it.

```dart
if (!AppConfig.isProd)
  Banner(message: AppConfig.env, location: BannerLocation.topEnd, child: app)
```

## Per-flavor services

- **Firebase:** a project per environment, with the config file placed per flavor as above.
  Sharing one project across environments mixes test crashes and analytics into production
  data, and it cannot be separated afterwards.
- **Crash reporting:** separate projects or at minimum a tagged environment, so a staging
  crash storm does not page anyone.
- **Deep links:** each flavor needs its own domain or scheme, and its own `assetlinks.json` /
  `apple-app-site-association` entry — one per application id. See
  [navigation](../part-02-professional/navigation.md).
- **Push notifications:** separate sender keys per environment, or a staging test notifies
  production users.

## In CI

```yaml
      - run: |
          flutter build appbundle \
            --flavor prod --release \
            --dart-define-from-file=config/prod.json \
            --obfuscate --split-debug-info=build/symbols
```

Build dev on every merge for the internal channel and prod on a release tag. Keep the
per-flavor configuration files in the repository, and only the signing material and any true
secret in CI secrets.

## Interview angles

**"How do you manage multiple environments?"** Flavors on Android, schemes on iOS, different
application ids so they install side by side, configuration through `--dart-define`, and a
visible banner and icon so nobody confuses them.

**"Why not a config file read at runtime?"** It has to ship in the bundle and can be read or
swapped, and it defeats tree shaking. `--dart-define` values are compile-time constants, so
the other environments' branches are removed.

**"Are `--dart-define` values secret?"** No — they are compiled into the binary and readable
with `strings`. Configuration only.

**"What breaks most often with iOS flavors?"** A scheme name not matching the flavor, missing
per-flavor build configurations for profile mode, and unshared schemes that work on one
machine.

## See also

- [GitHub Actions](ci-github-actions.md) — building each flavor
- [Release process](release-process.md) — which flavor goes to which channel
- [Network security](security-network.md) — why configuration is not secrets
- [Observability](../part-05-enterprise/observability.md) — separating environments in reporting
