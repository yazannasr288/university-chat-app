import 'package:firebase_storage/firebase_storage.dart';

class StorageDownloadUrlCache {
  StorageDownloadUrlCache._();

  static const int _maxResolvedUrls = 500;
  static const Duration _urlTtl = Duration(hours: 12);

  static final Map<String, _ResolvedStorageUrl> _resolvedUrls =
      <String, _ResolvedStorageUrl>{};
  static final Map<String, Future<String>> _pendingUrls =
      <String, Future<String>>{};

  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        (uri.isScheme('http') || uri.isScheme('https'));
  }

  static String normalizePath(String value) {
    return value.trim().replaceFirst(RegExp(r'^/+'), '');
  }

  static bool _isExpired(_ResolvedStorageUrl entry) {
    return DateTime.now().difference(entry.resolvedAt) > _urlTtl;
  }

  static void _remember(String path, String url) {
    final cleanUrl = url.trim();
    if (path.isEmpty || cleanUrl.isEmpty) return;

    _resolvedUrls.remove(path);
    _resolvedUrls[path] = _ResolvedStorageUrl(
      url: cleanUrl,
      resolvedAt: DateTime.now(),
    );

    while (_resolvedUrls.length > _maxResolvedUrls) {
      _resolvedUrls.remove(_resolvedUrls.keys.first);
    }
  }

  static String? peek(String storagePathOrUrl) {
    final value = storagePathOrUrl.trim();
    if (value.isEmpty) return null;

    if (isHttpUrl(value)) return value;

    final path = normalizePath(value);
    final entry = _resolvedUrls[path];
    if (entry == null) return null;

    if (_isExpired(entry)) {
      _resolvedUrls.remove(path);
      return null;
    }

    _resolvedUrls.remove(path);
    _resolvedUrls[path] = entry;
    return entry.url;
  }

  static Future<String> resolve(String storagePathOrUrl) {
    final value = storagePathOrUrl.trim();
    if (value.isEmpty) return Future.value('');

    if (isHttpUrl(value)) return Future.value(value);

    final path = normalizePath(value);

    final cached = peek(path);
    if (cached != null && cached.isNotEmpty) {
      return Future.value(cached);
    }

    final pending = _pendingUrls[path];
    if (pending != null) return pending;

    final future = FirebaseStorage.instance.ref(path).getDownloadURL().then(
      (url) {
        _remember(path, url);
        _pendingUrls.remove(path);
        return url.trim();
      },
      onError: (Object error, StackTrace stackTrace) {
        _pendingUrls.remove(path);
        throw error;
      },
    );

    _pendingUrls[path] = future;
    return future;
  }

  static void invalidate(String storagePathOrUrl) {
    final value = storagePathOrUrl.trim();
    if (value.isEmpty || isHttpUrl(value)) return;

    final path = normalizePath(value);
    _resolvedUrls.remove(path);
    _pendingUrls.remove(path);
  }

  static void clear() {
    _resolvedUrls.clear();
    _pendingUrls.clear();
  }
}

class _ResolvedStorageUrl {
  final String url;
  final DateTime resolvedAt;

  const _ResolvedStorageUrl({
    required this.url,
    required this.resolvedAt,
  });
}
