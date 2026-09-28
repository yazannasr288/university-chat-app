import 'dart:io';

/// Small synchronous file-existence cache for hot chat build paths.
///
/// `File.existsSync()` is cheap for a single file but expensive when it runs
/// repeatedly while scrolling many media messages. This cache keeps the check
/// synchronous for simple widget code, while preventing repeated disk access on
/// every rebuild.
class LocalFileExistsCache {
  LocalFileExistsCache._();

  static const int _maxEntries = 400;
  static final Map<String, bool> _cache = <String, bool>{};

  static bool existsSync(String? path) {
    final cleanPath = path?.trim();
    if (cleanPath == null || cleanPath.isEmpty) return false;

    final cached = _cache[cleanPath];
    if (cached != null) return cached;

    final exists = File(cleanPath).existsSync();
    _cache[cleanPath] = exists;

    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }

    return exists;
  }

  static void forget(String? path) {
    final cleanPath = path?.trim();
    if (cleanPath == null || cleanPath.isEmpty) return;
    _cache.remove(cleanPath);
  }

  static void clear() => _cache.clear();
}
