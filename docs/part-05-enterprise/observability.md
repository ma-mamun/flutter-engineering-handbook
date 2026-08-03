# Observability

Knowing what the app does on devices you will never hold.

## The recommendation

**Crash reporting with symbolication, structured logging with no PII, a small analytics
schema you actually defined, and feature flags for anything risky.** In that order. A team
that can answer "how many users hit this and on which OS version" ships differently from one
that cannot, and the gap widens with codebase age.

## Crash reporting

The baseline, and the part that is usually half-configured:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const App());
}
```

Four things that separate a crash dashboard that helps from one that does not:

**Symbolication must work.** An obfuscated release produces hex without the symbol files, so
uploading them is a release-pipeline step, not a manual one. See
[obfuscation and hardening](../part-04-production/security-hardening.md).

**Context, attached before the crash.** The state that explains it:

```dart
FirebaseCrashlytics.instance
  ..setUserIdentifier(hashedUserId)          // hashed, never an email
  ..setCustomKey('flavor', AppConfig.env)
  ..setCustomKey('last_screen', route.name)
  ..log('checkout: submitting order');       // breadcrumbs, in the report
```

**Non-fatals matter as much as crashes.** A caught exception that leaves the user stuck is
invisible unless you record it. Report every `UnexpectedFailure` from your
[error taxonomy](../part-02-professional/error-handling.md).

**A verified pipeline.** Throw deliberately from a debug build, confirm the report arrives
symbolicated, and confirm it is attributed to the right release. A crash reporter nobody has
tested is a checkbox.

The number to watch is **crash-free sessions**, per release, compared with the previous
release's baseline. That comparison is what a staged rollout is halted on.

## Structured logging

`print` is not logging: it survives into release builds, has no levels, no structure, and no
destination.

```dart
final _log = Logger('orders.repository');

_log.info('order submitted', {'orderId': order.id, 'itemCount': order.items.length});
_log.warning('retrying after 503', {'attempt': 2});
_log.severe('checkout failed', error, stackTrace);
```

- **Levels with meaning.** `severe` pages someone; `warning` is worth investigating; `info` is
  a milestone; `fine` is debug detail. If everything is an error, nothing is.
- **Structured fields, not interpolated strings.** `{'orderId': id}` is queryable; `'order
  $id failed'` is a grep.
- **A logger per component**, named after it, so noisy areas can be turned down without
  turning everything down.
- **Different sinks per environment.** Console in debug; a remote sink at `warning` and above
  in release, sampled.

!!! warning "Never log a token, a password, or PII"
    Logs travel to third parties, sit in dashboards, and appear in support tickets. Redact at
    the logger, not at each call site — one place that strips known-sensitive keys is the only
    version that survives a new developer.

## Analytics

Analytics rots faster than any other code, because nothing breaks when it is wrong. Two
practices prevent it.

**Define the schema before implementing.** A table of event names, their properties, types and
meaning, agreed with whoever will use the data. Without it you get `button_click`,
`ButtonClick` and `btn_click` in the same dashboard.

```dart
// Events as types, not strings: a typo is a compile error, and the property
// names cannot drift between call sites.
sealed class AnalyticsEvent {
  const AnalyticsEvent();
  String get name;
  Map<String, Object?> get parameters;
}

final class CheckoutCompleted extends AnalyticsEvent {
  const CheckoutCompleted({required this.orderId, required this.totalCents});
  final String orderId;
  final int totalCents;

  @override
  String get name => 'checkout_completed';
  @override
  Map<String, Object?> get parameters =>
      {'order_id': orderId, 'total_cents': totalCents};
}
```

**Instrument outcomes, not clicks.** `checkout_completed` answers a question;
`button_tapped` does not. A small number of well-defined funnel events beats hundreds of UI
events nobody analyses — and every event costs privacy budget and review scrutiny.

Both stores require accurate privacy declarations, and adding an SDK that collects an
identifier changes what you must declare. That is a release-blocking detail worth catching
before submission.

## Feature flags

The single highest-value piece of production tooling, because it decouples deploying from
releasing and it is the only instant remedy in a
[mobile release](../part-04-production/release-process.md).

```dart
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.setDefaults({'new_checkout_enabled': false});
await remoteConfig.fetchAndActivate();

if (remoteConfig.getBool('new_checkout_enabled')) { ... }
```

Rules that keep flags from becoming the next problem:

- **Default to the safe value**, so a fetch failure or a cold start behaves like the old
  behaviour.
- **Fetch early and cache.** A flag read before the fetch completes returns the default; a
  screen that flickers between behaviours is worse than either.
- **Every flag has an owner and a removal date.** Flags outlive their features and turn into
  permanent untested branches — a flag older than two releases is technical debt with a
  ticket.
- **Test both paths.** A flagged-off path nobody tests is a path that breaks silently when
  turned on.
- **Kill switches are flags too.** For anything risky, ship the ability to turn it off before
  you ship the feature.

## Performance and business monitoring

Crashes are the floor, not the ceiling. Also worth watching per release:

- **Startup time**, cold and warm. It is what every user experiences.
- **Frame timings** on key screens, via
  [Firebase Performance](../part-04-production/performance-profiling.md) or custom traces.
- **Network success rate and latency by endpoint**, which catches backend regressions before
  support tickets do.
- **The funnels that make money.** A drop in checkout completion is a production incident even
  when nothing crashed — and it is the class of failure crash reporting never sees.

## What to do with all of it

Data nobody looks at is cost without benefit. The minimum that makes it worth collecting:

- **Alerts on a small number of things**: crash-free rate dropping below baseline, a spike in
  a specific error, a funnel falling more than a threshold. Too many alerts and people mute
  the channel.
- **A release dashboard** with crash-free rate, adoption, startup time and the key funnel,
  compared against the previous release.
- **Someone on call during a rollout** who knows the halt criteria.

## Interview angles

**"How do you know what your app is doing in production?"** Crash reporting with symbolication
and context, non-fatals for caught failures, structured logs without PII, a small defined
analytics schema, and performance traces on key screens. Then the operational half: alerts on
a few things and a release dashboard.

**"What do you monitor after a release?"** Crash-free sessions against the previous release,
ANRs, startup time, key funnels, adoption. With halt criteria agreed beforehand.

**"How do feature flags help?"** They decouple deploy from release, allow incomplete work to
merge, and give you the only instant remedy on mobile, where you cannot recall a build. Then
the cost: flags need owners and removal dates, or they become untested permanent branches.

**"How do you handle logging sensitive data?"** Redact at the logger, so it is one place
rather than every call site, and treat "no tokens, no PII in logs" as a review checklist item.

## See also

- [Error handling](../part-02-professional/error-handling.md) — the failures you report
- [Release process](../part-04-production/release-process.md) — halting on these metrics
- [Obfuscation and hardening](../part-04-production/security-hardening.md) — symbol upload
- [Team workflow](team-workflow.md) — flags for unfinished work
