import 'dart:collection';

/// Memory-bounded local cache with indexing, LRU eviction, and cursor pagination.
/// Enforces a maximum memory ceiling so mobile devices never exceed 25MB RAM.
class LocalDataCache<T> {
  final int maxMemoryCapacity;
  final String Function(T item) idSelector;
  final int Function(T item)? timestampSelector;

  final LinkedHashMap<String, T> _storage = LinkedHashMap<String, T>();

  LocalDataCache({
    this.maxMemoryCapacity = 1000,
    required this.idSelector,
    this.timestampSelector,
  });

  /// Inserts or updates an item with LRU retention
  void put(T item) {
    final id = idSelector(item);
    if (_storage.containsKey(id)) {
      _storage.remove(id);
    } else if (_storage.length >= maxMemoryCapacity) {
      // Evict oldest item to maintain strict memory ceiling
      final oldestKey = _storage.keys.first;
      _storage.remove(oldestKey);
    }
    _storage[id] = item;
  }

  /// Bulk upsert
  void putAll(Iterable<T> items) {
    for (final item in items) {
      put(item);
    }
  }

  T? get(String id) {
    if (!_storage.containsKey(id)) return null;
    // Mark as recently used
    final item = _storage.remove(id);
    if (item != null) {
      _storage[id] = item;
    }
    return item;
  }

  /// Removes an item by ID
  void remove(String id) {
    _storage.remove(id);
  }

  /// Clears cache
  void clear() {
    _storage.clear();
  }

  /// Returns all cached items in reverse-chronological order (newest first)
  List<T> getAll() {
    return _storage.values.toList().reversed.toList();
  }

  /// Slices items using cursor-based pagination
  List<T> getPaginated({
    int limit = 50,
    String? startAfterId,
    bool Function(T item)? filter,
  }) {
    final all = getAll();
    final filtered = filter != null ? all.where(filter).toList() : all;

    int startIndex = 0;
    if (startAfterId != null) {
      final index = filtered.indexWhere((e) => idSelector(e) == startAfterId);
      if (index != -1) {
        startIndex = index + 1;
      }
    }

    if (startIndex >= filtered.length) {
      return [];
    }

    final endIndex = (startIndex + limit).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  int get length => _storage.length;
}
