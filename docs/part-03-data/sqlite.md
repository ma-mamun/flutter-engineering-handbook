# SQLite

Schema design, migrations that do not lose data, and indexing for mobile workloads.

## The recommendation

**SQLite for anything relational, queried, or larger than a few hundred rows.** Use `sqflite`
directly when you want full control of the SQL, and [Drift](drift.md) when you want the same
engine with type safety and reactive queries. Design the schema before the first release —
migrations are the expensive part, and they are only expensive because the first schema was
rushed.

## When raw SQL beats an ORM

- **Complex queries.** Window functions, recursive CTEs, `GROUP BY` with `HAVING`. Every ORM
  eventually makes you drop to raw SQL for these; starting there avoids the fight.
- **Bulk operations.** `INSERT ... SELECT` and batch upserts, where round-tripping through
  Dart objects is the bottleneck.
- **Fewer dependencies.** No `build_runner`, no generated files, faster CI.

The cost is real and worth naming: no compile-time checking. A typo in a column name is a
runtime exception on the user's device. That is the argument for Drift, and it is a strong
one — see [that page](drift.md) for the comparison.

## Schema design for mobile

```sql
CREATE TABLE orders (
  id            TEXT PRIMARY KEY,          -- client-generated UUID, not AUTOINCREMENT
  user_id       TEXT NOT NULL,
  status        TEXT NOT NULL,
  total_cents   INTEGER NOT NULL,          -- never a float for money
  created_at    INTEGER NOT NULL,          -- millisecondsSinceEpoch, UTC
  updated_at    INTEGER NOT NULL,
  version       INTEGER NOT NULL DEFAULT 0, -- optimistic concurrency
  pending_sync  INTEGER NOT NULL DEFAULT 0, -- 0/1: SQLite has no boolean
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) STRICT;                                  -- SQLite 3.37+: reject wrong types
```

The decisions in that table, each of which is a bug avoided:

- **Client-generated UUIDs, not `AUTOINCREMENT`.** A row created offline needs an identity
  before the server sees it, and two devices must not both create id 5. See
  [offline first](offline-first.md).
- **Money in integer cents.** Floating point money is wrong by design; `0.1 + 0.2` is the
  canonical demonstration.
- **Timestamps as integers, UTC.** Sortable, comparable, timezone-free. Convert at the edge
  for display.
- **`STRICT` tables.** Without them SQLite happily stores `'banana'` in an INTEGER column —
  it uses type affinity, not type checking.
- **A `version` column** so a conflicting write can be detected rather than silently
  overwriting.
- **`ON DELETE CASCADE`**, and remember `PRAGMA foreign_keys = ON` — SQLite disables foreign
  keys by default, per connection.

## Configuration that matters

```dart
final db = await openDatabase(
  path,
  version: 3,
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys = ON');   // off by default, per connection
  },
  onCreate: _createSchema,
  onUpgrade: _migrate,
  onDowngrade: onDatabaseDowngradeDelete,          // a downgrade means a rolled-back app
);

// Write-ahead logging: readers no longer block on the writer. On a mobile app
// with a background sync writing while the UI reads, this is the difference
// between smooth scrolling and a stalled list.
await db.execute('PRAGMA journal_mode = WAL');
```

## Migrations without data loss

The rule that prevents most incidents: **migrations are append-only and run in sequence.**
Never edit a shipped migration — users are on every version you ever released, and the app
that skipped v2 must still get there.

```dart
Future<void> _migrate(Database db, int from, int to) async {
  // No breaks: a user on v1 upgrading to v3 falls through both steps.
  if (from < 2) {
    await db.execute('ALTER TABLE orders ADD COLUMN version INTEGER NOT NULL DEFAULT 0');
  }
  if (from < 3) {
    await db.execute('CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC)');
  }
}
```

SQLite's `ALTER TABLE` is limited: it can add a column, rename a table or column (3.25+), and
drop a column (3.35+). Anything else — changing a type, adding a constraint, reordering —
needs the twelve-step dance:

```sql
PRAGMA foreign_keys = OFF;
BEGIN;
CREATE TABLE orders_new (...);                        -- the new shape
INSERT INTO orders_new SELECT id, user_id, ... FROM orders;   -- copy, transforming
DROP TABLE orders;
ALTER TABLE orders_new RENAME TO orders;
CREATE INDEX ...;                                     -- indexes do not survive
COMMIT;
PRAGMA foreign_keys = ON;
```

Three things people get wrong here: doing it outside a transaction (a crash mid-migration
leaves no `orders` table at all), forgetting to recreate indexes and triggers, and not
turning foreign keys off first — the `DROP` cascades and deletes children.

!!! warning "Test the migration path, not just the final schema"
    A test that opens a fresh database at v3 proves nothing about a user upgrading from v1
    with 4,000 rows. Keep a fixture database per shipped version, run the migration against
    each, and assert both the schema and the row counts. This is the single highest-value
    test in the data layer, and it is the one most teams discover they need after the
    support tickets arrive.

## Indexing

Index the columns you filter, join and sort by — and check that the index is actually used:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 20;
-- SEARCH orders USING INDEX idx_orders_user_created (user_id=?)   <- good
-- SCAN orders                                                     <- add an index
```

Rules that cover most cases:

- **Composite index column order follows the query**: equality columns first, then the range
  or sort column. `(user_id, created_at DESC)` serves the query above; `(created_at, user_id)`
  does not.
- **A covering index** — one containing every column the query needs — avoids touching the
  table at all. Worth it for hot list queries.
- **Indexes cost writes and disk.** Each one is updated on every insert and update. Three
  indexes on a sync-heavy table can double insert time.
- **`LIKE '%foo%'` cannot use an index.** For text search use FTS5, which is built into
  SQLite and is a virtual table you populate with triggers.

## Transactions and batches

```dart
// One transaction: 1,000 inserts commit once instead of 1,000 fsyncs.
await db.transaction((txn) async {
  final batch = txn.batch();
  for (final order in orders) {
    batch.insert('orders', order.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);   // noResult skips building a result list
});
```

The difference is not marginal. Inserting a few thousand rows one statement at a time takes
seconds on a mid-range Android device; the same rows in one transaction take tens of
milliseconds. Every sync that writes a batch should be doing this.

Keep transactions short. SQLite takes a write lock for the duration, and a transaction that
awaits a network call inside it blocks every other writer until the request finishes — a
common cause of "the app freezes while syncing".

## Where to run it

`sqflite` runs on a background platform thread, so queries do not block the UI isolate. What
*does* block is converting thousands of rows into Dart objects. If a query returns 10,000
rows and you map each to a model, that mapping is on your isolate.

Fixes, in order: **query less** (paginate, `LIMIT`), **select fewer columns**, then move the
mapping to an isolate. `sqflite_common_ffi` and Drift's isolate support let the whole
database run on a background isolate, which is the right answer for a sync engine.

## Interview angles

**"When would you use SQLite over a key-value store?"** Relational data, queries with filters
and joins, sorting, and anything more than a few hundred rows. A key-value store forces you
to load and filter in Dart, which is O(everything) per read.

**"How do you migrate a schema without losing data?"** Sequential, append-only migrations
that never get edited after release; the copy-and-rename dance for anything `ALTER TABLE`
cannot do; all of it inside a transaction; and a test per shipped version that migrates a
real fixture database.

**"How do you speed up a slow query?"** `EXPLAIN QUERY PLAN` first. Then a composite index
ordered equality-then-range, a covering index for hot queries, and pagination. Mention the
write cost of indexes — that is the tradeoff an interviewer is listening for.

**"Why are 5,000 inserts slow?"** Each statement is its own transaction and its own fsync.
Wrap them in one transaction.

## See also

- [Drift](drift.md) — the same engine with type safety and reactive queries
- [Isar](isar.md) and [Hive](hive.md) — the non-SQL options
- [Offline first](offline-first.md) — transactions around the outbox
- [Memory](../part-04-production/performance-memory.md) — row mapping on the UI isolate
