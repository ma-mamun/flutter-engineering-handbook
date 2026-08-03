# Obfuscation and hardening

Raising the cost of reverse engineering, without pretending it is prevention.

## The recommendation

**Ship `--obfuscate --split-debug-info`, keep the symbol files, and stop there unless you
have a specific threat that justifies more.** Obfuscation makes a binary tedious to read. It
does not make it unreadable, and no client-side measure can — the attacker controls the
device, the runtime and the debugger. Everything on this page raises cost; nothing on it
prevents.

## Obfuscation

```bash
flutter build appbundle \
  --obfuscate \
  --split-debug-info=build/symbols/$VERSION+$BUILD
```

What happens: Dart class, method and field names in the AOT snapshot are replaced with
meaningless symbols, and the mapping is written to the symbols directory.

- **Both flags or neither.** `--obfuscate` without `--split-debug-info` is rejected, because
  the result would be permanently un-symbolicatable crashes.
- **Archive the symbols per build**, keyed by version and build number, somewhere that
  outlives the CI run — a release artifact or object storage. Losing them means every crash
  report from that build is a wall of hex.
- **Symbolicate with the matching build's symbols:**

  ```bash
  flutter symbolize -i crash.txt -d build/symbols/1.4.0+128/app.android-arm64.symbols
  ```

- **Upload them to your crash reporter too** — Crashlytics and Sentry both take Dart symbol
  files, and without them your dashboards are useless. That upload belongs in the release
  pipeline, not in someone's memory. See
  [release process](release-process.md).

What obfuscation does *not* cover: your asset bundle, strings, API endpoints, native code,
and the structure of your network calls. A `strings` pass over the binary still finds every
URL, and a proxy still shows every request.

## Android: R8 and ProGuard

R8 (the default since Android Gradle Plugin 3.4) shrinks, obfuscates and optimises the
**Java/Kotlin** side. Your Dart code is unaffected by it, so on a Flutter app it mostly
affects plugins and any native code you wrote.

```gradle
buildTypes {
    release {
        minifyEnabled true          // R8: shrink and obfuscate
        shrinkResources true        // drop unreferenced resources
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                      'proguard-rules.pro'
    }
}
```

The failure mode is specific and worth recognising: **R8 removes classes only reached by
reflection**, and the crash appears in release only, often only on one plugin, with a
`ClassNotFoundException` or a `NoSuchMethodError`. Keep rules fix it:

```proguard
-keep class io.flutter.** { *; }
-keep class com.yourcompany.yourapp.models.** { *; }   # anything used via reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable              # readable native stack traces
```

Always smoke-test a release build on a device before shipping. A debug build proves nothing
about R8, and this is one of the two or three failure classes that only exist in release.

## Root and jailbreak detection

Libraries such as `flutter_jailbreak_detection` check for known artefacts — `su` binaries,
Cydia, writable system paths, test-keys builds.

**Value:** it filters out casual tampering and satisfies compliance requirements that ask for
it. For a banking or payments app, it is often a checkbox you are required to tick.

**Limits, which are severe:**

- The check runs on the device the attacker controls. Its return value can be patched, and
  Magisk Hide, Zygisk and similar exist specifically to defeat these checks.
- False positives are common — custom ROMs, developer devices, some OEM builds — so blocking
  outright locks out legitimate users, and they complain loudly.
- It gives no signal to your backend unless you send the result, and a client-reported "I am
  not rooted" is worth exactly nothing.

**A reasonable policy:** report the signal to the server as one input among many, degrade
rather than block (disable payments, require re-authentication), and never make it the only
control between an attacker and something valuable.

## Attestation: the control that actually works

Platform attestation moves the judgement off the device, which is the entire point.

- **Play Integrity API** (Android) returns a verdict signed by Google about the device, the
  app binary and the install source.
- **App Attest / DeviceCheck** (iOS) returns an assertion signed by Apple about the app
  instance.

The property that makes them different from client-side checks: **your server verifies the
signature.** A patched client cannot forge the verdict, because it cannot sign it.

Use them for high-value operations — first login, payment, account recovery — rather than on
every request; both have quotas, latency and failure modes. And plan for legitimate failures:
devices without Play Services, enterprise images, and outages. Failing closed on attestation
means an outage at Google takes your app down with it.

## Other measures, and what they are worth

| Measure | Actually stops | Costs |
| --- | --- | --- |
| `--obfuscate` | Casual reading of Dart symbols | Symbol management |
| R8/ProGuard | Casual reading of Java/Kotlin | Release-only crashes without keep rules |
| Root detection | Casual tampering, compliance | False positives, trivially bypassed |
| Attestation | Modified binaries, emulators — verified server-side | Quotas, availability, complexity |
| `FLAG_SECURE` | Screenshots, screen recording, app-switcher previews | Blocks legitimate screenshots |
| Anti-debugging | Casual dynamic analysis | Fragile, breaks on OS updates |
| Code integrity checks | Naive patching | Bypassed by patching the check |

The pattern across the table: **every client-side control is bypassable by someone who owns
the device.** They are speed bumps, and speed bumps have value — most attackers are not
determined. Just do not let a speed bump be the only thing between an attacker and money.

## Where the effort actually belongs

For a typical app, in descending order of value per hour spent:

1. **Server-side authorisation on every operation.** The client is a UI; the server decides.
2. **Short token lifetimes with revocation**, so a compromised device is survivable.
3. **Rate limiting and anomaly detection** on the backend, where the whole picture is.
4. **Not shipping secrets** — see [network security](security-network.md).
5. **Obfuscation and symbol management**, because it is nearly free.
6. **Attestation for high-value operations.**
7. Everything else on this page.

An app that gets 1–4 right and skips 5–7 is in far better shape than one with root detection,
pinning and anti-debugging on top of an API that trusts the client.

## Interview angles

**"How does obfuscation work in Flutter?"** `--obfuscate --split-debug-info` renames Dart
symbols in the AOT snapshot and writes a mapping file you archive per build and use to
symbolicate crashes. Then the limit: assets, strings, endpoints and network behaviour are all
still visible.

**"How does ProGuard/R8 work?"** It shrinks and obfuscates the Java/Kotlin side by tracing
reachable code from entry points, which is why anything reached only by reflection needs a
keep rule — and why the resulting crash appears in release builds only.

**"Is root detection worth it?"** As a signal reported to the server and as compliance, yes.
As a control, no — it runs on the attacker's device and is routinely bypassed. The control
that works is attestation, because the server verifies a signature the client cannot forge.

**"How do you protect a Flutter app from reverse engineering?"** You raise cost; you do not
prevent. Then redirect to where the real defence is: server-side authorisation, short-lived
revocable tokens, no secrets in the client, and attestation for high-value actions.

## See also

- [Secure storage](security-storage.md) — what encryption at rest does not cover
- [Network security](security-network.md) — pinning, and secrets off the client
- [Build size](performance-build-size.md) — the same build flags, from the size angle
- [Release process](release-process.md) — archiving and uploading symbol files
