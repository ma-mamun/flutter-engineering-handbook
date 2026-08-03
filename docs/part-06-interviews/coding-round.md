# Coding round

Live coding, take-homes, and the tasks that recur — with what the interviewer is actually
grading.

## The recommendation

**Narrate your reasoning and handle the edge cases out loud.** In a live round the code matters
less than whether the interviewer can follow your thinking. In a take-home the opposite is true:
nobody is watching, so structure, tests and a README carry the signal. Optimise for the format
you are in.

## The tasks that recur

Every one of these has a worked, tested implementation in `code/` in this repository, because
they are the same problems production apps actually contain.

### Debouncer and throttle

Asked constantly, because it separates people who have built a search field from people who
have not.

```dart
class Debouncer {
  Debouncer({required this.duration});
  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();          // the whole mechanism
    _timer = Timer(duration, action);
  }

  void dispose() => _timer?.cancel();
}
```

**What is being graded:** that you cancel the previous timer, that you expose a `dispose` — and
whether you volunteer the difference from throttle. Say it: debounce waits for quiet, throttle
runs immediately then ignores a window.
→ [async](../part-01-foundations/dart-async.md)

### LRU cache

```dart
class LruCache<K, V> {
  LruCache({required this.capacity});
  final int capacity;
  final Map<K, V> _entries = <K, V>{};   // LinkedHashMap: insertion-ordered

  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;               // move to most-recently-used
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);                // matters on update, not just insert
    _entries[key] = value;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
```

**What is being graded:** knowing a Dart map literal is a `LinkedHashMap` and using that instead
of hand-rolling a linked list, and removing before reinserting on *update* — the bug most
candidates ship.

### Retry with backoff

**What is being graded, in order:** that you do not retry a 404, that you add jitter, that you
notice a POST is not safe to retry blindly, and that you cap the delay. Most candidates produce
a fixed-delay loop; naming any two of those four is a strong signal.
→ [networking](../part-03-data/networking.md)

### Pagination and infinite scroll

**What is being graded:** the guard against concurrent loads (a fast scroll fires the callback
several times), keeping loaded pages when one fails, and prefetching before the user reaches the
bottom. Bonus: cursor over offset, and why.

### A generic repository

```dart
abstract interface class Repository<T, ID> {
  Future<Result<T>> byId(ID id);
  Future<Result<List<T>>> all();
  Future<Result<void>> save(T item);
}
```

**What is being graded:** whether the interface is in the domain and the implementation in the
data layer, whether failures are values or exceptions, and whether you mention caching policy
belonging here. Do not over-genericise — a repository with eleven type parameters is a negative
signal.

### Stream transformation

Search-as-you-type: debounce, distinct, cancel the in-flight request. **What is being graded:**
that you know `switchMap` cancels and `asyncExpand` does not, and that a stale response must
never overwrite a newer one.

### Offline sync

Usually a discussion rather than code. **What is being graded:** local-first writes, a durable
queue, client-generated ids for idempotency, and a stated conflict policy.
→ [offline first](../part-03-data/offline-first.md)

## Live coding: how to run the hour

1. **Restate the problem** and confirm the signature before typing.
2. **Ask about constraints** — size, concurrency, error handling. The answer changes the design,
   and asking is itself graded.
3. **Write the simplest correct version first.** A working simple solution beats an
   unfinished clever one, every time.
4. **Say what you are skipping and why.** "I would validate this input; skipping for now" is a
   sentence that earns credit.
5. **Test as you go**, out loud: empty, one element, capacity boundary, concurrent calls.
6. **Refactor when it works**, if there is time.

**Narrate.** Silence is unreadable. The interviewer is grading how you think, and they cannot
grade what they cannot hear.

If you get stuck, say what you are stuck on. Working through a hint well is a *positive* signal
in most rubrics; silent flailing is not.

## Take-home: what is actually graded

Nobody is watching you type, so the artefact is everything. In roughly the order interviewers
weight it:

1. **Does it run?** Clone, one command, works. A README with the exact commands.
2. **Structure.** Layers separated, dependencies injectable, no logic in widgets.
3. **Tests.** Not exhaustive — but the business logic tested, and the *error paths* tested. That
   last one is the strongest differentiator on a take-home.
4. **Error and empty states in the UI.** Most submissions handle only the happy path.
5. **A README that states your decisions.** What you chose, why, what you skipped and what you
   would do with more time. This can rescue an incomplete submission.
6. **Git history.** Small, meaningful commits show how you work.

Scope it deliberately. A take-home "estimated at four hours" that takes twenty is a bad signal
in both directions — build a smaller thing well, and write down what you left out.

## Debugging exercises

Increasingly common, and closer to the job than a puzzle. Typical prompts: a widget that does
not update, a `setState` after dispose crash, a leaking timer, a janky list, a
`RenderFlex overflowed`.

**The method to demonstrate:**

1. **Reproduce it**, reliably, and say what triggers it.
2. **Form a hypothesis** and say it out loud before testing it.
3. **Test the cheapest hypothesis first** — a print, a debug flag, a breakpoint.
4. **Change one thing.**
5. **Explain the mechanism**, not just the fix. "Adding `const` here made it faster" is weak;
   "the parent rebuilt, and without `const` the diff could not short-circuit" is the answer.

## Code review exercises

You are handed a file and asked what you would change. Reviewers are listening for **priority**
— can you tell a crash from a style preference?

Say them in this order:

1. **Correctness and crashes.** Context after an await, missing `dispose`, a swallowed error, an
   unguarded `!`.
2. **Architecture.** Business logic in the widget, an API call in `build`, a hidden dependency.
3. **Performance.** Rebuild scope, an unbounded list, a full-resolution image.
4. **Testing.** What is untested and would break silently.
5. **Style.** Last, briefly, and only if the formatter would not have caught it.

Leading with naming conventions on a file that leaks a controller is the failure mode.
→ [anti-patterns](../part-02-professional/anti-patterns.md)

## See also

- [Question bank](flutter-questions.md) — the verbal round
- [Mobile system design](system-design.md) — the design round
- [Anti-patterns](../part-02-professional/anti-patterns.md) — the review round's material
- [Async](../part-01-foundations/dart-async.md) — debounce, throttle, stream transforms
