/// Cursor pagination that survives the things offset pagination does not.
///
/// Offset pagination (`?page=3`) breaks when the underlying list changes: an
/// item inserted at the top shifts everything down, so page 3 repeats a row
/// that was on page 2 and skips one that moved. Cursor pagination asks for
/// "the page after this item" and is stable under insertion.
library;

import 'dart:async';

/// One page of results, as a data source returns it.
class Page<T> {
  const Page({required this.items, this.nextCursor});

  final List<T> items;

  /// Null means this was the last page. An empty item list with a non-null
  /// cursor is legal — a filtered page can be empty and still have a next.
  final String? nextCursor;
}

typedef PageLoader<T> = Future<Page<T>> Function(String? cursor, int limit);

/// Accumulates pages, and refuses to load two at once.
///
/// The concurrency guard is the part hand-rolled pagination usually misses: a
/// fast scroll fires the "load more" callback several times before the first
/// response lands, and without the guard the same page is appended twice.
class Paginator<T> {
  Paginator({
    required PageLoader<T> loader,
    this.pageSize = 20,
    Object Function(T item)? identity,
  })  : _loader = loader,
        _identity = identity;

  final PageLoader<T> _loader;
  final int pageSize;

  /// Used to drop duplicates across pages. Without it, an item that moved
  /// between pages while the user was scrolling appears twice — and if the
  /// list is keyed by id, Flutter throws on the duplicate key.
  final Object Function(T item)? _identity;

  final List<T> _items = <T>[];
  final Set<Object> _seen = <Object>{};

  String? _cursor;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _error;
  int loadCount = 0;

  List<T> get items => List<T>.unmodifiable(_items);

  bool get hasMore => _hasMore;

  bool get isLoading => _isLoading;

  Object? get error => _error;

  bool get isEmpty => _items.isEmpty && !_hasMore;

  /// Loads the next page. Returns immediately if one is already loading or the
  /// end has been reached.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    _isLoading = true;
    _error = null;
    loadCount++;

    try {
      final Page<T> page = await _loader(_cursor, pageSize);
      for (final T item in page.items) {
        final Object? key = _identity?.call(item);
        if (key != null && !_seen.add(key)) {
          continue; // already have it
        }
        _items.add(item);
      }
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
    } on Object catch (error) {
      // Keep what was already loaded: a failed page 3 must not blank out pages
      // 1 and 2. The UI shows a retry row at the bottom instead.
      _error = error;
    } finally {
      _isLoading = false;
    }
  }

  /// Retries the page that failed, keeping everything already loaded.
  Future<void> retry() async {
    if (_error == null) {
      return;
    }
    _error = null;
    await loadMore();
  }

  /// Pull to refresh: start over, but only replace what is on screen once the
  /// first page has actually arrived.
  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _error = null;
    _isLoading = true;
    loadCount++;

    try {
      final Page<T> page = await _loader(null, pageSize);
      _items
        ..clear()
        ..addAll(page.items);
      _seen
        ..clear()
        ..addAll(
          _identity == null
              ? const <Object>[]
              : page.items.map((T item) => _identity(item)),
        );
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
    } on Object catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
    }
  }
}

/// Decides when a scroll position is close enough to the end to prefetch.
///
/// Trigger on remaining pixels rather than on the last index being built: at
/// 200 px of runway the next page is usually there before the user reaches the
/// spinner, which is the difference between "infinite" and "loading…".
bool shouldPrefetch({
  required double pixels,
  required double maxScrollExtent,
  double threshold = 200,
}) =>
    maxScrollExtent - pixels <= threshold;
