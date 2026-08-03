# Team workflow

Branching, review, decisions and onboarding — the conventions that stop a large team from
spending its time on process arguments.

## The recommendation

**Trunk-based development with short-lived branches, feature flags for anything unfinished,
and a review standard written down.** The dominant cost on a large team is not writing code,
it is coordination: merge conflicts, waiting for review, and re-litigating decisions somebody
already made. Every convention here targets one of those three.

## Branching

**Trunk-based, and it is the default for a reason.** Short-lived branches off `main`, merged
within a day or two, with anything incomplete hidden behind a flag.

```bash
git switch -c feat/order-filters main
# ... work, small commits ...
git push -u origin feat/order-filters
# open a PR, review, squash merge
```

The alternative — long-lived develop, release and feature branches — is what this repository
itself uses, because a handbook releases in coherent chapters rather than continuously. That
is the honest test for which model fits: **release cadence**. Continuous delivery wants trunk;
scheduled releases with a stabilisation period want release branches.

What matters more than the model:

- **A branch older than two days is a merge conflict being written.** Split the work.
- **Feature flags let an unfinished feature merge.** Merging beats a branch that diverges, and
  the flag is also the [rollback plan](../part-04-production/release-process.md).
- **`main` is always releasable.** Protected, PR-only, CI green before merge.

## Merge versus rebase

Both are correct; disagreement is expensive, so decide once:

| | Merge | Rebase |
| --- | --- | --- |
| History | True, with the branch topology | Linear, as if written in sequence |
| Conflicts | Once, at merge | Possibly once per commit |
| Safe on shared branches | Yes | **No** — it rewrites history others have |
| Debugging with `bisect` | Noisier | Cleaner |

The convention that works on most teams: **rebase your own branch onto `main` to stay
current, squash-merge into `main`.** You get a linear history, one commit per PR, and nobody
ever rebases a branch someone else has pulled.

The absolute rule: **never rebase a branch other people are working on.** It rewrites commits
they have, and recovering is manual for everyone.

## Commits and PRs

**Conventional Commits**, because they are machine-readable and drive changelogs and version
bumps:

```text
feat(orders): add status filter to the order list
fix(auth): refresh the token before it expires rather than after
docs(readme): document the flavour setup
refactor(cart): extract the total calculation into the domain
```

**Small PRs.** Review quality falls off a cliff with size — a 200-line PR gets real comments,
a 2,000-line PR gets "LGTM". If a change is genuinely large, split it: refactor first, feature
second, in two PRs.

A PR description that answers three questions saves a reviewer ten minutes: **what changed**,
**why**, and **how it was verified**. A template makes it automatic.

## Code review standards

Write these down, because otherwise every reviewer applies their own and authors cannot
predict the outcome.

**A reviewer must check:**

- Correctness, especially error and empty paths.
- Tests for the behaviour, at the right level.
- Naming and public API — the hardest things to change later.
- Whether it fits the existing architecture, or knowingly departs from it.
- Security and privacy where relevant: logged secrets, new permissions, PII.

**A reviewer must not:**

- Argue formatting. The formatter decides, in CI.
- Redesign the feature in review. That conversation belongs before the code was written.
- Block on preference. Distinguish "this is wrong" from "I would have done it differently" —
  and say which one you mean.

Two conventions that reduce friction more than they look like they should: **prefix
non-blocking comments** with `nit:` or `question:`, and **agree a first-response SLA** — say,
four working hours. A PR waiting a day is a context switch for the author and a merge conflict
waiting to happen.

## Architecture Decision Records

An ADR is a short document capturing a decision and why it was made. They exist because
without one, the same debate recurs every six months with new people.

```markdown
# ADR 012: Riverpod for state management

## Status
Accepted — 2026-03-14

## Context
Three features use Provider, two use setState. Async loading and error states are
hand-rolled and inconsistent. The team has grown from 4 to 11.

## Decision
Riverpod for all new features. Existing Provider code migrates opportunistically.

## Consequences
+ Compile-time safety; AsyncValue removes hand-rolled loading/error states
+ Overrides make testing without a network straightforward
- A learning curve of roughly a week per engineer
- Two approaches coexist during migration
```

Keep them in `docs/adr/`, numbered, immutable once accepted. A superseded decision gets a new
ADR that references the old one rather than an edit — the record of what you believed at the
time is the point.

Write one for anything expensive to reverse: state management, local database, navigation,
modularization, a major dependency.

## Onboarding

The measurable goal: **a new engineer ships something real in their first week.** Two things
achieve it.

**A README that works.** Clone, one setup command, run. If setup takes a day, that is a
recurring cost paid by every hire, and it is usually fixable in an afternoon.

**A starter task that touches the whole stack.** A small feature crossing UI, state, data and
tests teaches the architecture faster than any document — and their questions are the best
list of what the documentation is missing.

Supporting material, in order of value: an architecture overview with the layer diagram, the
ADR index, the review standards, and a named buddy for the first two weeks.

## Working with Agile in practice

The parts that actually affect an engineering team:

- **Story points measure relative complexity, not hours.** The moment they are converted to
  hours they stop being useful and start being a commitment nobody made.
- **Standup is for blockers and coordination.** A status report to a manager can be written
  down instead, and asynchronous updates are better for distributed teams.
- **Retrospectives need one owned action item.** A retro that produces a list nobody owns
  trains people to stop raising things.
- **Sprint scope should include maintenance.** A team at 100% feature allocation accumulates
  technical debt at a predictable rate and then delivers a rewrite proposal in a year.
- **Definition of done, written down**: tested, reviewed, documented, behind a flag if risky,
  release notes if user-visible.

## Managing technical debt

Make it visible rather than moral. Track it as work items with a stated cost — "this doubles
the time for any change to checkout" — and reserve capacity for it, typically 15–20% of a
sprint.

The rule that keeps it from accumulating invisibly: **debt taken deliberately gets a ticket
and a date at the moment it is taken.** Debt discovered later gets a ticket when discovered.
What does not work is a "tech debt sprint" scheduled someday, which never survives contact
with a roadmap.

## Interview angles

**"Explain Git Flow."** Long-lived `develop` and `main`, plus feature, release and hotfix
branches. Then the judgement: it fits scheduled releases and is heavy for continuous delivery,
where trunk-based with feature flags is a better match. Naming the tradeoff is the answer.

**"Merge versus rebase?"** Merge preserves true history and resolves conflicts once; rebase
produces linear history and must never be used on a shared branch. The common convention is
rebase locally, squash-merge to main.

**"How do you manage 100 developers on one codebase?"** Package boundaries with CODEOWNERS,
trunk-based development with short branches and feature flags, a written review standard with
an SLA, ADRs so decisions are not re-litigated, and CI fast enough that people do not route
around it.

**"How do you handle a disagreement in review?"** Distinguish correctness from preference, say
which you mean, and escalate a genuine architectural disagreement to a decision with an ADR
rather than settling it in comment threads.

**"How do you handle technical debt?"** Track it as work with a stated cost, reserve capacity
every sprint, and ticket deliberate debt at the moment it is taken.

## See also

- [Modularization](modularization.md) — boundaries that make ownership real
- [Observability](observability.md) — feature flags for unfinished work
- [Release process](../part-04-production/release-process.md) — release trains and rollout
- [Behavioural interview](../part-06-interviews/hr-round.md) — talking about all of this
