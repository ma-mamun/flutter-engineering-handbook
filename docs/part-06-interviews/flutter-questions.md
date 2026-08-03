# Question bank

Questions grouped by level, each with what a strong answer contains.

Answers here are deliberately compressed, and every one links to the page that explains the
mechanism — because an answer you can only recite does not survive the follow-up.

## How to use this

Do not memorise the answers. Say each one out loud, then ask yourself "why is that true?" The
follow-up in a real interview is always the mechanism, and that is what separates a senior
answer from a well-read one.

## Junior: widgets, state, layout

**`StatelessWidget` versus `StatefulWidget`?**
Both are immutable configuration. `StatefulWidget` creates a `State` object held by the
*element*, which is why it survives rebuilds.
→ [three trees](../part-01-foundations/flutter-three-trees.md)

**What does `setState` do?**
Marks the element dirty and schedules a frame. It does not rebuild immediately, and ten calls
in one event produce one rebuild.
→ [rendering pipeline](../part-01-foundations/rendering-pipeline.md)

**`const` versus `final`?**
`final` is single assignment at runtime; `const` is compile-time canonicalisation, so identical
`const` values are the same object — which is what lets Flutter skip a subtree.
→ [language essentials](../part-01-foundations/dart-language-essentials.md)

**Why does my `Container(width: 100)` ignore its width?**
The parent passed tight constraints. Constraints go down, sizes go up; wrap in `Center` or
`Align` to loosen them.
→ [constraints and layout](../part-01-foundations/constraints-and-layout.md)

**What is a `Key` and when do you need one?**
An identity hint for element matching, needed when widgets of the same type change position
among siblings. `ValueKey` with a stable id by default.

**`ListView` versus `ListView.builder`?**
The first builds every child; the second builds only what is visible plus a cache window. Above
a screenful, always the builder.

## Mid: lifecycle, async, architecture

**Walk through the widget lifecycle.**
`createState → initState → didChangeDependencies → build`, then `didUpdateWidget` or
`didChangeDependencies` on changes, then `deactivate → dispose` — with `activate` if the
element is reinserted in the same frame.
→ [widget lifecycle](../part-01-foundations/widget-lifecycle.md)

**`initState` versus `didChangeDependencies`?**
`initState` runs once and cannot safely read inherited widgets; `didChangeDependencies` runs
after it and again on every dependency change, which is where `Theme.of` and `MediaQuery.of`
belong.

**Why is `BuildContext` dangerous after an `await`?**
It *is* an element, and the element can be unmounted while the future is in flight. Capture
what you need before the await, guard with `mounted` after it.

**Future versus Stream?**
One value versus many over time. The senior addition: a future is not cancellable and starts
eagerly; a single-subscription stream starts on listen, buffers until then, and can be
cancelled. → [async](../part-01-foundations/dart-async.md)

**Explain the event loop and the microtask queue.**
One thread, two queues; microtasks drain completely before a single event is taken. `Future(...)`
is an event — a zero-duration timer — while `Future.microtask` and the code after an `await`
are microtasks.

**`scheduleMicrotask` versus `Future()`?**
Different queues. The first runs before any timer this turn; the second runs after all pending
microtasks. Mention starvation: recursive microtasks block rendering while the app looks alive.

**Why use isolates?**
To move CPU-bound work off the UI isolate. Dart has no shared-memory threading, so isolates
trade shared state for message copying — parallelism without locks, paid for in copy cost.
→ [isolates](../part-01-foundations/dart-isolates.md)

**How does null safety prevent crashes?**
Nullability is in the type system and *sound*, so the compiler can prove a variable is non-null
and generate code that relies on it. Then name where it stops: `!`, `late`, `as`, and `dynamic`
at the JSON boundary.

**Why a repository?**
It is the seam: the domain states what it needs without knowing whether the answer comes from
HTTP, SQLite or a cache, and it is the one place the cache-versus-network policy can live.

**Entity versus DTO?**
An entity is shaped by the app's rules and non-null where the app requires a value; a DTO
mirrors the wire and is nullable wherever the server can omit a field. The mapper between them
is where a broken payload becomes a typed failure.

## Senior: internals, performance, tradeoffs

**Explain the rendering pipeline.**
Vsync → animation callbacks → build → layout → paint → compositing on the UI thread, then
rasterisation on the raster thread. That split is what the question is testing.

**Widget versus element versus render object?**
Immutable configuration; the mutable instance that holds `State` and decides update-or-replace;
the object that lays out, paints and hit-tests. Give the lifetimes.

**What is a `RepaintBoundary` and when does it hurt?**
It isolates a subtree into its own layer so repaints and moves are cheap. It hurts when
overused — each layer costs GPU memory and a compositing step.

**How does Flutter achieve 60 fps?**
Single-pass layout, relayout and repaint boundaries, retained layers, and a raster thread that
overlaps the next frame's UI work. Then be honest: it does not guarantee it, and the app's own
work is usually what breaks it.

**The app drops frames — what do you do?**
Reproduce in profile mode on a real device, record, and read which bar is long. UI-thread and
raster-thread problems share no fixes.
→ [profiling](../part-04-production/performance-profiling.md)

**How do you detect a memory leak?**
Snapshot, repeat the suspect cycle several times, GC, snapshot, diff, and read the retaining
path of the instances that should not exist. The retaining path is the answer.

**How do you refresh a JWT?**
Single-flight: the first 401 refreshes, everyone else awaits the same future, requests retry
with the new token, and a rejected refresh token signs the user out.
→ [networking](../part-03-data/networking.md)

**How would you retry failed requests?**
Exponential backoff with jitter, only on retryable statuses, only for idempotent methods or with
an idempotency key, honouring `Retry-After`. Every clause is a separate incident prevented.

**Explain SSL pinning.**
The app rejects certificate chains that do not match a compiled-in value, defeating an attacker
holding a trusted CA. Then the cost: an unplanned rotation bricks every installed copy, so it
needs two pins, a kill switch and rehearsed rotation.

**Why Riverpod, and why not GetX?**
Compile-time safety, no `BuildContext` requirement, `AsyncValue`, automatic disposal, and DI in
the same mechanism. Against GetX: globally reachable mutable singletons with no compile-time
seam, four frameworks in one dependency, and a small maintainership — stated as a tradeoff,
not a verdict.

**Cubit versus Bloc?**
Cubit exposes methods and is less code; Bloc turns actions into events, which buys
`BlocObserver` traceability and event transformers a Cubit cannot express.

**How do you avoid circular dependencies?**
Features never import each other; shared concepts move down into core; cross-feature needs are
inverted behind an interface or expressed as an event. Package boundaries make it a compile
error rather than a convention.

**Debug versus release builds?**
JIT with assertions versus AOT with tree shaking, obfuscation and R8 — and the consequence that
some bugs exist only in release, which is why a release build is smoke-tested before upload.

## Staff: design and leadership

**How would you migrate a 200k-line app off its current state management?**
Extract business logic out of widgets first — valuable regardless of the destination — then
migrate feature by feature behind repositories, with both approaches coexisting. Never a
big-bang branch, because it competes with the roadmap and loses.

**How do you manage 100 developers on one codebase?**
Package boundaries with CODEOWNERS so ownership is compiler-enforced, trunk-based development
with feature flags, written review standards with a response SLA, ADRs so decisions are not
re-litigated, and CI fast enough that nobody routes around it.
→ [team workflow](../part-05-enterprise/team-workflow.md)

**How do you decide whether to adopt a dependency?**
Maintenance and bus factor, how hard it is to leave, whether it can be wrapped behind an
interface, size cost measured with `--analyze-size`, and its effect on build time. Then write an
ADR.

**When is Clean Architecture the wrong choice?**
A prototype, a thin client over a stable API, a team of one or two, or any screen whose domain
logic is `if (list.isEmpty)`. The cost is files, mapping code and indirection, and it has to be
repaid by isolation you actually need.

**How do you release enterprise apps?**
Flavors per environment, signed artefacts from CI with archived symbols, staged rollout with
agreed halt criteria, feature flags for anything risky, and MDM or private distribution for
internal apps rather than a public listing.

**How do you handle technical debt?**
Track it as work with a stated cost, reserve capacity every sprint, and ticket deliberate debt
at the moment it is taken — not a someday tech-debt sprint, which never survives a roadmap.

## The answers people get wrong most often

Roughly ordered by how often the answer is memorised without the mechanism:

1. **`const` "for performance"** — without knowing that identity short-circuits the rebuild
   diff.
2. **"`setState` rebuilds the widget"** — it marks the element dirty and schedules a frame.
3. **"Isolates for async"** — conflating concurrency with parallelism.
4. **"Pinning makes the app secure"** — no cost named, no rotation plan.
5. **"We use Clean Architecture"** — no tradeoff, and use cases that forward a single call.
6. **"We aim for 100% coverage"** — as a goal rather than as a signal.

## See also

- [Coding round](coding-round.md) — the live and take-home tasks
- [Mobile system design](system-design.md) — the design round
- [HR round](hr-round.md) — the behavioural half
- [Part 1](../part-01-foundations/index.md) — where most of these answers are explained
