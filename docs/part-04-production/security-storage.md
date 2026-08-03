# Secure storage

Keychain, Keystore, and what should never touch shared preferences.

## The recommendation

**Tokens, keys and anything that grants access go in `flutter_secure_storage`; everything
else can go anywhere.** The rule is short because the boundary is: if leaking the value lets
someone act as the user, it needs the OS-backed store. Then accept the honest limit — on a
rooted or jailbroken device with the app unlocked, a determined attacker gets it anyway, and
your design should assume that.

## What each store actually is

| Store | Backed by | Encrypted at rest | In device backups | Right for |
| --- | --- | --- | --- | --- |
| `shared_preferences` | plist / XML in the sandbox | No | Yes | Theme, last tab, flags |
| Hive | A file in the sandbox | Only if you encrypt it | Yes | Structured settings, caches |
| `flutter_secure_storage` | Keychain / Keystore | Yes, by the OS | Configurable | Tokens, keys, secrets |
| SQLite + SQLCipher | An encrypted database file | Yes | Yes | Bulk sensitive data |

**`shared_preferences` is not secure and is not trying to be.** On Android it is an XML file
in the app's data directory; on iOS a plist. Both are readable with root, with a jailbreak,
from an unencrypted backup, and on Android from `adb backup` where the app allows it. Storing
a refresh token there is the single most common mobile security finding in an audit.

## Using secure storage properly

```dart
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,   // AES via the Keystore, not the legacy path
  ),
  iOptions: IOSOptions(
    // The default (kSecAttrAccessibleWhenUnlocked) syncs to iCloud Keychain and
    // restores onto a new device — which is wrong for a device-bound token.
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

await storage.write(key: 'refresh_token', value: token);
```

Two details that are usually wrong in real apps:

- **iOS accessibility.** `first_unlock_this_device` keeps the value off iCloud and off a
  restored device. Use `unlocked_this_device` for something that must not be readable while
  the phone is locked — but note that a background sync then cannot read it.
- **Android backing.** With `encryptedSharedPreferences: true` values are AES-encrypted with
  a Keystore-held key, hardware-backed on devices with a TEE or StrongBox. Without it, older
  plugin versions fall back to a weaker path.

Expect reads to fail. A Keystore key can be invalidated by a lock-screen change, a restore, a
device migration or an OS bug. Handle it as "the user must sign in again", never as a crash:

```dart
Future<String?> readToken() async {
  try {
    return await storage.read(key: 'refresh_token');
  } on PlatformException {
    await storage.deleteAll();   // corrupt or invalidated: start clean
    return null;
  }
}
```

## Tokens: what to store and for how long

- **Access token:** short-lived (minutes to an hour). Keeping it in memory only is the
  strongest option; secure storage is acceptable and survives a restart.
- **Refresh token:** long-lived, always in secure storage, **rotated on every use** if the
  backend supports it. Rotation turns a stolen token into a detectable event — the legitimate
  client's next refresh fails, and the server can revoke the family.
- **Nothing else.** No passwords, no PANs, no long-lived API keys. If the client can decrypt
  it, so can whoever has the device.

Racing refreshes are the failure mode that makes rotation dangerous if you get it wrong —
five 401s refreshing at once invalidate each other's tokens. That is the single-flight
refresher in [networking](../part-03-data/networking.md#token-refresh-done-once).

Clear everything on logout — tokens, caches, database, and the session scope in your DI
container. A "log out" that leaves the previous user's cached orders on disk is a real
finding, and it is usually the field somebody forgot.

## Biometric gating

```dart
final auth = LocalAuthentication();
final ok = await auth.authenticate(
  localizedReason: 'Confirm to view your account',
  options: const AuthenticationOptions(
    biometricOnly: false,   // allow device PIN as a fallback, or you lock people out
    stickyAuth: true,       // survive an app switch mid-prompt
  ),
);
```

Understand what the boolean means. `authenticate` returns **true or false in your Dart code**
— on a device where the attacker controls the runtime, that return value can be patched. Two
consequences:

- **Biometrics gate the UI, not the data.** A `true` from `local_auth` is a user-experience
  gate. To make it a real one, bind the secret to the authentication: store it with
  `AndroidOptions(...)` requiring user authentication for the Keystore key, or use the
  Keychain's `biometryCurrentSet` access control so the OS refuses to release the value
  without a successful biometric.
- **Never do the authorisation client-side.** Sensitive operations are authorised by the
  server against a token; biometrics decide whether the app is willing to *use* that token.

## What encryption at rest does not protect

Worth stating plainly, because "we encrypt it" is often treated as the end of the discussion:

- **A running app with the data decrypted.** Frida, a debugger, or a hooked runtime reads it
  out of memory. Encryption at rest is exactly that — at rest.
- **A rooted or jailbroken device.** The OS guarantees the store depends on are gone.
- **Screenshots, logs and crash reports.** A token logged in a debug print, or a screenshot in
  the app switcher, bypasses the store entirely. Use `FLAG_SECURE` on Android and a blur
  overlay on iOS for sensitive screens, and never log a token — see
  [observability](../part-05-enterprise/observability.md).
- **The clipboard.** Copying an OTP or a password puts it somewhere every app can read.
- **A compromised backend.** The client's storage is irrelevant if the server hands data to
  anyone who asks.

The design conclusion: **assume the client can be compromised, and make that survivable.**
Short token lifetimes, rotation, server-side authorisation, and the ability to revoke a
session remotely are worth more than any client-side hardening.

## Interview angles

**"How secure is `SharedPreferences`?"** Not secure at all — a plain XML file or plist in the
app sandbox, readable with root or a jailbreak and present in backups. It is for preferences.
Tokens go in the Keychain or the Keystore.

**"SecureStorage versus Hive?"** Different jobs. Secure storage is a small OS-backed store
where the key is protected by hardware; Hive is a general store whose encryption is only as
good as where you keep its key — which should be secure storage. Use both together.

**"How do you store a JWT?"** Access token in memory or secure storage, refresh token in
secure storage with rotation on use, cleared on logout. Then the part that shows judgement:
storage matters less than lifetime and revocation, because a compromised device beats any
client-side store.

**"Is biometric authentication secure?"** The prompt is; the boolean it returns to your Dart
code is not. Bind the secret to the biometric at the OS level, and keep authorisation on the
server.

## See also

- [Network security](security-network.md) — TLS, pinning, and secrets off the client
- [Obfuscation and hardening](security-hardening.md) — raising cost, not preventing
- [Networking](../part-03-data/networking.md) — token refresh done once
- [Hive](../part-03-data/hive.md) — encryption and where the key belongs
