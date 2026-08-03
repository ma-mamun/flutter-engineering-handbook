/// A fixed-capacity least-recently-used cache.
///
/// The interview version of this question is really asking whether you know
/// that a Dart `Map` literal is a `LinkedHashMap`: it iterates in insertion
/// order, so "move this key to the most-recently-used end" is remove-then-
/// reinsert, and the least-recently-used key is always `keys.first`. That gives
/// O(1) reads and writes without writing a linked list by hand.
library;

/// An in-memory LRU cache bounded by entry count.
///
/// Bounded by *count*, not bytes — for image or response caches where entry
/// size varies by orders of magnitude, weigh entries instead and evict until
/// the weight fits.
class LruCache<K, V> {
  LruCache({required this.capacity, this.onEvict})
      : assert(capacity > 0, 'capacity must be at least 1');

  /// Maximum number of entries held before the least-recently-used one is
  /// evicted.
  final int capacity;

  /// Called with each evicted entry, in eviction order.
  ///
  /// This is the hook that stops a cache from leaking: if values own resources
  /// — a subscription, a file handle, a decoded image — release them here.
  final void Function(K key, V value)? onEvict;

  // A map literal is a LinkedHashMap: iteration follows insertion order, and
  // that ordering is what makes this class an LRU rather than a plain map.
  final Map<K, V> _entries = <K, V>{};

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  /// Keys from least- to most-recently used.
  Iterable<K> get keys => _entries.keys;

  bool containsKey(K key) => _entries.containsKey(key);

  /// Returns the value for [key] and marks it most-recently used.
  ///
  /// Returns `null` when the key is absent. If `V` is itself nullable, use
  /// [containsKey] to tell "absent" from "present and null".
  V? get(K key) {
    if (!_entries.containsKey(key)) {
      return null;
    }
    // Remove and reinsert so the key moves to the most-recently-used end.
    final V value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  /// Inserts or updates [key], evicting the least-recently-used entry if the
  /// cache is now over capacity.
  void put(K key, V value) {
    // Removing first matters even on update: without it the key keeps its old
    // position and would be evicted too early.
    _entries.remove(key);
    _entries[key] = value;

    while (_entries.length > capacity) {
      final K oldest = _entries.keys.first;
      final V evicted = _entries.remove(oldest) as V;
      onEvict?.call(oldest, evicted);
    }
  }

  /// Returns the cached value for [key], computing and caching it on a miss.
  ///
  /// The synchronous sibling of the read-through cache in the data layer: one
  /// place decides whether to call the expensive thing.
  V putIfAbsent(K key, V Function() ifAbsent) {
    final V? existing = get(key);
    if (existing != null || _entries.containsKey(key)) {
      return existing as V;
    }
    final V created = ifAbsent();
    put(key, created);
    return created;
  }

  V? remove(K key) => _entries.remove(key);

  /// Drops every entry, notifying [onEvict] for each.
  void clear() {
    if (onEvict != null) {
      for (final MapEntry<K, V> entry in _entries.entries.toList()) {
        onEvict!(entry.key, entry.value);
      }
    }
    _entries.clear();
  }

  @override
  String toString() => 'LruCache(${_entries.length}/$capacity)';
}
