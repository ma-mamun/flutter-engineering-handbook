# Cheatsheets

One-page references for the things you look up rather than read. No explanation — each one
links to the page that explains why.

- **[Widget lifecycle](widget-lifecycle.md)** — call order, what belongs in each callback, the
  dispose checklist, the `mounted` rule, and app lifecycle states.
- **[Testing](testing.md)** — which level to test at, finders, matchers, pump semantics,
  dependency injection, environment setup, and a flake checklist.
- **[Performance checklist](performance-checklist.md)** — what to check and in what order when a
  screen feels slow, starting with which thread is over budget.

## How to use them

Open the one that matches the problem, work down it in order, and follow the link when you need
the reasoning. The ordering in each is deliberate: the performance checklist puts "which thread"
first because nothing below it is worth doing until that is answered, and the lifecycle sheet
puts call order first because most mistakes are a callback used in the wrong place.
