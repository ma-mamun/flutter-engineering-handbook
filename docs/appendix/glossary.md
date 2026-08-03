# Glossary

Terms used throughout the handbook, defined once. Where a term has a page, this is the short
version and the page is the long one.

## Framework

**Widget** — Immutable configuration describing part of the UI. Cheap, rebuilt constantly, holds
no state. → [three trees](../part-01-foundations/flutter-three-trees.md)

**Element** — The mutable instance occupying a position in the tree. Holds `State`, and decides
whether a new widget updates or replaces what is there. A `BuildContext` *is* an element.

**RenderObject** — The object that computes size, positions children, paints and answers hit
tests. Most widgets do not create one.

**BuildContext** — A handle to an element, used to look up ancestors. It has a position in the
tree, and it becomes invalid when the element is unmounted.

**InheritedWidget** — A widget that propagates data down the tree efficiently. `of(context)`
registers a dependency, so dependents rebuild when it changes. The mechanism behind Provider.

**Key** — An identity hint used when matching new widgets to existing elements. A `LocalKey`
(`ValueKey`, `ObjectKey`, `UniqueKey`) need only be unique among siblings; a `GlobalKey` is
unique app-wide.

**Layer / layer tree** — The output of the paint phase: recorded drawing commands, grouped so
the compositor can reuse them.

**RepaintBoundary** — A render object that isolates its subtree into its own layer, so repainting
it does not repaint neighbours. Costs GPU memory and a compositing step.

**Constraints** — The `BoxConstraints` a parent passes down. *Tight* means min equals max;
*loose* means min is zero; *unbounded* means max is infinity.
→ [constraints and layout](../part-01-foundations/constraints-and-layout.md)

**Relayout / repaint boundary** — A point where the framework can stop propagating a layout or
paint invalidation, keeping the work local.

**Raster thread** — The thread that turns the layer tree into GPU commands. Renamed from "GPU
thread" in Flutter 2.5. Its performance problems have different fixes from the UI thread's.
→ [rendering pipeline](../part-01-foundations/rendering-pipeline.md)

**Impeller** — Flutter's rendering backend, which compiles shaders ahead of time and removes
shader jank. Default on iOS since 3.10 and on Android since 3.29.

**Sliver** — A scrollable area's protocol: takes `SliverConstraints`, returns `SliverGeometry`,
and builds only what is visible plus a cache window.

## Dart

**Isolate** — A unit of concurrency with its own heap and event loop. No shared memory;
communication is by copied messages. → [isolates](../part-01-foundations/dart-isolates.md)

**Event loop** — The loop that drains the microtask queue completely, then takes one item from
the event queue, forever.

**Microtask queue** — The high-priority queue holding `scheduleMicrotask`, `Future.microtask`,
and the continuation after every `await`.

**Event queue** — Timers, I/O completions, platform messages and frame callbacks. `Future(...)`
schedules here, not on the microtask queue.

**Sound null safety** — Nullability in the type system with a guarantee the compiler can act on
at runtime. Escape hatches: `!`, `late`, `as`, and `dynamic`.

**Record** — An anonymous, immutable, structurally typed aggregate: `(1, 'a')` or
`(id: 1, name: 'a')`.

**Sealed class** — A class whose subtypes are all known to the compiler, enabling exhaustive
`switch`.

**Mixin** — Reusable behaviour applied to a class in a linearised chain, without becoming its
supertype.

**Extension method** — A statically resolved member added to a type you do not own. Cannot be
overridden, and does not dispatch dynamically.

**Covariance** — `List<Card>` is a `List<PaymentMethod>`. Sound for reads, unsound for writes,
checked at runtime.

## Architecture

**Entity** — A domain object shaped by the app's rules, non-null wherever the app requires a
value. → [Clean Architecture](../part-02-professional/clean-architecture.md)

**DTO** — A data transfer object shaped by the wire, nullable wherever the server can omit a
field. Often called a "model", ambiguously.

**Mapper** — The code converting a DTO to an entity, and the one place a broken payload becomes
a typed failure.

**Repository** — The interface the domain declares and the data layer implements. The seam
between what the app needs and where it comes from.

**Use case** — One verb with its own rule, orchestrating repositories. Not worth writing when it
forwards a single call.

**Composition root** — The single place that constructs the object graph, usually `main`.

**Service locator** — A registry objects pull dependencies from, such as `get_it`. Contrast with
constructor injection, where dependencies are pushed in.

**Feature-first** — Organising code by user-facing capability rather than by kind of code.

## Data and networking

**Outbox** — A durable, ordered queue of pending writes, enqueued in the same transaction as the
local change. → [offline first](../part-03-data/offline-first.md)

**Idempotency key** — A client-generated identifier the server deduplicates on, which makes a
retried write safe.

**Optimistic update** — Applying a change locally before the server confirms, with a rollback
path if it fails.

**Stale-while-revalidate** — Serve the cache immediately, refresh in the background, update when
it lands.

**Delta sync** — Fetching only what changed since a cursor, including tombstones.

**Tombstone** — A record marking a deletion, so other devices learn about it.

**Cursor pagination** — Requesting "the page after this item" rather than an offset. Stable when
the underlying list changes.

**ETag** — A version identifier the server returns and the client sends back, allowing a
`304 Not Modified` with no body.

**Backoff and jitter** — Exponentially increasing retry delays, randomised so clients do not
retry in lockstep.

**Single-flight** — Collapsing concurrent identical requests — typically a token refresh — into
one shared future.

**WAL** — Write-ahead logging in SQLite: readers no longer block on the writer.

## Production

**Flavor / scheme** — A build variant with its own application id, name and configuration.
Flavors on Android, schemes on iOS. → [flavors](../part-04-production/ci-flavors.md)

**`--dart-define`** — Compile-time constants passed at build time. Configuration, never secrets.

**Obfuscation** — Renaming Dart symbols in the AOT snapshot, with a symbol file archived for
symbolication.

**Symbolication** — Turning an obfuscated stack trace back into readable names using the
archived symbol file.

**R8 / ProGuard** — Android's shrinker and obfuscator for Java and Kotlin. Needs keep rules for
anything reached by reflection.

**Staged rollout** — Releasing to a growing percentage of users, with the ability to halt. On
mobile, the rollout percentage is the rollback.

**Certificate pinning** — Rejecting TLS chains that do not match a compiled-in value. Requires
two pins, a kill switch and a rotation plan.

**Attestation** — A platform-signed verdict about the device and app, verified server-side: Play
Integrity and App Attest.

**Feature flag** — A remotely controlled switch, and the only instant remedy a shipped mobile
release has.

**Frame budget** — The time available per frame: 16.7 ms at 60 Hz, 8.3 ms at 120 Hz.

**Jank** — A frame that missed its budget, visible as a stutter.

**ANR** — Application Not Responding: on Android, the main thread blocked long enough for the
system to notice.

## Process

**ADR** — Architecture Decision Record: a short document capturing a decision, its context and
its consequences. → [team workflow](../part-05-enterprise/team-workflow.md)

**Trunk-based development** — Short-lived branches merged frequently into one main branch, with
feature flags hiding incomplete work.

**Conventional Commits** — A commit message format (`feat:`, `fix:`, `docs:`) machines can read
to generate changelogs and version bumps.

**Melos** — A tool for managing a Dart or Flutter monorepo: bootstrapping, scripting and
versioning across packages.

**Story point** — A relative measure of complexity, not a unit of time.

**Definition of done** — The written agreement on what "finished" means: tested, reviewed,
documented, flagged if risky.
