# HR and behavioural round

Structured answers, levelling, and the compensation conversation.

## The recommendation

**Prepare six stories, not thirty answers.** Almost every behavioural question maps onto a
handful of real situations: a production incident, a technical disagreement, a decision you got
wrong, something you led, something you shipped under pressure, and something you mentored.
Learn the stories; adapt them to the question in the room.

## STAR, used properly

**Situation** (1–2 sentences) → **Task** (what was yours) → **Action** (what *you* did) →
**Result** (with a number where one exists).

The failure modes are consistent:

- **Too much situation.** Two minutes of context, twenty seconds of action. Invert it.
- **"We" everywhere.** The interviewer is hiring you, not your team. Say what you did.
- **No result.** "It went well" is not an outcome. "Crash-free sessions went from 97.2% to
  99.4% over two releases" is.
- **No reflection.** One sentence on what you would do differently earns more than a perfect
  outcome.

## The six stories to have ready

**1. A production incident you handled.**
The strongest story you have, if you have one. What broke, how you found it, what you did
first, and what changed afterwards so it could not recur. Interviewers listen for whether you
stopped the bleeding before diagnosing — halt the rollout, flip the flag, then investigate.

> "A token refresh race logged out roughly 8% of sessions after a release. Support tickets
> spiked before our alerts did. I halted the rollout at 10%, reproduced it by firing concurrent
> 401s in a test, and found five parallel refreshes invalidating each other's tokens. The fix
> was single-flight refresh — one in-flight future everyone awaits. Shipped in a patch within a
> day; logout rate returned to baseline. Afterwards I added the concurrency test and an alert on
> the logout rate, because the tickets should not have been our first signal."

**2. A technical disagreement.**
The trap is sounding either combative or spineless. What works: you disagreed, you tested the
disagreement against evidence, and you committed to the outcome either way.

> "A colleague wanted GetX for a new app; I argued for Riverpod. Rather than trading opinions,
> we each built the same screen in a day and compared testability and the migration path. His
> version was faster to write; mine could be tested without a widget tree, which mattered for
> our coverage requirement. We chose Riverpod and wrote an ADR. He was right that the learning
> curve cost us about a week."

**3. A failure that was yours.**
Pick a real one with a real cost, and own it without spiralling. Interviewers are testing
whether you can be honest about a mistake — a candidate with no failures is a candidate who has
not shipped or is not honest.

**4. Something you led.** A migration, a system, a team through a hard quarter. What you
decided, how you brought people with you, what you would do differently.

**5. Delivering under pressure.** What you cut, and how you decided. The right answer names a
tradeoff — scope reduced, quality bar held, or a stated exception with a follow-up ticket.

**6. Mentoring.** Someone specific, what changed for them, and what you learned about
explaining things.

## Common questions, and what they are really asking

**"Tell me about yourself."**
*Are you relevant and can you communicate?* Ninety seconds: what you do now, one or two things
you have built that match this role, and why you are in this conversation. Not your life story,
not a chronological CV reading.

**"Why are you leaving?"**
*Will you badmouth us next?* Frame it forward — what you are moving toward, not what you are
escaping. Never criticise a former employer, even accurately, especially accurately.

**"What is your biggest weakness?"**
*Are you self-aware?* A real one, with what you do about it. "I have shipped over-engineered
abstractions before; now I wait for the second real case before generalising."

**"Tell me about a conflict with a teammate."**
*Are you safe to work with?* Disagreement, evidence, resolution, and the relationship intact.

**"Where do you see yourself in five years?"**
*Is this role a step on your path or a stopgap?* Direction is enough — deeper technical scope,
or leading a team. Precision here helps nobody.

**"Why this company?"**
*Did you prepare?* One specific thing about their product or engineering, and how it connects to
what you want to do. The answer takes ten minutes of research and most candidates skip it.

## Levelling, by scope

Titles vary; scope is comparable. Know where you sit and where the role sits — a mismatch here
is the most common cause of a rejection that felt arbitrary.

| Level | Scope | Judged on |
| --- | --- | --- |
| Mid | A feature | Ships independently, writes tests, asks good questions |
| Senior | A system or a codebase area | Design decisions, unblocks others, names tradeoffs |
| Staff | Multiple teams or a technical direction | Influence without authority, choosing what not to build |
| Principal | Organisation-wide | Technical strategy, multi-year bets |

The senior-versus-mid line in practice: **a senior engineer is expected to say no**, to name
what a decision costs, and to be trusted with a problem rather than a task.

For a Flutter role specifically, senior means being able to answer *why* rather than *how* —
why the element tree exists, why pinning has an operational cost, why this state management
choice over that one — which is the material in Parts 1 to 5 of this handbook.

## Questions worth asking them

You are also evaluating them, and the questions you ask are themselves a signal.

**About the work:** What does the codebase look like — architecture, test coverage, technical
debt? What is the release cadence and how are rollouts managed? What broke most recently?

**About the team:** How are technical decisions made, and how are disagreements resolved? What
does code review look like? How long from a new hire's first day to their first production
change?

**About the role:** What would success look like in six months? Why is this role open? What is
the hardest problem the team has right now?

**Red flags in their answers:** no tests and no plan for them, "we move fast" as an answer to a
process question, everyone on call with no rotation, a codebase nobody wants to describe, and an
inability to say what success looks like.

## Compensation

- **Research first.** Levels.fyi, Glassdoor, and local salary surveys for your market and level.
  Regional variation is enormous; a number without a market attached is meaningless.
- **Let them go first where you can.** "I would like to understand the range for this level" is
  a complete and professional answer.
- **Negotiate the package, not just base.** Bonus, equity, notice period, remote arrangement,
  learning budget, and a review date are all negotiable, and some are easier for them to move
  than salary.
- **Get the offer in writing** before resigning anything.
- **Be prepared to walk.** The only real leverage, and the only way to negotiate without
  bluffing.

There is nothing adversarial about this conversation. You are agreeing a price for work, and
being straightforward about it is a professional trait, not a confrontational one.

## Mock interview: a full loop

The five rounds a Flutter loop typically contains, and where each is covered here:

| Round | Focus | Prepare with |
| --- | --- | --- |
| HR / recruiter | Motivation, level, compensation | This page |
| Flutter technical | Lifecycle, keys, state, streams, internals | [Question bank](flutter-questions.md) |
| Coding | Pagination, debounce, repository, cache | [Coding round](coding-round.md) |
| System design | Scalable app, offline sync, notifications | [System design](system-design.md) |
| Code review | Bottlenecks, architecture, testing strategy | [Anti-patterns](../part-02-professional/anti-patterns.md) |

Run them out loud, timed, with someone else if possible. The gap between knowing an answer and
saying it well is larger than anyone expects, and it closes only with practice.

## See also

- [Question bank](flutter-questions.md) — the technical round
- [Coding round](coding-round.md) — live coding and take-homes
- [Mobile system design](system-design.md) — the design round
- [Team workflow](../part-05-enterprise/team-workflow.md) — the material behind the stories
