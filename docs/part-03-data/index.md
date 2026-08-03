# Part 3 — Data

Networking, caching and persistence — the layer where most production bugs actually live.

UI bugs are visible and get fixed. Data bugs are the ones that reach support tickets: a
duplicate charge from a retried POST, a user silently logged out by racing token refreshes, a
list that repeats a row when it scrolls, an edit lost because two devices disagreed about
which was newer. Every page in this part is written around one of those.

## Pages

- **[Networking](networking.md)** — choosing a client, interceptor order, single-flight token
  refresh, retry with backoff and jitter, timeouts versus cancellation, cursor pagination,
  serialisation at the boundary, ETags, PUT versus PATCH.
- **[Offline first](offline-first.md)** — the local database as the source of truth, read
  strategies, the outbox pattern, optimistic updates and rollback, conflict resolution
  policies, delta sync with tombstones, and surfacing sync state.
- **[SQLite](sqlite.md)** — schema design for mobile, migrations that do not lose data,
  indexing and query plans, transactions and batches.
- **[Drift](drift.md)** — compile-time checked queries, reactive streams, DAOs, and the
  migration test harness that makes migrations safe.
- **[Isar](isar.md)** — the document model, links and watchers, implicit migrations and their
  cost, and the maintenance question to answer before adopting it.
- **[Hive](hive.md)** — boxes and adapters, encryption and where the key belongs, and the
  five signals that you have outgrown it.

## Choosing a local database

| Your data is | Use |
| --- | --- |
| A dozen primitive settings | `shared_preferences` |
| Structured settings or a small cache | [Hive](hive.md) |
| Relational, queried, sorted, joined | [Drift](drift.md) |
| Document-shaped, single-collection queries | [Isar](isar.md), after checking maintenance |
| Relational, and you want full control of the SQL | [sqflite](sqlite.md) |
| Secrets — tokens, keys | [Secure storage](../part-04-production/security-storage.md) |

The default for an app with real data is Drift: it is SQLite, so nothing is given up, and it
adds compile-time checked queries and testable migrations.

## Runnable samples

`code/networking/` holds the three pieces every production data layer needs and most get
subtly wrong, each with tests that assert the property rather than the happy path:

- `retry.dart` — exponential backoff with jitter, a predicate that refuses to retry a 404,
  and an idempotency check.
- `token_refresh.dart` — single-flight refresh: five concurrent 401s produce exactly one
  refresh call.
- `paginator.dart` — cursor pagination with a concurrency guard, deduplication, and a failed
  page that keeps what was already loaded.
