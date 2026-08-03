import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../networking/paginator.dart';
import '../networking/retry.dart';
import '../networking/token_refresh.dart';

void main() {
  group('retry', () {
    test('succeeds after transient failures', () {
      fakeAsync((FakeAsync async) {
        int calls = 0;
        Object? result;

        unawaited(
          retry<String>(() async {
            calls++;
            if (calls < 3) {
              throw const HttpStatusException(503);
            }
            return 'ok';
          }).then((String value) => result = value),
        );

        async.elapse(const Duration(seconds: 10));

        expect(calls, 3);
        expect(result, 'ok');
      });
    });

    test('does not retry a failure that will never succeed', () {
      fakeAsync((FakeAsync async) {
        int calls = 0;
        Object? caught;

        unawaited(
          retry<String>(() async {
            calls++;
            throw const HttpStatusException(404);
          }).catchError((Object error) {
            caught = error;
            return 'unused';
          }),
        );

        async.elapse(const Duration(seconds: 10));

        expect(calls, 1, reason: 'a 404 is the final answer');
        expect(caught, isA<HttpStatusException>());
      });
    });

    test('rethrows the real error once attempts are exhausted', () {
      fakeAsync((FakeAsync async) {
        int calls = 0;
        Object? caught;

        unawaited(
          retry<String>(
            () async {
              calls++;
              throw TimeoutException('slow');
            },
            policy: const RetryPolicy(maxAttempts: 4),
          ).catchError((Object error) {
            caught = error;
            return 'unused';
          }),
        );

        async.elapse(const Duration(minutes: 1));

        expect(calls, 4);
        expect(caught, isA<TimeoutException>());
      });
    });

    test('backoff grows exponentially and stays under the cap', () {
      const RetryPolicy policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 2),
        jitter: 0,
      );
      final Random fixed = Random(1);

      expect(policy.delayFor(2, random: fixed).inMilliseconds, 100);
      expect(policy.delayFor(3, random: fixed).inMilliseconds, 200);
      expect(policy.delayFor(4, random: fixed).inMilliseconds, 400);
      expect(policy.delayFor(9, random: fixed).inMilliseconds, 2000);
    });

    test('jitter spreads retries around the computed delay', () {
      const RetryPolicy policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 1000),
        jitter: 0.5,
      );
      final Set<int> delays = <int>{
        for (int seed = 0; seed < 20; seed++)
          policy.delayFor(2, random: Random(seed)).inMilliseconds,
      };

      expect(delays.length, greaterThan(1), reason: 'not a fixed schedule');
      expect(delays.every((int ms) => ms >= 500 && ms <= 1500), isTrue);
    });

    test('Retry-After is parsed when the server sends one', () {
      expect(
        retryAfter(<String, String>{'retry-after': '30'}),
        const Duration(seconds: 30),
      );
      expect(retryAfter(<String, String>{}), isNull);
    });

    test('only idempotent methods are safe to repeat blindly', () {
      expect(HttpStatusException.isIdempotent('GET'), isTrue);
      expect(HttpStatusException.isIdempotent('put'), isTrue);
      expect(HttpStatusException.isIdempotent('POST'), isFalse);
    });
  });

  group('TokenRefresher', () {
    late DateTime now;
    late InMemoryTokenStore store;

    AuthTokens expiredTokens() => AuthTokens(
          accessToken: 'old',
          refreshToken: 'refresh-1',
          expiresAt: now.subtract(const Duration(minutes: 1)),
        );

    setUp(() {
      now = DateTime(2026, 8, 4, 12);
      store = InMemoryTokenStore(expiredTokens());
    });

    test('concurrent 401s trigger exactly one refresh', () async {
      final Completer<void> serverDelay = Completer<void>();
      int refreshCalls = 0;

      final TokenRefresher refresher = TokenRefresher(
        store: store,
        clock: () => now,
        refresh: (String token) async {
          refreshCalls++;
          await serverDelay.future;
          return AuthTokens(
            accessToken: 'new',
            refreshToken: 'refresh-2',
            expiresAt: now.add(const Duration(hours: 1)),
          );
        },
      );

      // Five requests fail at once, before any refresh has completed.
      final List<Future<String>> waiting = <Future<String>>[
        for (int i = 0; i < 5; i++) refresher.onUnauthorized('old'),
      ];

      serverDelay.complete();
      final List<String> tokens = await Future.wait(waiting);

      expect(refreshCalls, 1, reason: 'the others waited on the first future');
      expect(tokens, everyElement('new'));
    });

    test('a request that used an already-rotated token does not refresh again',
        () async {
      int refreshCalls = 0;
      final TokenRefresher refresher = TokenRefresher(
        store: store,
        clock: () => now,
        refresh: (String token) async {
          refreshCalls++;
          return AuthTokens(
            accessToken: 'new',
            refreshToken: 'refresh-2',
            expiresAt: now.add(const Duration(hours: 1)),
          );
        },
      );

      expect(await refresher.onUnauthorized('old'), 'new');
      // A second request that had been queued with the stale token.
      expect(await refresher.onUnauthorized('old'), 'new');

      expect(refreshCalls, 1);
    });

    test('a rejected refresh token clears storage and signs out', () async {
      bool signedOut = false;
      final TokenRefresher refresher = TokenRefresher(
        store: store,
        clock: () => now,
        refresh: (String token) async =>
            throw const HttpStatusException(401, 'refresh token revoked'),
        onSignOut: () async => signedOut = true,
      );

      await expectLater(
        refresher.accessToken(),
        throwsA(isA<RefreshFailure>()),
      );
      expect(signedOut, isTrue);
      expect(await store.read(), isNull);
    });

    test('a valid token is returned without refreshing', () async {
      await store.write(
        AuthTokens(
          accessToken: 'fresh',
          refreshToken: 'refresh-1',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      final TokenRefresher refresher = TokenRefresher(
        store: store,
        clock: () => now,
        refresh: (String token) async => throw StateError('should not refresh'),
      );

      expect(await refresher.accessToken(), 'fresh');
    });

    test('a token inside the leeway window is refreshed early', () async {
      await store.write(
        AuthTokens(
          accessToken: 'nearly-stale',
          refreshToken: 'refresh-1',
          expiresAt: now.add(const Duration(seconds: 5)),
        ),
      );
      final TokenRefresher refresher = TokenRefresher(
        store: store,
        clock: () => now,
        refresh: (String token) async => AuthTokens(
          accessToken: 'new',
          refreshToken: 'refresh-2',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );

      expect(await refresher.accessToken(), 'new');
    });
  });

  group('Paginator', () {
    Page<int> pageOf(int start, {bool last = false}) => Page<int>(
          items: <int>[for (int i = start; i < start + 3; i++) i],
          nextCursor: last ? null : '${start + 3}',
        );

    test('accumulates pages and stops at the end', () async {
      final Paginator<int> paginator = Paginator<int>(
        pageSize: 3,
        loader: (String? cursor, int limit) async {
          final int start = int.tryParse(cursor ?? '0') ?? 0;
          return pageOf(start, last: start >= 6);
        },
      );

      await paginator.loadMore();
      expect(paginator.items, <int>[0, 1, 2]);
      expect(paginator.hasMore, isTrue);

      await paginator.loadMore();
      await paginator.loadMore();
      expect(paginator.items, <int>[0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(paginator.hasMore, isFalse);

      // Past the end, further calls are no-ops rather than errors.
      await paginator.loadMore();
      expect(paginator.loadCount, 3);
    });

    test('a fast scroll cannot load the same page twice', () async {
      final Completer<void> gate = Completer<void>();
      final Paginator<int> paginator = Paginator<int>(
        pageSize: 3,
        loader: (String? cursor, int limit) async {
          await gate.future;
          return pageOf(0);
        },
      );

      final Future<void> first = paginator.loadMore();
      final Future<void> second = paginator.loadMore();
      final Future<void> third = paginator.loadMore();

      gate.complete();
      await Future.wait(<Future<void>>[first, second, third]);

      expect(paginator.loadCount, 1);
      expect(paginator.items, <int>[0, 1, 2]);
    });

    test('duplicates across pages are dropped', () async {
      int call = 0;
      final Paginator<int> paginator = Paginator<int>(
        pageSize: 3,
        identity: (int item) => item,
        loader: (String? cursor, int limit) async {
          call++;
          // The second page overlaps the first — an item was inserted at the
          // top of the list between requests.
          return call == 1
              ? const Page<int>(items: <int>[1, 2, 3], nextCursor: '3')
              : const Page<int>(items: <int>[3, 4, 5]);
        },
      );

      await paginator.loadMore();
      await paginator.loadMore();

      expect(paginator.items, <int>[1, 2, 3, 4, 5]);
    });

    test('a failed page keeps what was already loaded', () async {
      int call = 0;
      final Paginator<int> paginator = Paginator<int>(
        pageSize: 3,
        loader: (String? cursor, int limit) async {
          call++;
          if (call == 2) {
            throw const HttpStatusException(503);
          }
          return pageOf(int.tryParse(cursor ?? '0') ?? 0);
        },
      );

      await paginator.loadMore();
      await paginator.loadMore();

      expect(paginator.error, isA<HttpStatusException>());
      expect(paginator.items, <int>[0, 1, 2], reason: 'page 1 is still there');

      await paginator.retry();
      expect(paginator.error, isNull);
      expect(paginator.items, <int>[0, 1, 2, 3, 4, 5]);
    });

    test('refresh starts over from the first page', () async {
      final Paginator<int> paginator = Paginator<int>(
        pageSize: 3,
        loader: (String? cursor, int limit) async =>
            pageOf(int.tryParse(cursor ?? '0') ?? 0),
      );

      await paginator.loadMore();
      await paginator.loadMore();
      expect(paginator.items.length, 6);

      await paginator.refresh();
      expect(paginator.items, <int>[0, 1, 2]);
    });

    test('prefetch triggers before the user reaches the bottom', () {
      expect(
        shouldPrefetch(pixels: 900, maxScrollExtent: 1000),
        isTrue,
      );
      expect(
        shouldPrefetch(pixels: 400, maxScrollExtent: 1000),
        isFalse,
      );
    });
  });
}
