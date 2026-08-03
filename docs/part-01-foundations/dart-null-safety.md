# Null safety

What sound null safety actually guarantees, what it does not, and how to write code that
does not need `!`.

## The recommendation

Treat every `!` as a claim you are making to the compiler that it could not verify. Some of
those claims are correct and worth making; most are a signal that the type is wrong, the
value should have been captured in a local, or the state should have been modelled as a
sealed class. Prefer, in order: **restructure the type**, then **narrow with a local**,
then `??` / `?.`, and only then `!`.

## What "sound" means

Non-sound null safety (TypeScript, Kotlin's platform types) means the compiler checks what
it can and trusts you elsewhere. Sound null safety means the compiler can *prove* a
non-nullable variable is never null — and the proof holds at runtime, so the compiler is
allowed to act on it.

That proof buys three things:

1. **No null dereference crashes** from code the analyzer accepts, except where you wrote
   `!` or `late`.
2. **Smaller, faster output.** The AOT compiler removes null checks it can prove are
   unnecessary, and tree-shakes branches that only existed to handle null.
3. **Signatures that carry information.** `User?` in a return type tells you the not-found
   case exists; `User` tells you it does not.

The cost is real and worth naming: soundness requires every dependency to be null safe, and
it forces you to decide what null means in places where you were previously vague. That
decision is work, and it is work the language will not let you defer.

## Flow analysis is doing more than you think

The analyzer promotes a nullable variable to non-nullable when it can prove the null case
was handled:

```dart
String describe(User? user) {
  if (user == null) return 'anonymous';
  return user.name; // promoted to User — no `!` needed
}
```

Promotion has two rules people trip over.

**It does not apply to fields**, because another isolate — or a getter, or any method call
in between — could change them:

```dart
class Profile {
  String? nickname;

  String greet() {
    if (nickname != null) {
      return 'Hi ${nickname.toUpperCase()}'; // compile error: not promoted
    }
    return 'Hi';
  }
}
```

The fix is a local, not a `!`:

```dart
String greet() {
  final name = nickname;           // capture once
  if (name == null) return 'Hi';
  return 'Hi ${name.toUpperCase()}'; // promoted, and immune to concurrent change
}
```

This pattern — copy the field into a `final` local, then check — is the single most useful
null safety habit to build. It also fixes a real race, not just an analyzer complaint: with
`!`, a field cleared between the check and the use crashes.

**It does not survive an `await` for fields** for the same reason, and the gap is wider
because anything can run in between. See
[BuildContext across an await](widget-lifecycle.md).

## The nullable toolkit

```dart
user?.address?.city              // null-aware access: null in, null out
user?.name ?? 'anonymous'        // fallback
settings.timeout ??= const Duration(seconds: 30) // assign only if currently null
names.map((n) => n?.trim()).whereType<String>()  // drop nulls, keep the type
list.firstWhereOrNull((u) => u.id == id)         // collection package, avoids throwing
```

`whereType<String>()` deserves a mention: it filters *and* changes the static type from
`Iterable<String?>` to `Iterable<String>` in one call, which is usually what you wanted
when you reached for a `!` inside a `map`.

## When `!` is legitimate

Three cases, all of which share one property: the invariant is enforced somewhere the
compiler cannot see, and you can point at where.

```dart
// 1. You just checked, in the same expression, and no await intervenes.
if (map.containsKey(key)) use(map[key]!);

// 2. A framework guarantee. `initState` runs before `build`, always.
late final AnimationController _controller;

// 3. A test asserting the thing exists — a crash here is the failure you want.
expect(find.byType(ListView), findsOneWidget);
final state = tester.state<MyState>(find.byType(MyWidget))!;
```

Everything else is worth restructuring. The most common offender in Flutter code:

```dart
// Before: three fields that must agree, and nothing enforces it.
class SearchState {
  bool isLoading;
  List<Result>? results;
  String? error;
}
// `state.results!.length` compiles. It also throws whenever isLoading is true.

// After: illegal combinations cannot be constructed.
sealed class SearchState {}
final class SearchLoading extends SearchState {}
final class SearchLoaded extends SearchState {
  const SearchLoaded(this.results);
  final List<Result> results;   // non-nullable, because in this state it exists
}
final class SearchFailed extends SearchState {
  const SearchFailed(this.message);
  final String message;
}
```

The second version needs no `!` anywhere, because `results` only exists in the state where
it is meaningful. That is the general move: **make the illegal state unrepresentable, and
the null checks disappear with it.**

## Required, optional, and nullable are three different things

```dart
void configure({
  required String host,      // must pass, cannot be null
  required String? region,   // must pass, may be null — "I explicitly have no region"
  int port = 443,            // optional, has a default
  Duration? timeout,         // optional, null means "use the caller's default"
})
```

`required String? region` looks odd until you need it: it forces the caller to make a
decision and record it, rather than silently getting a default. Use it for fields where
"not set" and "deliberately empty" mean different things — a nullable `dismissedAt`, an
optional middle name, a nullable foreign key.

## Nullable fields in models

Two rules keep a data layer honest:

**Nullability in a model mirrors the wire format, not your preference.** If the API can omit
`avatarUrl`, the DTO field is `String?`. Lying about it moves the crash from the parser
(where the payload is in scope and loggable) into a widget three screens away.

**The domain entity decides what null means, and the mapper enforces it.** A DTO with
`String? id` maps to an entity with `String id`, and the mapper throws a typed failure when
the id is missing. That way exactly one place knows the difference between "the server is
broken" and "this user has no avatar".

```dart
final class UserDto {
  const UserDto({required this.id, this.avatarUrl});
  final String? id;        // the wire allows it
  final String? avatarUrl; // genuinely optional

  User toEntity() {
    final id = this.id;
    if (id == null) {
      throw const FormatException('user.id missing'); // caught in the data layer
    }
    return User(id: id, avatarUrl: avatarUrl);
  }
}
```

## Migrating a legacy codebase

If you still have pre-null-safety code, migrate leaves first. A package cannot be sound
until everything it depends on is, so the dependency graph dictates the order.

1. `dart pub outdated --mode=null-safety` to see what is blocking you.
2. Upgrade dependencies until every one is migrated. Vendor or replace the one that never
   will be — that decision is usually the actual project.
3. `dart migrate` for a first pass, then **review every inserted `?` and `!`**. The tool is
   conservative: it produces code that compiles, not code that models your domain. Every
   `!` it inserts is a question it could not answer.
4. Fix the types the tool got wrong, working from the data layer outwards. A nullable field
   near the wire is usually correct; a nullable field in a widget usually is not.
5. Only then turn on the stricter analyzer settings.

Expect the migration to surface real bugs — fields that were sometimes null and never
handled. That is the point, and it is why a mechanical migration that leaves `!` everywhere
buys you nothing.

## How null safety prevents runtime crashes

Worth being precise here, because the honest answer is narrower than the marketing one.

Null safety eliminates one specific crash: dereferencing null on a variable the compiler
proved non-nullable. It does not prevent:

- `!` on a value that is null at runtime — you overrode the compiler.
- `LateInitializationError` — a `late` field read before assignment.
- A cast failure from `as`, or from an implicit downcast in a `dynamic` chain.
- JSON parsing that produces null where your type says otherwise, since `jsonDecode`
  returns `dynamic` and hands you whatever the server sent.

The last one is the leak in practice: null safety stops at the boundary where data becomes
`dynamic`. Parse into typed models at the edge and the guarantee holds inside; pass maps
around and it does not.

## Interview angles

**"How does null safety prevent runtime crashes?"** It makes nullability part of the type
system and *sound*, so the compiler can prove a non-nullable variable is never null and
generate code that relies on it. Then name the escape hatches — `!`, `late`, `as`, and
`dynamic` at the JSON boundary — because knowing where the guarantee stops is the senior
half of the answer.

**"Why is `!` a design smell?"** It is an assertion the compiler could not verify. Usually
it means the state model allows a combination that should not exist. Show the loading /
loaded / failed refactor.

**"What is the difference between `late` and nullable?"** `late` promises the value will
exist by first read and fails at runtime if it does not; nullable admits it might not and
makes every reader handle that. Choose `late` only where a framework guarantee — like
`initState` before `build` — backs the promise.

**"Why does promotion not work on fields?"** Because a field can change between the check
and the use — another method, a getter with side effects, an `await`. Copy to a `final`
local first.

## See also

- [Dart language essentials](dart-language-essentials.md) — sealed classes and `late`
- [Widget lifecycle](widget-lifecycle.md) — `mounted` and context after an await
- [Error handling](../part-02-professional/error-handling.md) — typed failures at the edge
- [Networking](../part-03-data/networking.md) — parsing at the boundary
