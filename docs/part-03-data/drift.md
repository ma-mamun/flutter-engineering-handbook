# Drift

Type-safe SQL over SQLite, with reactive queries and migrations you can test.

## The recommendation

**Drift is the default local database for a Flutter app with relational data.** It is SQLite
underneath, so nothing is given up, and it adds three things worth the `build_runner` step:
compile-time checked queries, streams that re-emit when the underlying rows change, and a
migration testing harness. If your data is not relational, [Hive](hive.md) or
[Isar](isar.md) may fit better.

## Tables and queries

```dart
class Orders extends Table {
  TextColumn get id => text()();                        // client-generated UUID
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get status => textEnum<OrderStatus>()();
  IntColumn get totalCents => integer()();              // never a float for money
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Orders, Users], daos: [OrderDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 3;
}
```

Queries are checked at compile time, which is the whole point:

```dart
Future<List<Order>> recentFor(String userId) {
  return (select(orders)
        ..where((o) => o.userId.equals(userId) & o.status.equalsValue(OrderStatus.open))
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
        ..limit(20))
      .get();
}
```

Rename a column and every query referencing it fails to compile — the failure moves from a
user's device to your build. That is the difference from raw `sqflite`, and it is the reason
to accept the code generation step.

For queries the DSL cannot express, drop to SQL and keep the type safety:

```dart
@DriftDatabase(include: {'queries.drift'})   // .drift files are checked too
```

## Reactive queries

The feature that changes how screens are built:

```dart
Stream<List<Order>> watchRecent(String userId) =>
    (select(orders)..where((o) => o.userId.equals(userId))).watch();
```

Any write touching `orders` — from a sync engine, a background isolate, another DAO —
re-emits this stream. Combined with a `StreamProvider` or `StreamBuilder`, the UI follows the
database with no manual invalidation, which removes an entire class of "the list did not
refresh" bugs.

**The cost:** the stream re-runs the whole query on any write to the tables it reads, not
just on rows that matched. On a table under heavy sync load, that is a query per write.
Narrow the watch (`limit`, a tighter `where`), or debounce it — the extension from
[the async page](../part-01-foundations/dart-async.md) works directly on these streams.

## DAOs

Split queries by feature so the database class does not become a two-thousand-line file:

```dart
@DriftAccessor(tables: [Orders])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  Future<void> upsertAll(List<OrderRow> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(orders, rows));

  Future<void> markSynced(String id) =>
      (update(orders)..where((o) => o.id.equals(id)))
          .write(const OrdersCompanion(pendingSync: Value(false)));
}
```

`Companion` objects are how Drift distinguishes "set this column to null" from "leave this
column alone" — `Value(null)` versus `Value.absent()`. Getting that wrong silently wipes
fields on update, and it is the most common Drift bug.

## Migrations

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(orders, orders.version);
        }
        if (from < 3) {
          await m.createIndex(Index('idx_orders_user_created',
              'CREATE INDEX idx_orders_user_created ON orders (user_id, created_at DESC)'));
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        if (details.wasCreated) {
          await _seedReferenceData();
        }
      },
    );
```

Same rules as [raw SQLite](sqlite.md#migrations-without-data-loss): sequential, append-only,
never edited after release, `if (from < n)` rather than `switch` so a user skipping a version
falls through every step.

What Drift adds, and the reason to prefer it here:

```bash
dart run drift_dev schema dump lib/database.dart drift_schemas/   # snapshot per version
dart run drift_dev schema generate drift_schemas/ test/generated/ # test helpers
```

Then a test migrates a real v1 database to v3 and verifies the schema matches:

```dart
test('migrates v1 to v3 without losing orders', () async {
  final schema = SchemaVerifier(GeneratedHelper());
  final db = await schema.startAt(1);
  await db.customStatement("INSERT INTO orders (id, user_id, ...) VALUES ('o1', 'u1', ...)");

  await schema.migrateAndValidate(AppDatabase(db), 3);

  final rows = await db.customSelect('SELECT * FROM orders').get();
  expect(rows, hasLength(1));
});
```

This is the highest-value test in the data layer. A migration bug corrupts data on devices
you cannot reach, and it is discovered by users rather than by you.

## Running off the UI isolate

```dart
// Drift 2.x: the database runs on its own isolate, and queries do not touch
// the UI isolate at all.
final db = AppDatabase(
  driftDatabase(name: 'app', native: const DriftNativeOptions(shareAcrossIsolates: true)),
);
```

Worth doing when a sync engine writes while the user scrolls. The cost is that every result
crosses an isolate boundary and is copied, so a query returning 10,000 rows is now a 10,000
row copy — paginate either way.

## Drift versus the alternatives

| | Drift | raw `sqflite` | Isar | Hive |
| --- | --- | --- | --- | --- |
| Storage model | Relational SQL | Relational SQL | NoSQL documents | Key-value |
| Compile-time safety | Yes | No | Partial | No |
| Reactive queries | Yes | No | Yes | Box-level only |
| Migrations | Explicit, testable | Explicit, manual | Mostly implicit | Manual |
| Joins | Yes | Yes | Links | No |
| Code generation | Required | None | Required | For adapters |
| Maintenance | Active | Active | See [Isar](isar.md) | See [Hive](hive.md) |

## The cost

- **`build_runner` in every developer's loop.** A schema change means regenerating before the
  code compiles.
- **Generated files** that are large and either committed or regenerated in CI — pick one and
  write it down.
- **A learning curve on the DSL**, and a moment for every SQL-fluent developer where the DSL
  cannot express what they want and they have to find the `.drift` file escape hatch.

None of that outweighs compile-checked queries and testable migrations on an app that will
be maintained for years.

## Interview angles

**"Why Drift over sqflite?"** Compile-time checked queries, reactive streams that follow the
database, and a migration test harness — all on the same SQLite engine. The cost is code
generation.

**"How do you test a migration?"** Snapshot the schema per released version, open a database
at the old version with real rows, migrate, and assert both the schema and the data. Say why
it matters: migration bugs corrupt data on devices you cannot reach.

**"How do reactive queries work?"** Drift tracks which tables a query reads and re-runs it
when any of them is written. Then the cost: on a write-heavy table, one query per write, so
narrow or debounce the watch.

## See also

- [SQLite](sqlite.md) — the engine, indexing, and migration mechanics
- [Offline first](offline-first.md) — transactions around the outbox
- [Isar](isar.md) and [Hive](hive.md) — when relational is the wrong shape
- [Unit tests](../part-02-professional/testing-unit.md) — testing the data layer
