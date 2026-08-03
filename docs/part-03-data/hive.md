# Hive

Key-value storage for small, simple state — and a clear line for where it stops being the
right tool.

## The recommendation

**Use Hive for what a preferences file would hold, and nothing more.** Settings, feature
flags, a cached auth session, the last selected tab, a small list of recently viewed ids.
The moment you need to query, sort, join or store more than a few thousand entries, move to
[Drift](drift.md) — Hive has no query engine, so every "find where" is a full load and a
filter in Dart.

Note the version situation before adopting: Hive 2 is stable and widely used but no longer
actively developed; Hive 4 (`hive_ce`, the community edition) is where maintenance moved.
Check which one you are pulling in.

## Boxes

```dart
await Hive.initFlutter();
Hive.registerAdapter(SettingsAdapter());

final settings = await Hive.openBox<Settings>('settings');
await settings.put('current', Settings(theme: ThemeMode.dark, locale: 'en'));
final current = settings.get('current');
```

Three facts that determine how you should use it:

- **A box is loaded into memory on open**, and stays there. That is why reads are
  synchronous and fast, and also why a large box is a memory problem rather than a disk one.
- **`LazyBox` reads from disk per key**, trading speed for memory. Use it if a box is large —
  though a large box is usually a sign you want a database.
- **Writes are appended to a log and compacted periodically.** The file grows with the number
  of writes, not the number of keys, until compaction runs.

## Type adapters

```dart
@HiveType(typeId: 1)
class Settings extends HiveObject {
  @HiveField(0) late ThemeMode theme;
  @HiveField(1) late String locale;
  @HiveField(2) String? lastSyncCursor;    // added in v2 — new field, new index
}
```

The rules are strict and unforgiving, because the field index is the serialisation format:

- **Never reuse or reorder a `@HiveField` index.** Index 1 means "locale" forever. Reusing it
  for something else reads old data as the new type and produces garbage or a crash.
- **Never change a field's type.** Add a new field and migrate.
- **`typeId` is global and permanent.** Keep a registry in a comment, because a duplicate
  produces a runtime error only when both types are used.
- **Deleting a field is safe**; the stored value is ignored. Deleting *and later reusing* the
  index is not.

## Encryption

```dart
final key = await secureStorage.read(key: 'hive_key');
final bytes = key == null ? Hive.generateSecureKey() : base64Decode(key);
if (key == null) {
  await secureStorage.write(key: 'hive_key', value: base64Encode(bytes));
}

final box = await Hive.openBox<Token>('tokens', encryptionCipher: HiveAesCipher(bytes));
```

What this does and does not buy you:

- **It encrypts values at rest** with AES-256, so the file is not readable by pulling it off
  a backup or an unlocked device with file access.
- **It does not protect the key**, unless the key lives in the Keychain or the Keystore —
  which is exactly what the code above does. An encryption key stored in the box, in the
  code, or in `SharedPreferences` provides no protection at all.
- **It does not make Hive a secure storage replacement** for tokens on a rooted or
  jailbroken device. See [secure storage](../part-04-production/security-storage.md) for the
  comparison.

## Where Hive stops scaling

The signals, in the order they usually appear:

1. **You write a query in Dart.** `box.values.where((o) => o.userId == id && o.open)` loads
   and filters everything, every time. That is O(n) per read and it is invisible until n
   grows.
2. **You maintain your own index.** A second box mapping `userId -> [orderIds]`, kept in sync
   by hand. You are now writing a database, badly.
3. **Startup gets slower.** Every open box is deserialised into memory at launch.
4. **Two writes must be atomic** and there is no transaction to make them so — the outbox
   pattern from [offline first](offline-first.md) cannot be implemented correctly.
5. **A schema change needs a data transformation** and you have no migration framework.

Any two of those together mean it is time to move.

## Hive versus the alternatives

| | Hive | `shared_preferences` | Drift |
| --- | --- | --- | --- |
| Model | Key-value, typed objects | Key-value, primitives | Relational SQL |
| Queries | None | None | Full |
| Transactions | No | No | Yes |
| Encryption | Optional AES | No | Via SQLCipher |
| Sync reads | Yes | Yes (after load) | No |
| Right for | Structured settings, small caches | A handful of primitives | Anything queried |

`shared_preferences` is genuinely simpler for a dozen primitive values and has no adapters to
maintain. Hive earns its place when the values are objects.

## Migrating off it

Same shape as any storage migration:

1. Put a repository interface in front of it, if there is not one.
2. Create the new schema alongside.
3. On first launch after the update, copy box by box inside a transaction, with a persisted
   per-box flag so an interrupted migration resumes.
4. Keep the Hive files for one release, then delete.

Because Hive data is usually small, this migration is one of the cheaper ones — which is an
argument for using it early and moving on without regret when it stops fitting.

## Interview angles

**"How secure is `SharedPreferences`?"** Not secure. It is a plist on iOS and an XML file in
the app sandbox on Android — readable on a rooted or jailbroken device, and included in
backups. It is for preferences, not for tokens.

**"SecureStorage versus Hive?"** Different jobs. `flutter_secure_storage` puts a small value
in the Keychain or the Keystore, protected by the OS and hardware-backed where available.
Hive is a general store that can be AES-encrypted, and its encryption is only as good as
where you keep the key — which should be secure storage. Use secure storage for the key and
Hive for the data.

**"When would you not use Hive?"** As soon as you need queries, transactions, or more than a
few thousand entries. Give the tell: the first `box.values.where(...)` is the signal you
have outgrown it.

## See also

- [Drift](drift.md) — where to go when queries appear
- [Secure storage](../part-04-production/security-storage.md) — where the encryption key lives
- [Offline first](offline-first.md) — why the outbox needs transactions
- [SQLite](sqlite.md) — the engine behind the relational options
