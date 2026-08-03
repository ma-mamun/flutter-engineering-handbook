# Part 6 — Interviews

Preparation material for Flutter roles, on both sides of the table.

This part is last on purpose. Interview preparation that is not built on the material in Parts
1 to 5 produces answers that collapse at the first follow-up — and the follow-up is always the
mechanism. Everything here links back to the page that explains why the answer is true.

## Pages

- **[Mobile system design](system-design.md)** — a six-step framework, the constraints that
  make mobile different, and five worked examples: chat, banking, ride sharing, offline POS,
  e-commerce.
- **[Coding round](coding-round.md)** — the tasks that recur and what each one is grading, how
  to run a live hour, what take-homes are actually scored on, and debugging and review
  exercises.
- **[Question bank](flutter-questions.md)** — questions by level with compressed answers and a
  link to the mechanism, plus the six answers people most often memorise without understanding.
- **[HR round](hr-round.md)** — six stories instead of thirty answers, levelling by scope,
  questions worth asking them, and compensation.

## What Flutter interviews actually test

Four things, in ascending order of how much they differentiate candidates:

1. **Framework knowledge.** Widgets, lifecycle, layout. Table stakes; nearly everyone passes.
2. **Mechanism.** *Why* the element tree exists, *why* `setState` schedules rather than
   rebuilds, *why* a `BuildContext` is dangerous after an await. This is where most mid-level
   candidates stop and most senior candidates are separated.
3. **Judgement.** Naming what a decision costs. "Clean Architecture, and here is what it charges
   in files and indirection" versus "we use Clean Architecture".
4. **Production experience.** Idempotency mentioned unprompted, staged rollouts, symbol files,
   what you cannot roll back. Impossible to fake and instantly recognisable.

## How to prepare

**Six weeks, roughly:**

1. **Weeks 1–2 — foundations.** [Part 1](../part-01-foundations/index.md), until you can explain
   the event loop ordering and the three trees without notes.
2. **Week 3 — architecture and state.** [Part 2](../part-02-professional/index.md). Be able to
   defend a state management choice against its alternatives.
3. **Week 4 — data and production.** [Part 3](../part-03-data/index.md) and
   [Part 4](../part-04-production/index.md). Offline sync, retries, profiling, release.
4. **Week 5 — practice out loud.** The [coding tasks](coding-round.md) on a timer, then
   [system design](system-design.md) prompts spoken, not written.
5. **Week 6 — behavioural and mocks.** Write the [six stories](hr-round.md), then run full
   loops with someone else.

The single highest-value habit: **say answers out loud**. The gap between knowing something and
explaining it under mild pressure is where most interviews are lost, and it closes only with
repetition.

## If you are the interviewer

- **Ask for mechanism, not recall.** "What does `const` do" is a search query. "Why does a
  `const` widget make a rebuild cheaper" is a question.
- **Give a real problem.** A debugging exercise or a code review predicts on-the-job performance
  better than a puzzle.
- **Let them ask questions.** What a candidate asks about your codebase tells you what they pay
  attention to.
- **Test judgement with tradeoffs.** "When would you *not* use this?" is the most informative
  question in a technical interview.
- **Do not grade recall of API names.** That is what documentation is for, and it selects for
  memory rather than engineering.
