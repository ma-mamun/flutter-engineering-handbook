# Release process

Versioning, signing, staged rollout, and being able to roll back — so a release day is
uneventful.

## The recommendation

**Automate the whole path from tag to store, and never ship to 100% on day one.** A staged
rollout with crash-rate monitoring turns a bad build into a few hundred affected users instead
of all of them. On mobile you cannot recall a release, so the rollout percentage *is* your
rollback.

## Versioning

```yaml
# pubspec.yaml
version: 1.4.2+128
#        ^^^^^ ^^^
#        name  build number
```

- **The version name** is semantic and user-visible: breaking redesign, feature, fix.
- **The build number** must increase with every upload, forever, on both stores. A rejected or
  replaced build burns its number permanently.

Derive the build number rather than editing it by hand — CI run number, or commit count:

```bash
BUILD_NUMBER=$(git rev-list --count HEAD)
flutter build appbundle --build-name=1.4.2 --build-number=$BUILD_NUMBER
```

**Tag the release commit** and keep the tag, the build number and the uploaded artefact
associated. When a crash arrives from 1.4.2+128, you need to know exactly which commit that
was.

## Signing

**Android:**

```properties
# android/key.properties — never committed
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/upload-keystore.jks
```

```gradle
signingConfigs {
    release {
        def props = new Properties()
        file('../key.properties').withInputStream { props.load(it) }
        storeFile file(props['storeFile'])
        storePassword props['storePassword']
        keyAlias props['keyAlias']
        keyPassword props['keyPassword']
    }
}
```

**Use Play App Signing.** Google holds the app signing key; you hold an upload key that can be
reset if lost. Without it, a lost keystore means you can never update that listing again — the
app is stranded and users must install a new one. This has ended products.

**iOS:** certificates and provisioning profiles, ideally managed by `fastlane match`, which
keeps them encrypted in a private repository so every machine and CI runner uses the same
ones rather than each developer generating their own.

Back up the keystore and the `key.properties` values in a password manager or secret store,
in more than one place, and check that someone other than one person can reach them.

## Automating with Fastlane

```ruby
# android/fastlane/Fastfile
platform :android do
  desc "Deploy to Play internal testing"
  lane :internal do
    sh("flutter build appbundle --release --flavor prod " \
       "--obfuscate --split-debug-info=../build/symbols")
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/prodRelease/app-prod-release.aab',
      mapping_paths: ['../build/app/outputs/mapping/prodRelease/mapping.txt'],
    )
  end

  desc "Promote internal to production at 10%"
  lane :rollout do
    upload_to_play_store(
      track: 'production',
      rollout: '0.1',
      skip_upload_aab: true,
      version_code: ENV['VERSION_CODE'],
    )
  end
end
```

The same shape on iOS with `upload_to_testflight` and `deliver`. What automation actually buys
you is **repeatability** — the release is the same every time, it does not depend on who is
doing it, and the steps live in a file rather than in someone's memory.

## The staged rollout

The mechanism that makes mobile releases survivable:

| Stage | Audience | Watch for | Typical duration |
| --- | --- | --- | --- |
| Internal | The team | Does it launch and sign in | Hours |
| Closed beta | 50–500 opted-in users | Crashes, obvious breakage | 1–3 days |
| Production 1–5% | Real users | Crash-free rate, ANRs, key funnels | 24 hours |
| Production 20% | More real users | Same, plus reviews | 24 hours |
| Production 50→100% | Everyone | Same | 2–3 days |

**Halt criteria decided before the release**, not during: a crash-free session rate below your
baseline minus a threshold, a spike in a key funnel's failure rate, ANRs over target. Written
down, and anyone on the team can call it. During an incident is the worst possible time to
debate whether the number is bad.

Play supports halting and resuming a staged rollout. App Store Connect supports phased release
over seven days and pausing it. Both let you stop the bleeding — which is why day-one 100% is
a choice, not a default.

## Rollback, honestly

**You cannot recall an installed version.** Users who updated have the new binary. What you
actually have:

1. **Halt the rollout.** Stops new users receiving it. First action, always.
2. **Ship a fixed build with a higher version.** The real fix, and it costs review time — up
   to 24 hours on iOS, less if expedited.
3. **Server-side kill switches.** The only *instant* remedy. A feature flag that disables the
   broken feature, or a config value the app respects, turns a hotfix into a toggle.
4. **Force-update gate.** For a genuinely dangerous build — data loss, security — an endpoint
   that tells old versions to stop and prompt for an update.

The design conclusion, and it belongs in the architecture rather than the release process:
**anything risky ships behind a flag.** See
[observability](../part-05-enterprise/observability.md).

## The release checklist

Automate what can be automated, and keep the rest short enough to actually run:

- [ ] Version and build number bumped; release commit tagged.
- [ ] CHANGELOG updated with user-visible changes.
- [ ] Full test suite green, including integration tests.
- [ ] Release build smoke-tested on a real device — R8 and obfuscation only break there.
- [ ] Symbol files archived and uploaded to the crash reporter.
- [ ] Store metadata and screenshots current for the new UI.
- [ ] Privacy declarations updated if data collection changed.
- [ ] Minimum OS versions and permission list reviewed.
- [ ] Feature flags for new work set to their launch state.
- [ ] Rollback plan named: which flag, who can call it, what the halt criteria are.
- [ ] Someone is on call for the next 24 hours and knows they are.

## After the release

The part that is usually skipped, and where the value is:

- **Watch crash-free rate for 24 hours** before advancing the rollout.
- **Compare adoption to the previous release.** A slow uptake can itself be a signal — an
  update failing on a particular OS version.
- **Read the reviews from the release window.** Users describe bugs your telemetry does not
  categorise.
- **Note anything that surprised you** and fix it in the process, not just in the code. That
  is what stops release day from being tense.

## Interview angles

**"Walk me through your release process."** Tag, CI builds the signed artefact with obfuscation
and archives symbols, Fastlane uploads to internal, staged rollout with monitoring at each
step and pre-agreed halt criteria, feature flags for anything risky. The staged rollout is the
part that matters.

**"How do you roll back a mobile release?"** You do not, really — halt the rollout, ship a
higher version, and use server-side kill switches for anything that needs to be instant. That
answer separates people who have shipped from people who have read about shipping.

**"Debug versus release build?"** JIT with assertions and the debug service versus AOT with
tree shaking, obfuscation and R8. Then the consequence: some bugs — reflection removed by R8,
missing keep rules — exist only in release, which is why a release build must be smoke-tested
before upload.

**"What do you monitor after a release?"** Crash-free sessions and ANRs against the previous
version's baseline, the key funnels, adoption rate, and reviews. With halt criteria agreed
beforehand.

## See also

- [GitHub Actions](ci-github-actions.md) — the pipeline that produces the artefact
- [Flavors](ci-flavors.md) — which build goes to which channel
- [Obfuscation and hardening](security-hardening.md) — symbols to archive
- [Observability](../part-05-enterprise/observability.md) — flags and the metrics you halt on
