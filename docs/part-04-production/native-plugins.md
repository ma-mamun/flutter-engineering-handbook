# Writing plugins

Federated structure, publishing, and the versioning discipline that makes a plugin usable by
someone else.

## The recommendation

**Write a package unless you need platform code; write a plugin when you do; make it federated
only when more than one team or repository will own the platform implementations.** The
federated structure exists to let different people ship different platforms independently. If
that is not your situation, it is four packages of overhead for no benefit.

## Package or plugin

- **Package** — pure Dart. A utility, a state management helper, a design system, an API
  client. No platform folders.
- **Plugin** — a package that also contains platform code and registers itself with the engine.

```bash
flutter create --template=plugin --platforms=android,ios -a kotlin -i swift my_plugin
```

## The federated structure

```text
my_plugin/                       # the app-facing package: API, docs, default constructor
my_plugin_platform_interface/    # the contract every implementation satisfies
my_plugin_android/               # Android implementation
my_plugin_ios/                   # iOS implementation
my_plugin_web/                   # web implementation
```

The platform interface is the contract:

```dart
abstract class MyPluginPlatform extends PlatformInterface {
  MyPluginPlatform() : super(token: _token);
  static final Object _token = Object();

  static MyPluginPlatform _instance = MethodChannelMyPlugin();
  static MyPluginPlatform get instance => _instance;

  static set instance(MyPluginPlatform instance) {
    // Verifies the implementation extends this class rather than implementing
    // it — an `implements` subclass silently breaks when a method is added.
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() =>
      throw UnimplementedError('getPlatformVersion() is not implemented');
}
```

Two rules that make this work over time:

- **Implementations `extend`, never `implements`.** Adding a method to an `extends` subclass
  inherits the throwing default; an `implements` subclass fails to compile for every user.
  That is the entire reason for the token check.
- **New methods get a default implementation that throws** `UnimplementedError`, so adding one
  is a minor version bump rather than a breaking change.

Registration is declared in the pubspec, so a user adding the package gets the platform
implementation automatically:

```yaml
flutter:
  plugin:
    platforms:
      android:
        package: com.example.my_plugin
        pluginClass: MyPlugin
      ios:
        pluginClass: MyPlugin
```

## Designing the Dart API

The plugin's public API is the part you cannot change later. Five decisions worth making
deliberately:

- **Dart types, not platform types.** Return a `Position`, not a map with `lat` and `lng`
  keys.
- **Typed errors.** Map `PlatformException` to your own exception classes so callers do not
  switch on string codes.
- **Explicit unsupported behaviour.** `UnsupportedError` on a platform that cannot do it, not
  a silent no-op that leaves the caller guessing.
- **Streams for continuous data, futures for one-shot.** Match the shape to the data, as in
  [platform channels](native-platform-channels.md).
- **A testing surface.** Expose the platform interface so users can substitute a fake. A
  plugin that cannot be faked forces every consumer into an integration test.

## Testing a plugin

Three levels, and all three are needed:

```dart
// 1. Dart, against a fake platform implementation.
class FakeMyPluginPlatform extends MyPluginPlatform {
  @override
  Future<String?> getPlatformVersion() async => '42';
}

test('returns the platform version', () async {
  MyPluginPlatform.instance = FakeMyPluginPlatform();
  expect(await MyPlugin().getPlatformVersion(), '42');
});
```

2. **Native unit tests** — JUnit for Kotlin, XCTest for Swift — for the platform logic.
3. **An integration test in the example app**, on a real device, for the parts that only exist
   when the two sides are connected.

The example app is not optional. It is how users evaluate the plugin, how you test on device,
and where a regression shows up first.

## Publishing

```bash
dart pub publish --dry-run     # check for issues without publishing
dart pub publish
```

The pub.dev score is what most users see first, and it is mechanical:

- **Documentation on every public API.** A `///` comment on each exported member.
- **An example** in `example/`.
- **A complete `pubspec.yaml`**: description between 60 and 180 characters, homepage,
  repository, issue tracker.
- **`dart format` clean, `dart analyze` clean**, no dependency constraints that are already
  outdated.
- **A CHANGELOG entry per version**, in the format pub.dev parses.

## Versioning

Semantic versioning, applied strictly, because other people's builds depend on it:

- **Patch** (1.0.**1**) — a fix with no API change.
- **Minor** (1.**1**.0) — a new method with a default implementation, a new optional
  parameter.
- **Major** (**2**.0.0) — a removed or changed signature, a required parameter, a raised
  minimum SDK.

Three things people underestimate as breaking: **raising the minimum Dart or Flutter SDK**,
**changing a default value**, and **making an error type more specific**. All three break
someone's build or behaviour, and all three deserve a major bump.

For a federated plugin, the app-facing package constrains the platform interface with a
caret range, and the interface's own major bump is a coordinated release across all packages.
That coordination cost is the strongest argument for not federating until you need to.

## Maintaining one

- **Support the platforms you claim.** A plugin listing web support that throws on web is
  worse than one that never claimed it.
- **Answer issues or say you are not.** An archived plugin with a clear note is more useful
  than one that looks alive.
- **Test against Flutter beta** in CI, so a breaking framework change is your problem before
  it is your users'.
- **Keep the example app current.** It is the first thing anyone reads.

## Interview angles

**"When would you write a plugin instead of a package?"** When it needs platform code. A
package is pure Dart; a plugin registers platform implementations with the engine.

**"What is the federated plugin structure and why?"** An app-facing package, a platform
interface, and per-platform implementations, so different owners can ship platforms
independently. The cost is coordinated releases, which is why it is not the default.

**"Why do implementations extend rather than implement the platform interface?"** So a new
method inherits a throwing default instead of breaking every implementation's compilation.
That is what the `PlatformInterface` token check enforces.

**"How do you version a plugin?"** Semantic versioning strictly, and count SDK minimums,
changed defaults and narrowed error types as breaking — because they break somebody's build.

## See also

- [Platform channels](native-platform-channels.md) — the mechanism a plugin wraps
- [Dart FFI](native-ffi.md) — plugins that ship native libraries
- [Modularization](../part-05-enterprise/modularization.md) — internal packages, same rules
- [Unit tests](../part-02-professional/testing-unit.md) — faking the platform interface
