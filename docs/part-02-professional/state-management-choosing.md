# Choosing a state management approach

A decision, made once, with the tradeoffs named — not a default inherited from a tutorial.

## The recommendation

**Keep state as local as it can be.** Most state is ephemeral and belongs in a `State`
object with `setState`. For shared, async, cached state, pick **Riverpod** for new work and
**BLoC** where the team already knows it or the domain is genuinely event-driven. Both are
defensible; what is not defensible is having three approaches in one codebase because nobody
decided.

## First: is this state shared at all?

The question that eliminates most of the debate.

| State | Lives in | Example |
| --- | --- | --- |
| **Ephemeral** — one widget, dies with it | `State` + `setState` | Form field text, whether a panel is expanded, animation progress, current tab |
| **Shared** — two or more screens need it | A state management approach | Signed-in user, cart contents, cached feed, feature flags |
| **Persisted** — must survive a restart | Database or preferences, *then* shared state | Draft messages, offline queue, settings |

A checkbox does not need a provider. Putting ephemeral state in a global store is the most
common over-engineering in Flutter apps: it adds indirection, makes the widget useless
without app-wide setup, and gains nothing.

The complementary mistake is a `setState` at the top of a page for something one child cares
about — that rebuilds the whole page every keystroke. The fix is scope, not a package:
`ValueListenableBuilder`, a smaller stateful widget, or a `const` subtree.

## The options

| | setState | Provider | Riverpod | BLoC / Cubit | signals |
| --- | --- | --- | --- | --- | --- |
| Boilerplate | None | Low | Low | Medium (Cubit) to high (Bloc) | Low |
| Compile-time safety | n/a | Runtime lookup by type | Typed providers | Typed | Typed |
| Works outside the widget tree | No | No — needs a `BuildContext` | Yes | Yes | Yes |
| Async/loading/error built in | No | No | Yes — `AsyncValue` | Manual states | Partial |
| Caching and disposal | Manual | Manual | Automatic | Manual | Manual |
| Testing | `pumpWidget` | `pumpWidget` + overrides | `ProviderContainer` | Plain unit test | Plain unit test |
| Team familiarity | Universal | High | Growing | High | Low |
| Right for | Ephemeral state | Simple DI + notifiers | Async app state, caching | Event-driven flows, audit trails | Fine-grained reactivity |

### Why Riverpod for new work

- **Compile-time safety.** `Provider.of<T>` fails at runtime when the provider is missing;
  a Riverpod provider is a typed object, so a missing dependency does not compile.
- **No `BuildContext` requirement.** Providers work in tests, background isolates, and
  services — `ProviderContainer` needs no widget tree.
- **`AsyncValue` is the loading/error/data union you would otherwise write by hand**, with
  the previous value retained during a refresh, which is what makes pull-to-refresh not
  flash a spinner.
- **Automatic caching and disposal.** `autoDispose` and families remove the
  `initState`/`dispose` pairing that leaks when someone forgets.
- **DI and state are the same mechanism**, so overriding a repository in a test is one line
  — see [dependency injection](dependency-injection.md).

**The cost:** a genuine concept load — `ref`, `watch` vs `read` vs `listen`, scopes,
families, `autoDispose`. Riverpod 3 also changed enough APIs that older tutorials mislead.
A developer new to it is slower for about a week.

### Why not Provider

Provider is not bad; it is *less*. It resolves by type at runtime through the widget tree,
so a missing provider is a runtime exception, it cannot be used outside a widget, and it
gives you no async story. If your app is already on Provider and working, migrating for its
own sake is not worth it. For new code, Riverpod is Provider's own author's replacement, and
that is the most honest argument available.

### Why not GetX

Worth stating plainly because it is popular and it does come up in interviews:

- **It is four frameworks in one** — state, DI, routing, and utilities — so adopting any
  part couples you to all of it, and replacing any part means replacing everything.
- **Global mutable singletons by default.** `Get.find()` reaches anywhere from anywhere,
  which is convenient in week one and untestable in month six: no compile-time seam, and
  tests that depend on registration order.
- **It routes without a `BuildContext`** by holding a global navigator key. That is genuinely
  convenient and it hides the lifecycle problems the framework's rules exist to prevent.
- **Sparse tests and a bus factor of roughly one**, against Riverpod and BLoC, which are
  heavily tested and have broad maintainership.

If you are on GetX and shipping, that is fine — this is a tradeoff, not a moral position.
But for a new codebase with a multi-year horizon, "everything is globally reachable" is the
property that hurts most, and it is the one thing GetX cannot be configured out of.

### When BLoC is the right answer

- The team already knows it. Familiarity is a real engineering constraint, not a weakness.
- The domain is genuinely event-driven — a checkout, a multi-step upload, a state machine
  with transitions you can draw.
- You want an audit trail. `BlocObserver` gives you every event and transition in one place,
  which is a debugging and analytics feature nothing else provides for free.
- You need **event transformers**: debounce, throttle, `restartable`, `sequential`,
  `droppable`. A Cubit cannot express "cancel the in-flight handler when a newer event
  arrives" — a Bloc does it in one line. That is the case where the ceremony pays for
  itself, and it is on the [BLoC page](state-management-bloc.md).

## Rules that outlive the choice

Whatever you pick, these determine whether the codebase stays workable:

1. **One approach per codebase.** Two is a migration; three is an accident.
2. **UI state and business state are different things.** "Is this dialog open" is UI state
   and belongs near the widget. "Is the order placed" is business state and belongs in the
   layer that can be tested without a widget.
3. **State objects hold no widgets and no `BuildContext`.** The moment one does, it cannot
   be unit tested and it will outlive a context.
4. **Every async state has loading, error and empty.** Model them; do not represent them as
   three loose booleans that can disagree.
5. **Rebuild scope is a design decision.** `select`, `buildWhen` and small builder widgets
   exist so a change to one field does not rebuild a page.

## Migration cost, honestly

If you inherit an app on the wrong approach, migrate at the boundary rather than all at
once:

- **setState → anything:** cheap and incremental, screen by screen.
- **Provider → Riverpod:** moderate. Both can coexist; migrate feature by feature, starting
  where the async pain is worst.
- **GetX → Riverpod/BLoC:** expensive, because GetX is also your router and DI. Replace it
  in that order: state first behind repositories, then DI, then routing last.
- **BLoC ↔ Riverpod:** moderate, and rarely worth it on its own. Do it only if you are
  already rewriting the layer for another reason.

The cost is dominated by how much business logic sits inside widgets. If it does, extract it
into repositories and plain Dart classes **first** — that refactor is valuable regardless of
which approach you end up with, and it makes the migration mechanical.

## Interview angles

**"Why Riverpod?"** Compile-time safety, no `BuildContext` dependency, `AsyncValue` for
loading and error states, automatic caching and disposal, and DI in the same mechanism. Then
the cost: a real learning curve and API churn between v2 and v3.

**"Why not Provider?"** Runtime type lookup, needs a widget tree, no async story. And the
strongest point: its author wrote Riverpod as its successor.

**"Why not GetX?"** Global mutable singletons with no compile-time seam, four frameworks
coupled into one dependency, and a small maintainership. Say it as a tradeoff — an
interviewer is testing whether you can criticise a tool without dogma.

**"Cubit versus Bloc?"** Cubit exposes methods and is less code; Bloc turns actions into
events, which buys traceability and event transformers. Use Cubit unless you need one of
those two things.

**"When should state be local?"** When exactly one widget cares and it dies with the widget.
Give examples — expansion state, form fields, animation values — and the reason: a provider
for a checkbox adds indirection and buys nothing.

**"How do you separate UI state from business state?"** Business state lives in a class with
no Flutter import and is tested without a widget; UI state lives next to the widget that
owns it. The test is the boundary: if it needs `pumpWidget`, it is UI state.

## See also

- [Riverpod](state-management-riverpod.md) — providers, `AsyncNotifier`, anti-patterns
- [BLoC](state-management-bloc.md) — Cubit versus Bloc and event transformers
- [Dependency injection](dependency-injection.md) — providers as a DI mechanism
- [Anti-patterns](anti-patterns.md) — what goes wrong regardless of the choice
