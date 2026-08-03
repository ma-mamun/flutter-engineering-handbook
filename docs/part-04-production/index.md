# Part 4 — Production

Everything between "it works on my machine" and "it works on a stranger's phone".

Three concerns share this part because they share a property: none of them can be evaluated
from your development machine. Security is about a device you do not control, performance is
about hardware slower than yours, and release is about a pipeline that must work when you are
asleep.

## Security

The binary runs on the attacker's device. Every page here states what a measure does **not**
prevent, because that is the part usually left out.

- **[Secure storage](security-storage.md)** — Keychain and Keystore, token lifetimes and
  rotation, biometric gating, and what encryption at rest does not cover.
- **[Network security](security-network.md)** — TLS enforcement, certificate pinning with its
  full operational cost, and why secrets cannot live in a client.
- **[Obfuscation and hardening](security-hardening.md)** — symbol management, R8, root
  detection's limits, attestation, and a ranked list of where effort actually belongs.

## Performance

Measure, then fix. Most of the work is measuring.

- **[Profiling](performance-profiling.md)** — the reproduce/measure/change-one-thing loop, and
  the UI-versus-raster split that decides everything after it.
- **[Rendering](performance-rendering.md)** — rebuild scope first, `RepaintBoundary` with its
  cost, list performance, expensive effects, shader jank.
- **[Memory](performance-memory.md)** — the retaining chain, leak sources, the snapshot diff,
  and the image cache.
- **[Build size](performance-build-size.md)** — `--analyze-size`, app bundles, assets and
  fonts, deferred components.

## Native integration

- **[Platform channels](native-platform-channels.md)** — MethodChannel, EventChannel, Pigeon,
  and errors across the boundary.
- **[Dart FFI](native-ffi.md)** — when it beats a channel, `ffigen`, and the memory rules.
- **[Writing plugins](native-plugins.md)** — federated structure, publishing, versioning.

## Ship it

- **[GitHub Actions](ci-github-actions.md)** — a pipeline under ten minutes, and what belongs
  off the PR path.
- **[Flavors](ci-flavors.md)** — dev, staging and production side by side, impossible to
  confuse.
- **[Release process](release-process.md)** — versioning, signing, staged rollout, and the
  honest answer about rollback.

## The thread through this part

**You cannot roll back a mobile release.** Users who updated have the binary. Everything here
follows from that: measure before shipping because you cannot fix it after, stage the rollout
so a bad build reaches hundreds rather than everyone, keep symbol files because crash reports
are your only view into the field, and put anything risky behind a flag so there is something
to turn off.
