# Networking

HTTP clients, interceptors, retries and token refresh — the data layer where most
production bugs actually live.

## The recommendation

**dio, one configured instance, interceptors for cross-cutting concerns.** Set explicit
timeouts, map exceptions to a typed failure at the boundary, retry only what is safe to
retry, and refresh tokens exactly once no matter how many requests fail at the same moment.

## Choosing a client

| | `http` | `dio` | `chopper`/`retrofit` |
| --- | --- | --- | --- |
| Interceptors | No — wrap the client yourself | Yes, first class | Via the underlying client |
| Cancellation | `client.close()`, all-or-nothing | `CancelToken` per request | Depends |
| Timeouts | `.timeout()` per call | Connect, send and receive, configured once | Depends |
| Form data / upload progress | Manual | Built in | Built in |
| Weight | Minimal | Moderate | Generated code |

`http` is right for a package (fewer transitive dependencies for your users) and for an app
with a handful of calls. `dio` is right for an app: interceptors, per-request cancellation
and progress callbacks are all things you would otherwise write. `retrofit` generates a typed
client from annotations on top of dio — worth it past thirty endpoints, `build_runner` cost
below that.

## One configured client

```dart
Dio buildDio(Environment env, {required TokenRefresher auth}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.baseUrl,
      // All three matter. The default is no timeout, which means a request can
      // hang until the OS gives up — minutes on a bad mobile connection.
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      // Let non-2xx responses through so the error interceptor maps them,
      // rather than throwing before you can read the body.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(auth),
    RetryInterceptor(),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
    ErrorMappingInterceptor(),
  ]);

  return dio;
}
```

**Order is behaviour, not style.** Interceptors run in registration order for requests and in
reverse for responses, so the auth interceptor must come before the retry interceptor — the
retried request needs the refreshed token attached. Getting this backwards produces a retry
storm of 401s that looks like a server problem.

## How an interceptor works

Three hooks, and each one must call exactly one of `next`, `resolve` or `reject`:

```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._auth);
  final TokenRefresher _auth;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer ${await _auth.accessToken()}';
    }
    handler.next(options);          // continue the chain
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);     // not ours — pass it along
    }
    try {
      final used = err.requestOptions.headers['Authorization'] as String?;
      final token = await _auth.onUnauthorized(used?.replaceFirst('Bearer ', '') ?? '');
      final retried = await _retryWithToken(err.requestOptions, token);
      handler.resolve(retried);     // the caller never sees the 401
    } on RefreshFailure {
      handler.next(err);            // refresh is dead: let the 401 surface
    }
  }
}
```

Forgetting to call a handler method hangs the request forever with no error — the most
confusing failure mode dio has. Every code path in every hook ends in exactly one call.

## Token refresh, done once

The bug worth designing against: five requests fail with 401 at the same moment, all five
call the refresh endpoint, and on a backend that rotates refresh tokens the later ones
invalidate the token the earlier ones are using. The user is logged out for no reason, and
it only reproduces under concurrency.

```dart
--8<-- "networking/token_refresh.dart"
```

The mechanism is three lines: the first caller stores its refresh future in a field,
everyone else awaits that same future, and the field is cleared when it settles. Two details
that matter beyond that:

- **Compare the token the failed request used against the stored one.** If they differ,
  somebody already refreshed — just retry with the new one. This is the check that stops the
  second wave.
- **A rejected refresh token is terminal.** Clear storage and sign out. Retrying against a
  revoked token loops forever, and it is a common cause of battery complaints.

A test proves the single-flight property: five concurrent `onUnauthorized` calls produce
exactly one refresh call. Storage must be secure — see
[secure storage](../part-04-production/security-storage.md).

## Retry, correctly

```dart
--8<-- "networking/retry.dart"
```

Three rules, each of which is a real incident when broken:

**Retry only what a later attempt could fix.** 408, 429, 5xx and connection failures. Never
400, 401, 403, 404 or 422 — the server gave its final answer, and retrying wastes battery
and adds load.

**Never blindly retry a non-idempotent write.** A POST that timed out may well have been
processed; retrying charges the card twice. Either restrict retries to
GET/PUT/DELETE/HEAD/OPTIONS, or send an **idempotency key** the server deduplicates on. The
key is the real fix; the method check is the safe default.

**Jitter is not optional.** Without it, every client that failed during an outage retries at
the same instant and knocks the server over again as it recovers. The sample randomises
±30% by default, and honours `Retry-After` when the server sends one.

## Timeouts and cancellation

A timeout stops *waiting*; it does not stop the work. The request keeps running and the
response is discarded. To actually stop it, cancel:

```dart
final cancelToken = CancelToken();
ref.onDispose(cancelToken.cancel);      // the screen closed: stop the request

final response = await dio.get('/feed', cancelToken: cancelToken);
```

Cancel on `dispose`, and cancel the previous search request when a new keystroke arrives —
the `switchMap` behaviour from the [async page](../part-01-foundations/dart-async.md), at the
HTTP layer.

## Pagination

Offset pagination (`?page=3`) breaks whenever the list changes underneath: an item inserted
at the top shifts everything down, so page 3 repeats a row and skips another. Cursor
pagination asks for "the page after this item" and is stable under insertion.

```dart
--8<-- "networking/paginator.dart"
```

Four behaviours that hand-rolled pagination usually misses, and that the tests assert:

- **A concurrency guard.** A fast scroll fires "load more" several times before the first
  response lands; without the guard the same page is appended twice.
- **Deduplication by id.** An item that moved between pages appears twice, and a keyed list
  throws on the duplicate key.
- **A failed page keeps what was already loaded.** Page 3 failing must not blank pages 1 and
  2 — show a retry row at the bottom.
- **Prefetch on remaining pixels**, not on the last index being built. At ~200 px of runway
  the next page usually arrives before the user reaches the spinner.

## Serialisation

Parse into typed models at the boundary. `jsonDecode` returns `dynamic`, and every `dynamic`
that travels inward is a null-safety guarantee you have given up — see
[null safety](../part-01-foundations/dart-null-safety.md).

```dart
@JsonSerializable()
class OrderDto {
  const OrderDto({required this.id, this.note});
  factory OrderDto.fromJson(Map<String, Object?> json) => _$OrderDtoFromJson(json);

  final String? id;      // nullable because the wire allows it
  final String? note;
}
```

Two rules that prevent most parsing incidents: **DTO nullability mirrors the wire, not your
preference**, and **the mapper to the entity is the only place that decides what a missing
field means**. Both are on the [Clean Architecture page](../part-02-professional/clean-architecture.md).

For large payloads, move `jsonDecode` to an isolate — a 2 MB response routinely takes 100 ms
on a mid-range phone, which is six dropped frames. See
[isolates](../part-01-foundations/dart-isolates.md).

## Caching and ETags

The cheapest bandwidth saving available: send back the `ETag` the server gave you, and it
answers `304 Not Modified` with no body.

```dart
final etag = await cache.etagFor(url);
final response = await dio.get(
  url,
  options: Options(headers: {if (etag != null) 'If-None-Match': etag}),
);

if (response.statusCode == 304) {
  return cache.read(url);          // unchanged — the body was never sent
}
await cache.write(url, response.data, etag: response.headers.value('etag'));
```

`Cache-Control: max-age` lets you skip the request entirely while fresh; an ETag still costs
a round trip but not the payload. Use `max-age` for content that ages predictably and ETags
for content that changes unpredictably but rarely. `dio_cache_interceptor` implements both;
the important part is deciding the policy per endpoint rather than globally.

## PUT versus PATCH

Asked in almost every backend-adjacent interview:

- **PUT replaces the whole resource.** Fields you omit are cleared. It is idempotent —
  sending it twice leaves the same state.
- **PATCH applies a partial update.** Only the fields present change. It is idempotent only
  if the patch itself is (setting a value is; incrementing is not).

The practical consequence for a mobile client: a PATCH with only the changed fields avoids
the lost-update problem where two devices each PUT their full copy and the second wipes the
first's edit.

## Interview angles

**"How does a dio interceptor work?"** Three hooks — request, response, error — each ending
in exactly one of `next`, `resolve` or `reject`. Then the detail that shows experience:
order matters, auth before retry, and a missing handler call hangs the request silently.

**"How do you refresh a JWT?"** Single-flight: the first 401 refreshes, everyone else awaits
the same future, and requests are retried with the new token. Compare the used token against
the stored one to avoid a second wave, and sign out when the refresh token itself is
rejected.

**"How would you retry failed requests?"** Exponential backoff with jitter, only on
retryable statuses, only for idempotent methods or with an idempotency key, honouring
`Retry-After`. Every clause there is a separate incident you are preventing.

**"PUT versus PATCH?"** Replace versus partial update; both should be idempotent, and PATCH
avoids two devices overwriting each other's fields.

**"How do you handle a slow network?"** Explicit timeouts on all three phases, cancellation
tied to widget disposal, cached reads so the screen has something to show, and an outbox for
writes — see [offline first](offline-first.md).

## See also

- [Offline first](offline-first.md) — what happens when the request cannot be made at all
- [Error handling](../part-02-professional/error-handling.md) — mapping exceptions to failures
- [Secure storage](../part-04-production/security-storage.md) — where tokens live
- [Network security](../part-04-production/security-network.md) — TLS and pinning
