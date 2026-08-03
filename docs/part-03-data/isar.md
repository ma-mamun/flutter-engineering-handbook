# Isar

A NoSQL local database with fast queries, watchers, and an inspector — plus a maintenance
question you have to answer before adopting it.

## The recommendation

**Check the project's current maintenance status before choosing Isar for new work.** Isar 3
is fast and pleasant, and its community fork (`isar_community`) is where activity moved after
the original project stalled in 2023–2024. That is a real risk to weigh: a database is the
hardest dependency to replace, and "the maintainer stopped" is a migration you cannot
schedule. For a new app, [Drift](drift.md) is the safer default. Isar earns its place where
its performance profile genuinely matters and you have accepted that risk deliberately.

## The model

Isar stores Dart objects in collections, with indexes you declare:

```dart
@collection
class Order {
  Id id = Isar.autoIncrement;          // or a hashed string id

  @Index(unique: true, replace: true)
  late String uuid;                    // client-generated, for sync

  @Index(composite: [CompositeIndex('createdAt')])
  late String userId;

  @enumerated
  late OrderStatus status;

  late int totalCents;
  late DateTime createdAt;

  final items = IsarLinks<OrderItem>();   // link, not a foreign key
}
```

Differences from SQL that shape the design:

- **No joins.** `IsarLinks` gives you traversal, not a join — a query cannot filter parents by
  a child's field without loading and filtering. Denormalise fields you need to query on.
- **Objects, not rows.** Nested objects are stored inline, so the "one big document" shape is
  natural and there is no mapping layer.
- **Indexes are explicit and typed**, including composite and multi-entry indexes for lists.

## Queries and watchers

```dart
final open = await isar.orders
    .filter()
    .userIdEqualTo(userId)
    .statusEqualTo(OrderStatus.open)
    .sortByCreatedAtDesc()
    .limit(20)
    .findAll();

// Re-emits when anything in the collection changes.
final stream = isar.orders.filter().userIdEqualTo(userId).watch(fireImmediately: true);
```

Two properties worth knowing:

- **Synchronous reads are available** (`findAllSync`) and genuinely fast, which is why Isar
  shows up in benchmarks. Use them only for small result sets on the UI isolate — a
  synchronous read of ten thousand objects blocks a frame just as effectively as any other
  work.
- **Watchers fire per collection change by default.** `watchObject` narrows to one object,
  and filtering a broad watcher in Dart re-runs your predicate on every write.

## Writes and transactions

```dart
await isar.writeTxn(() async {
  await isar.orders.putAll(orders);       // upsert by id
  await order.items.save();               // links are saved separately
});
```

`putAll` inside one transaction is the batch path, and the difference from one-at-a-time
writes is the same order of magnitude as in SQLite. Two Isar-specific gotchas:

- **Links are not saved with the object.** `order.items.save()` is a separate call, and
  forgetting it silently drops the relationship.
- **Write transactions are exclusive.** A long write blocks readers on the same isolate.

## Migrations

Isar handles many changes implicitly: adding a field gives existing objects the default,
removing one drops it on next write. What is *not* implicit is anything that changes the
meaning of stored data — a renamed field, a changed type, a re-scaled value.

```dart
final isar = await Isar.open([OrderSchema], directory: dir);
final version = prefs.getInt('isar_schema_version') ?? 1;

if (version < 2) {
  await isar.writeTxn(() async {
    final all = await isar.orders.where().findAll();
    for (final order in all) {
      order.totalCents = (order.legacyTotal * 100).round();  // rescale
    }
    await isar.orders.putAll(all);
  });
  await prefs.setInt('isar_schema_version', 2);
}
```

You are tracking the version yourself. That is the honest cost of implicit migrations: the
easy cases are free, and the hard cases have no framework support, no ordering guarantees and
no test harness comparable to [Drift's](drift.md#migrations). Write the version number down
from version one, or you will not be able to tell which transformations a given install has
already had.

## The inspector

`Isar.open(inspector: true)` in debug serves a web UI showing collections, live query
results, and edits. It is genuinely better than the SQLite equivalents and it shortens the
"is the data actually there" loop considerably. Keep it out of release builds.

## Isar versus Drift

| | Isar | Drift |
| --- | --- | --- |
| Model | NoSQL documents with links | Relational SQL |
| Joins | No — denormalise or traverse | Yes |
| Raw query escape hatch | Limited | Full SQL |
| Migrations | Implicit, manual for real changes | Explicit, testable |
| Sync reads | Yes | No |
| Inspector | Excellent | DevTools plus SQL tooling |
| Maintenance | Community fork; verify before adopting | Actively maintained |

**Pick Isar when** the data is document-shaped, queries are single-collection, and the
inspector plus synchronous reads solve a real problem for you.
**Pick Drift when** the data is relational, you want compile-time checked queries and tested
migrations, or the app has a multi-year horizon.

## If you have to migrate off it

The route that works, in order:

1. **Put a repository interface in front of it first**, if there is not one already. Every
   call site should already go through the domain contract from
   [Clean Architecture](../part-02-professional/clean-architecture.md).
2. **Write the new schema in Drift** alongside, without removing Isar.
3. **On first launch after the update, copy collection by collection inside a transaction**,
   with a persisted flag per collection so an interrupted migration resumes rather than
   restarting.
4. **Keep the Isar files for one release** before deleting them, so a rollback is possible.
5. Delete the Isar dependency in the release after that.

That is the general shape for replacing any local database, and it is why the repository
interface matters before you need it.

## Interview angles

**"When would you choose a NoSQL database on mobile?"** Document-shaped data with no joins,
where objects map to storage without a mapping layer. Then name what you give up: joins,
declarative migrations, and a raw query escape hatch.

**"How do you evaluate a database dependency?"** Maintenance status and bus factor, migration
story, query capability against your actual access patterns, and how hard it is to leave.
Isar is a good example to discuss precisely because the maintenance answer changed after
adoption for a lot of teams.

**"How would you migrate between local databases?"** Repository interface first, dual-write
or one-shot copy inside transactions with a resumable flag, keep the old files for one
release, then delete. The point is that it is a release-spanning plan, not a code change.

## See also

- [Drift](drift.md) — the relational alternative
- [Hive](hive.md) — when key-value is enough
- [SQLite](sqlite.md) — the engine underneath most of the alternatives
- [Offline first](offline-first.md) — what the database is actually for
