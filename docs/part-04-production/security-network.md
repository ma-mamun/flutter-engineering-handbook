# Network security

TLS, certificate pinning and its rotation risk, and keeping secrets off a binary you have
already given to the attacker.

## The recommendation

**Enforce HTTPS everywhere, keep secrets on the server, and treat certificate pinning as an
optional extra with a real operational cost.** Pinning stops an attacker who can install a
trusted root on the device; it also bricks every installed copy of your app the day a
certificate rotates unexpectedly. Ship it only if you have the rotation plan written down
first.

## HTTPS, enforced by the platform

Both platforms block cleartext by default, and both have an escape hatch someone will
eventually add "temporarily".

**Android** — `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors>
      <certificates src="system" />
      <!-- No <certificates src="user" />: user-installed CAs are how an
           interception proxy reads your traffic on a non-rooted device. -->
    </trust-anchors>
  </base-config>
</network-security-config>
```

**iOS** — leave App Transport Security at its defaults. Any
`NSAllowsArbitraryLoads` in `Info.plist` needs a justification in review, and Apple will ask
for one.

Two rules that prevent the common mistake: **never disable certificate validation, even in
debug** (`badCertificateCallback => true` in a debug branch has shipped to production more
than once), and **use a debug-only flavour with its own config** if you need a proxy for
development, so the release build's configuration is never touched.

## Certificate pinning

Pinning means the app refuses connections whose certificate chain does not match a value you
compiled in.

```dart
final dio = Dio();
(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final context = SecurityContext(withTrustedRoots: true);
  final client = HttpClient(context: context);

  client.badCertificateCallback = (cert, host, port) => false;   // never accept
  return client;
};

// Pin on the public key hash, not the certificate: the key usually survives
// renewal, so routine rotation does not break the app.
dio.interceptors.add(
  CertificatePinningInterceptor(allowedSHAFingerprints: [primaryPin, backupPin]),
);
```

**What it buys:** protection against an attacker who can get a CA the device trusts to issue
a certificate for your domain — a corporate MDM root, a malicious profile, a compromised CA,
or an interception proxy the user was persuaded to install.

**What it costs**, and this is the part usually left out:

- **An unplanned certificate change bricks the installed app.** Not degrades — bricks. Every
  request fails until users update, and you cannot fix it server-side.
- **You need at least two pins**: the current key and a backup key held offline. Shipping one
  pin means one incident ends your app's connectivity.
- **Pins expire on your release cadence, not the CA's.** If a pin's certificate expires before
  the app version carrying it falls out of use, those installs stop working.
- **It does not protect a rooted device.** Frida can hook the check out in minutes; pinning
  raises cost for the network attacker, not for someone holding the device.

**A workable policy:** pin the public key, ship two pins, keep a server-delivered kill switch
that can disable pinning remotely, monitor pinning failure rates, and rehearse rotation
before shipping. If any of that is missing, ship TLS without pinning — a broken app is worse
than an unpinned one for almost every threat model.

## Secrets do not belong in the client

An API key in the app is an API key you have published. Obfuscation, `--dart-define`,
splitting it into three strings, storing it in the native layer — all of it is decoration.
The binary is on the attacker's device, and `strings` plus a debugger is a five-minute job.

What to do instead:

- **Route third-party calls through your backend.** The key lives on the server; the client
  authenticates as the user. This is the answer for payment providers, mail services and
  anything billed per call.
- **Use keys that are designed to be public** — a Firebase Web API key, a Maps key — and
  restrict them by bundle id, SHA-1 fingerprint, referrer and quota on the provider's console.
  Restriction is the control, not secrecy.
- **Short-lived, server-issued tokens** for anything else. A token minted per session with a
  narrow scope limits what a stolen one can do.

If a secret has already shipped, **rotate it** — removing it from the source tree does
nothing for the versions already installed, and it stays in git history.

## Detecting interception

You cannot reliably detect a man in the middle from inside the app, and code that claims to
is usually detecting a proxy configuration rather than an attack. What actually helps:

- **Certificate validation failures reported as a metric**, not swallowed. A spike is a
  signal — a broken deployment, a captive portal, or something worse.
- **Server-side anomaly detection.** Impossible travel, request patterns, token reuse across
  IPs. The server has the whole picture; the client sees one device.
- **Short token lifetimes and revocation.** The mitigation that works regardless of how the
  interception happened.

## A practical checklist

Before a release that handles anything sensitive:

- [ ] Cleartext disabled on both platforms; no `NSAllowsArbitraryLoads`.
- [ ] No `badCertificateCallback` returning true on any code path, including debug.
- [ ] No user-installed CA trust in the Android network security config.
- [ ] No API keys or secrets in the repository, `--dart-define`, or the binary.
- [ ] Public-by-design keys restricted by bundle id and quota at the provider.
- [ ] Access tokens short-lived; refresh tokens rotated; sessions revocable server-side.
- [ ] Pinning either absent, or shipped with two pins, a kill switch and a rehearsed rotation.
- [ ] TLS 1.2 minimum, verified against the production endpoint rather than assumed.

## Interview angles

**"Explain SSL pinning."** The app refuses connections whose certificate chain does not match
a compiled-in value, which defeats an attacker holding a trusted CA. Then the sentence that
separates a senior answer: it also means an unplanned certificate change bricks every
installed copy, so it needs two pins, a kill switch and a rehearsed rotation — and it does
not help against someone holding the device.

**"Where do you store an API key?"** Not in the client. Proxy through your backend, or use a
key designed to be public and restrict it by bundle id and quota. Anything else is
obfuscation, and obfuscation of a value the binary must contain is not protection.

**"How do you protect traffic?"** TLS with platform defaults and cleartext disabled, no
validation bypass anywhere, short-lived tokens, and server-side detection. Pinning as an
optional extra with a stated cost.

**"How would you handle a leaked key?"** Rotate it first — it is in the installed versions
and in git history, so removing the line changes nothing. Then move it server-side so it
cannot leak again.

## See also

- [Secure storage](security-storage.md) — where tokens live on the device
- [Obfuscation and hardening](security-hardening.md) — what raising cost does and does not do
- [Networking](../part-03-data/networking.md) — interceptors and token refresh
- [Flavors](ci-flavors.md) — a debug configuration that cannot reach release
