# Part 5 — Enterprise Flutter

What changes when there are forty engineers and a five-year horizon.

Nothing in this part is a different technology. It is the same Flutter, with the constraint
that **no single person can hold the codebase in their head** and that decisions made this
quarter will still be paid for in three years. That constraint changes which tradeoffs are
correct: indirection that is over-engineering on a two-person team is what makes a
forty-person team able to work in parallel.

## Pages

- **[Modularization](modularization.md)** — what actually justifies a package, monorepo layout
  and Melos, public APIs, versioning models, build times measured rather than assumed, and how
  to migrate a monolith without a doomed long-lived branch.
- **[Team workflow](team-workflow.md)** — branching models matched to release cadence, merge
  versus rebase, review standards written down, ADRs so decisions are not re-litigated,
  onboarding that produces a shipped change in week one, and technical debt tracked as work.
- **[Observability](observability.md)** — crash reporting with symbolication and context,
  structured logging without PII, an analytics schema defined before implementation, and
  feature flags as the only instant remedy a mobile release has.
- **[Design systems](design-systems.md)** — semantic tokens in `ThemeExtension`, a component
  package with no business logic, white labelling and where it goes wrong, versioning a shared
  dependency, and keeping design and code in sync.

## The four problems that only appear at size

**Coordination beats implementation as the dominant cost.** A feature takes a week to build
and three days to review, merge and release. Every convention in
[team workflow](team-workflow.md) targets those three days.

**Conventions decay unless a machine enforces them.** A dependency rule nobody checks is gone
within a quarter. That is the argument for [packages](modularization.md), a strict analyzer,
and golden tests.

**Nobody can see the whole system.** [Observability](observability.md) is how you learn what
the app does on devices you will never hold, and how you learn it before a support ticket
does.

**Decisions outlive the people who made them.** ADRs and a versioned
[design system](design-systems.md) are how a decision survives the engineer who made it
leaving.

## What does not change

Layering, state management, testing and performance work the same at forty engineers as at
four — the pages in Parts 2 to 4 apply unchanged. What changes is the cost of getting them
wrong: a bad boundary in a small codebase is an afternoon's refactor, and in a large one it is
a quarter's migration with six teams involved.
