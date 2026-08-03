# Dart language essentials

The parts of Dart that change how Flutter code is written: what `const` buys you, how
records and patterns replace a category of boilerplate, and why a mixin is not just
another word for inheritance.

Written against Dart 3.5. Records, patterns and class modifiers are Dart 3 features and do
not compile on Dart 2.

## The recommendation

Default to `const` for values, `final` for locals, and sealed class hierarchies plus
`switch` for anything with a fixed set of cases. Reach for `late` only when a value is
genuinely initialised after construction and you can name the moment it happens; every
other use of `late` is a runtime error you have moved out of the compiler's reach.

## Variables: const, final, late

Four ways to declare a value, each telling the reader something different.

| Declaration | Fixed at | Reassignable | Use for |
| --- | --- | --- | --- |
| `const x = 1` | Compile time | No | Literals, canonicalised widget subtrees |
| `final x = f()` | First assignment | No | Almost every local and field |
| `var x = 1` | Runtime | Yes | Values that genuinely change |
| `late final x` | First read | Once | Fields that need `this`, or expensive init |

`const` is not "a stronger `final`". It is *canonicalisation*: two `const` values with the
same type and arguments are the same object at runtime.

```dart
const a = Duration(seconds: 1);
const b = Duration(seconds: 1);
assert(identical(a, b)); // true — one object, created at compile time

final c = Duration(seconds: 1);
final d = Duration(seconds: 1);
assert(!identical(c, d)); // two objects
```

That identity is what makes `const` widgets cheap: when Flutter diffs a widget against the
previous frame, an identical instance short-circuits the comparison and the subtree is
skipped. The mechanism is in [the three trees](flutter-three-trees.md); the measured effect
is in [rendering performance](../part-04-production/performance-rendering.md).

`final` prevents reassignment of the *binding*, not mutation of the object.

```dart
final items = <String>['a'];
items.add('b');       // fine — the list is mutable
items = <String>[];   // compile error — the binding is not
```

For a genuinely immutable collection, use a `const` literal or `List.unmodifiable`. Both
throw on modification rather than silently corrupting state shared across a screen.

### late

`late` moves a null check from compile time to runtime. It has three honest uses:

```dart
class _ProfilePageState extends State<ProfilePage> {
  // 1. Needs `this` or `widget`, which do not exist in the initialiser list.
  late final Future<User> _user = context.read<UserRepository>().load(widget.id);

  // 2. Expensive and possibly unused — `late` makes it lazy, computed on first read.
  late final Uint8List _thumbnail = _decode(widget.bytes);

  // 3. Assigned in initState, non-null for the rest of the State's life.
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }
}
```

!!! warning "`late` without `final` is a footgun"
    `late int x;` can be read before it is assigned, and the failure is a
    `LateInitializationError` at runtime — on a user's device, not in your analyzer. The
    stack trace points at the read, not at the missing write. If you cannot name the exact
    moment the value is set, make the field nullable and handle the null.

**The cost:** every `late` field carries a hidden initialisation check on every read, and
it converts a compile-time guarantee into a crash you have to reproduce.

## Functions and closures

Dart closures capture *variables*, not values, but each loop iteration gets a fresh
binding — so the classic JavaScript loop bug does not reproduce:

```dart
final callbacks = <void Function()>[];
for (var i = 0; i < 3; i++) {
  callbacks.add(() => i); // each closure captures its own `i`
}
// callbacks.map((f) => f()) => (0, 1, 2)
```

What does bite in Flutter is capturing something long-lived by accident:

```dart
// Leak: the timer holds the closure, the closure holds `this`, and `this` holds the
// element and its whole subtree. The State cannot be collected until the timer is
// cancelled — and nothing here ever cancels it.
Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
```

Every closure handed to something longer-lived than the widget — a timer, a stream, a
singleton, a platform callback — is a reference you must release in `dispose`. See
[memory](../part-04-production/performance-memory.md).

The parameter style is API design, not taste:

```dart
// Positional: order matters, and it stops being readable past two arguments.
void moveTo(double x, double y);

// Named: self-documenting at the call site, reorderable, individually optional.
void showBanner({required String message, Duration? duration, bool dismissible = true});
```

Use named parameters for anything a caller could get wrong by position. Flutter's own APIs
do this consistently and matching that convention costs nothing.

## Classes, abstract classes and interfaces

Dart has no `interface` keyword because **every class is implicitly an interface**. Any
class can be `implement`ed, which forces the implementer to supply every member and
inherits no code at all.

```dart
class Logger {
  void log(String message) => debugPrint(message);
}

// Extends: inherits the implementation.
class TimestampLogger extends Logger {
  @override
  void log(String message) => super.log('${DateTime.now()}: $message');
}

// Implements: inherits nothing, must supply everything.
class SilentLogger implements Logger {
  @override
  void log(String message) {}
}
```

Dart 3 added class modifiers so a library author can state what is allowed:

| Modifier | Meaning | Use when |
| --- | --- | --- |
| `abstract` | Cannot be instantiated | The base defines contract, not behaviour |
| `base` | Can be extended, not implemented | Subtypes must inherit your invariants |
| `interface` | Can be implemented, not extended | You publish a contract, not a base class |
| `final` | Neither extended nor implemented | You want freedom to add members later |
| `sealed` | Implicitly abstract, subtypes known | Exhaustive `switch` over a fixed set |

`sealed` is the one that changes daily code. Because the compiler knows every subtype, a
`switch` over a sealed type is checked for exhaustiveness — add a case to the hierarchy and
every `switch` that does not handle it fails to compile, across every file, at build time.

```dart
sealed class PaymentMethod {}

final class Card extends PaymentMethod {
  const Card(this.last4);
  final String last4;
}

final class Cash extends PaymentMethod {
  const Cash();
}

String describe(PaymentMethod method) => switch (method) {
      Card(:final last4) => 'Card ending $last4',
      Cash() => 'Cash',
      // No default clause. Adding `final class Wallet extends PaymentMethod {}`
      // breaks this switch at compile time, which is the entire point.
    };
```

The same mechanism gives you a failure type the compiler can see:

```dart
--8<-- "dart/result.dart"
```

## Mixins

A mixin adds behaviour to a class without becoming its supertype. Use one when the
behaviour is orthogonal to the class hierarchy — `WidgetsBindingObserver`,
`SingleTickerProviderStateMixin` and `ChangeNotifier` are all mixins for that reason.

```dart
mixin Retryable {
  int get maxAttempts => 3;

  Future<T> withRetry<T>(Future<T> Function() action) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } on Object {
        if (attempt >= maxAttempts) rethrow;
      }
    }
  }
}

class UserApi with Retryable {
  // Gains withRetry without UserApi having to sit somewhere in a hierarchy.
}
```

**Mixin versus inheritance**, stated the way it is worth saying out loud:

- **Inheritance** answers *what is this*. You get one superclass and it defines identity.
- **Mixins** answer *what can this do*. You get many, applied in order, each layered onto
  the class in a linearised chain.

The linearisation matters. In `class A extends B with M1, M2`, `M1` is applied on top of
`B` and `M2` on top of that, so `super` inside `M2` reaches `M1`, not `B`. Two mixins that
override the same method is where mixin bugs live — keep them non-overlapping.

Constrain a mixin with `on` when it depends on its host:

```dart
mixin LoggingState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState(); // `on State<T>` is what makes this super call legal
    debugPrint('$runtimeType mounted');
  }
}
```

**The cost:** mixins make a class's real behaviour non-local. Three mixins deep, answering
"where does this method come from" needs an IDE. Prefer composition — a field holding a
collaborator — unless the behaviour has to hook into the host's own lifecycle.

## Extension methods

Extensions add methods to a type you do not own, resolved **statically**.

```dart
extension StringCasing on String {
  String get titleCase => split(' ')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

'flutter engineering'.titleCase; // 'Flutter Engineering'
```

Static resolution is the whole story, and every limitation follows from it:

- The member is chosen by the **static type** of the expression, not the runtime type. An
  extension on `String` does not apply to a variable declared as `Object`.
- Extensions cannot be overridden, cannot add fields, and do not show up in `is` checks.
- A real instance method always wins. If the SDK later adds a method with your extension's
  name, your code silently starts calling theirs.

**Use them for** call-site ergonomics on types you cannot change: `context.colors`,
`duration.humanised`, `list.partition(...)`.

**Do not use them for** domain behaviour on your own types. If you own the class, put the
method in the class, where a reader will look for it.

## Generics and variance

Dart generics are reified: `List<String>` still knows it is a `List<String>` at runtime, so
`is List<String>` works — unlike Java's erasure.

They are also **covariant**: `List<Card>` is a subtype of `List<PaymentMethod>` because
`Card` is a subtype of `PaymentMethod`. That is convenient for reading and unsound for
writing, which Dart accepts deliberately and checks at runtime:

```dart
final List<Card> cards = <Card>[Card('4242')];
final List<PaymentMethod> methods = cards; // allowed — covariance
methods.add(const Cash());                 // TypeError at runtime
```

The rule worth memorising: **covariance is safe for output and unsafe for input.** A
`Repository<Card>` used as a `Repository<PaymentMethod>` is fine while you only read from
it, and a runtime error the first time you write.

Constrain type parameters when the code needs a capability rather than just a name:

```dart
abstract interface class Identifiable {
  String get id;
}

class InMemoryStore<T extends Identifiable> {
  final Map<String, T> _byId = <String, T>{};

  void put(T item) => _byId[item.id] = item; // `.id` needs the bound above
  T? get(String id) => _byId[id];
}
```

`covariant` on a parameter is the escape hatch for narrowing an override's parameter type.
It moves a check to runtime, so use it where the framework does — `RenderObject`
hierarchies — and be suspicious of it anywhere else.

## Enums

Dart enums are full classes: fields, methods, interfaces, const constructors.

```dart
enum Environment {
  dev('https://api.dev.example.com', Duration(seconds: 30)),
  staging('https://api.staging.example.com', Duration(seconds: 15)),
  prod('https://api.example.com', Duration(seconds: 10));

  const Environment(this.baseUrl, this.timeout);

  final String baseUrl;
  final Duration timeout;

  bool get allowsSelfSignedCerts => this != Environment.prod;
}
```

A `switch` over an enum is exhaustive, so adding a value breaks every switch that does not
handle it — the same safety as a sealed class without the ceremony. Use an enum when the
cases carry no per-instance data, and a sealed class when they do.

`values`, `name` and `byName` cover serialisation:

```dart
Environment.prod.name;              // 'prod'
Environment.values.byName('prod');  // Environment.prod — throws if unknown
```

Wrap `byName` when parsing untrusted input. An unknown string from a server should produce
a fallback or a typed failure, not an `ArgumentError` thrown from your data layer.

## Records and pattern matching

Records are anonymous, immutable, structurally typed aggregates. They remove the two worst
workarounds in Dart 2: returning a `List<dynamic>`, and declaring a class whose only job is
to return two values.

```dart
(double, double) minMax(List<double> values) {
  var min = values.first;
  var max = values.first;
  for (final value in values) {
    if (value < min) min = value;
    if (value > max) max = value;
  }
  return (min, max);
}

final (min, max) = minMax(samples); // destructured at the call site
```

Named fields make a record self-documenting without a class:

```dart
({String id, int unread}) summarise(Chat chat) =>
    (id: chat.id, unread: chat.messages.where((m) => !m.read).length);
```

Records compare by value, which makes them usable as map keys and as `distinct()` inputs.

**When not to use one:** anything that crosses a layer boundary or outlives a function. A
record has no name, so it cannot carry documentation, validation, or meaning in a
signature. Domain concepts deserve classes — see
[Clean Architecture](../part-02-professional/clean-architecture.md).

### Patterns

Patterns destructure and match in `switch`, in `if-case`, and in assignments.

```dart
// Switch expression with guards and destructuring.
String shipping(Order order) => switch (order) {
      Order(total: > 100) => 'free',
      Order(destination: 'domestic', :final weight) when weight < 2 => 'standard',
      Order(destination: 'domestic') => 'freight',
      _ => 'international',
    };

// if-case: match and bind in one step.
if (response case {'data': {'user': final Map<String, Object?> user}}) {
  // `user` is bound, typed, and in scope only inside this branch.
}

// List patterns, including a rest element.
switch (segments) {
  case ['users', final id]:           openUser(id);
  case ['orders', final id, 'items']: openOrderItems(id);
  case ['settings', ...final rest]:   openSettings(rest);
}
```

Sealed classes, exhaustive switches and destructuring together are why Dart 3 state
modelling is worth adopting: a union type stops needing a hand-written `when(...)` helper,
because the language provides one.

## Collections

Three things worth internalising.

**Map literals are `LinkedHashMap`.** Iteration follows insertion order, guaranteed. That
one fact turns an LRU cache into twenty lines instead of a hand-rolled linked list:

```dart
--8<-- "dart/lru_cache.dart"
```

**Iterables are lazy; lists are not.** `map`, `where` and `expand` build a description of
work rather than a result. Nothing runs until you iterate, and it runs *again* on the next
iteration:

```dart
final expensive = users.map(decode);        // nothing has run yet
expensive.length;                           // decodes every user
expensive.first;                            // decodes the first one a second time
final decoded = users.map(decode).toList(); // run once, keep the result
```

Call `toList()` at the point where you stop transforming and start reading more than once.
Leave it out while you are still chaining, or you allocate a list per step.

**Collection-if and spread beat imperative building.** They keep widget lists declarative
and `const`-friendly:

```dart
Column(
  children: [
    const Header(),
    if (user.isAdmin) const AdminPanel(),
    ...orders.map(OrderTile.new),
    if (hasMore) const LoadMoreButton() else const EndOfList(),
  ],
)
```

## Interview angles

**"Difference between `const` and `final`?"** `final` is single assignment at runtime;
`const` is compile-time canonicalisation, so identical `const` values are literally the
same object. The follow-up is why it matters in Flutter: a `const` widget short-circuits
the rebuild diff.

**"What are extension methods?"** Statically resolved additions to a type you do not own.
Say "statically" — the interviewer is checking whether you know they do not dispatch
dynamically and cannot be overridden.

**"Mixin versus inheritance?"** Inheritance defines what something *is* and gives you one
superclass; mixins define what it *can do* and compose in a linearised chain. Name the
ordering rule and the `on` constraint.

**"Explain covariance."** Dart generics are covariant, which is sound for reads and unsound
for writes, and the unsoundness is caught at runtime. The
`List<Card>` → `List<PaymentMethod>` → `add(Cash())` example is the shortest complete
answer.

**"When would you use a record instead of a class?"** Inside a function, or across two
adjacent lines, where the shape is obvious and short-lived. Not across a layer boundary,
because a record carries no name, documentation, or validation.

## See also

- [Null safety](dart-null-safety.md) — soundness, and why `!` is a design smell
- [Async and concurrency](dart-async.md) — the event loop, futures, and streams
- [Error handling](../part-02-professional/error-handling.md) — where `Result` belongs
- [Clean Architecture](../part-02-professional/clean-architecture.md) — entities vs models
