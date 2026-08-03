# GitHub Actions

Analyze, test and build on every pull request — and keep it under ten minutes, because a
slow pipeline is a pipeline people route around.

## The recommendation

**One fast required check on every PR, everything else on a schedule.** Format, analyze and
unit tests should finish in under five minutes and block merge. Builds, integration tests and
golden generation belong on merge to the main branch or nightly, where their slowness costs
nobody's attention.

## The pull request workflow

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

concurrency:
  # A new push cancels the previous run for the same branch — no queue of runs
  # for commits nobody is waiting on.
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'   # pin: 'stable' means CI changes under you
          cache: true                 # caches the SDK between runs

      - name: Install dependencies
        run: flutter pub get

      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Test
        run: flutter test --coverage --reporter=expanded

      - uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
```

Four decisions in that file worth copying:

- **Pin the Flutter version.** `stable` upgrades under you and produces a failure unrelated to
  the PR that caused it. Bump deliberately, in its own PR.
- **`concurrency` with `cancel-in-progress`.** Halves runner minutes on an active repository
  and removes the queue that makes results arrive after the author has moved on.
- **`--fatal-infos`.** Info-level analyzer output is either worth fixing or worth disabling in
  `analysis_options.yaml`. Warnings nobody has to fix accumulate until nobody reads any of
  them.
- **`--reporter=expanded`**, so a failure in the log names the test rather than showing a
  progress line.

## Caching

Cold Flutter setup and `pub get` dominate a short pipeline. Both cache well:

```yaml
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0', cache: true }

      - uses: actions/cache@v4
        with:
          path: ~/.pub-cache
          key: pub-${{ runner.os }}-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: pub-${{ runner.os }}-

      # Gradle, for Android builds — the largest single win there.
      - uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
```

The cache key must be the lockfile hash, with a looser `restore-keys` prefix so a changed
dependency still restores most of the cache instead of starting from nothing.

## Build jobs

Builds belong on merge, not on every PR, unless a build break is common in your codebase:

```yaml
  build-android:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: 'zulu', java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.0', cache: true }

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks

      - name: Build app bundle
        run: |
          flutter build appbundle --release \
            --obfuscate --split-debug-info=build/symbols \
            --dart-define=ENV=production

      - uses: actions/upload-artifact@v4
        with:
          name: symbols-${{ github.sha }}      # never lose these
          path: build/symbols
          retention-days: 90
```

**Archive the symbol files with the build.** Without them, every crash from that build is
unreadable, and they cannot be regenerated — see
[obfuscation and hardening](security-hardening.md).

iOS builds need `macos-latest`, which bills at roughly ten times the Linux rate on GitHub's
hosted runners. Run them on merge and on release tags, not per PR.

## Matrix builds

Useful for a package that must work across SDK versions; wasteful for an app:

```yaml
    strategy:
      fail-fast: false          # one failure should not hide the others
      matrix:
        flutter: ['3.19.0', '3.24.0', 'beta']
```

For an app, one pinned version plus a scheduled beta run gives you the same early warning
without multiplying every PR.

## Secrets

- **Never in the repository**, including in a workflow file. Use repository or environment
  secrets.
- **Base64-encode binaries** — keystores, provisioning profiles, service account JSON — to
  store them as secrets, and decode at build time as above.
- **Environment protection rules** for anything that publishes: require an approval before the
  production environment's secrets are available.
- **Secrets are not available to workflows triggered by `pull_request` from a fork**, which is
  a feature. Design the PR job so it does not need them.

## Keeping it under ten minutes

In rough order of effect:

1. **Split fast checks from slow builds**, and make only the fast ones required.
2. **Cache the SDK, pub and Gradle.**
3. **`cancel-in-progress`**, so runners work on current commits.
4. **Run jobs in parallel**, not as steps in one job.
5. **Shard the test suite** if it is genuinely large: `flutter test --total-shards=4
   --shard-index=${{ matrix.shard }}`.
6. **Move integration and golden jobs to nightly.**

A ten-minute pipeline gets read. A forty-minute one gets merged around, and then it stops
being a gate at all.

## Deploying documentation

This repository's own workflow is a small worked example: code checks gate the site build, and
`main` deploys to GitHub Pages.

```yaml
  deploy-docs:
    needs: analyze-and-test        # never publish a site from a red build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions: { pages: write, id-token: write }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: 'pip' }
      - run: pip install -r requirements.txt
      - run: mkdocs build --strict
      - uses: actions/upload-pages-artifact@v3
        with: { path: site }
      - uses: actions/deploy-pages@v4
```

`--strict` turns a broken link into a failed build, which is the only reliable way to keep
cross-references honest in a document this size.

## Interview angles

**"How do you set up CI for a Flutter app?"** Format, analyze and test on every PR with a
pinned SDK and caching; builds on merge; integration and golden tests nightly. Then the
constraint that drives the design: under ten minutes, or people route around it.

**"How do you keep CI fast?"** Cache the SDK, pub and Gradle; cancel superseded runs; run
jobs in parallel; shard tests; move slow jobs off the PR path.

**"How do you handle signing secrets in CI?"** Base64-encoded repository or environment
secrets, decoded at build time, with environment protection on anything that publishes — and
never available to fork PRs.

**"What do you archive from a release build?"** The artefact and the debug symbols, keyed by
version. Symbols cannot be regenerated, and without them crash reports from that build are
unreadable.

## See also

- [Flavors](ci-flavors.md) — building the right variant
- [Release process](release-process.md) — what happens after a green build
- [Tooling](../part-02-professional/tooling.md) — the same commands, locally
- [Integration tests](../part-02-professional/testing-integration.md) — the nightly job
