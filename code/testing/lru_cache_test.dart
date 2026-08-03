import 'package:flutter_test/flutter_test.dart';

import '../dart/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('evicts the least recently used entry at capacity', () {
      final LruCache<String, int> cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.length, 2);
    });

    test('a read promotes a key out of the eviction slot', () {
      final LruCache<String, int> cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      // Without this read, 'a' would be evicted by the write below.
      cache.get('a');
      cache.put('c', 3);

      expect(cache.get('a'), 1);
      expect(cache.get('b'), isNull);
    });

    test('updating a key refreshes its position rather than duplicating it',
        () {
      final LruCache<String, int> cache = LruCache<String, int>(capacity: 2);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('a', 11);
      cache.put('c', 3);

      expect(cache.length, 2);
      expect(cache.get('a'), 11);
      expect(cache.get('b'), isNull);
    });

    test('onEvict fires for evicted and cleared entries', () {
      final List<String> evicted = <String>[];
      final LruCache<String, int> cache = LruCache<String, int>(
        capacity: 1,
        onEvict: (String key, int value) => evicted.add('$key=$value'),
      );

      cache.put('a', 1);
      cache.put('b', 2);
      expect(evicted, <String>['a=1']);

      cache.clear();
      expect(evicted, <String>['a=1', 'b=2']);
      expect(cache.isEmpty, isTrue);
    });

    test('putIfAbsent computes once per key', () {
      final LruCache<String, int> cache = LruCache<String, int>(capacity: 4);
      int computations = 0;

      int compute() {
        computations++;
        return 42;
      }

      expect(cache.putIfAbsent('a', compute), 42);
      expect(cache.putIfAbsent('a', compute), 42);
      expect(computations, 1);
    });

    test('keys are ordered least- to most-recently used', () {
      final LruCache<String, int> cache = LruCache<String, int>(capacity: 3);

      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      cache.get('a');

      expect(cache.keys.toList(), <String>['b', 'c', 'a']);
    });
  });
}
