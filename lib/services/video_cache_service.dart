import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Singleton that keeps [VideoPlayerController]s alive across widget rebuilds.
///
/// Benefits:
///   • Each video URL is only fetched **once** per app session → fewer R2 Class B ops.
///   • Controllers are reused instantly on revisit — no spinner on second open.
///   • Cache-Control request header hints the platform HTTP stack to honour CDN cache.
///
/// Usage:
///   final controller = await VideoCacheService.instance.getController(url);
class VideoCacheService {
  static final VideoCacheService instance = VideoCacheService._internal();
  VideoCacheService._internal();

  /// Fully initialised controllers keyed by canonical URL.
  final Map<String, VideoPlayerController> _controllers = {};

  /// Pending init futures to avoid double-initialisation when the same URL is
  /// requested concurrently (e.g. fast navigation).
  final Map<String, Future<VideoPlayerController?>> _pending = {};

  /// Reference counts for each URL to know which ones are currently displayed.
  final Map<String, int> _refCounts = {};

  /// Access order tracker (Least Recently Used first).
  final List<String> _accessOrder = [];

  /// Maximum number of idle (refCount == 0) controllers to keep in memory.
  static const int _maxIdleControllers = 3;

  /// Prefetch queue to process prefetch requests sequentially.
  final List<String> _prefetchQueue = [];
  bool _isPrefetching = false;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns an initialised, looping, muted, auto-playing controller for [url].
  /// Returns `null` if initialisation fails.
  Future<VideoPlayerController?> getController(String url) async {
    _markAccessed(url);
    _refCounts[url] = (_refCounts[url] ?? 0) + 1;

    VideoPlayerController? controller;

    // 1. Already cached and initialised → return immediately.
    final cached = _controllers[url];
    if (cached != null && cached.value.isInitialized) {
      if (!cached.value.isPlaying) cached.play();
      controller = cached;
    } else if (_pending.containsKey(url)) {
      // 2. Initialisation already in progress → wait for it.
      controller = await _pending[url]!;
    } else {
      // 3. New URL → initialise and cache.
      final future = _initController(url);
      _pending[url] = future;
      controller = await future;
    }

    // If initialisation failed, decrement the refCount immediately.
    if (controller == null) {
      _refCounts[url] = (_refCounts[url] ?? 1) - 1;
      if (_refCounts[url]! <= 0) {
        _refCounts.remove(url);
      }
    }

    return controller;
  }

  /// Release a reference to the controller for [url].
  /// If no more widgets are using it, it becomes eligible for cache eviction.
  void release(String url) {
    if (_refCounts.containsKey(url)) {
      _refCounts[url] = _refCounts[url]! - 1;
      if (_refCounts[url]! <= 0) {
        _refCounts.remove(url);
        _trimCache();
      }
    }
  }

  bool isReady(String url) =>
      _controllers[url]?.value.isInitialized == true;

  /// Pause every active controller (e.g. when app goes to background).
  void pauseAll() {
    for (final c in _controllers.values) {
      if (c.value.isInitialized && c.value.isPlaying) c.pause();
    }
  }

  /// Resume every controller (e.g. when app returns to foreground).
  void resumeAll() {
    for (final c in _controllers.values) {
      if (c.value.isInitialized && !c.value.isPlaying) c.play();
    }
  }

  /// Release all controllers — call when the user logs out or the app is torn down.
  void disposeAll() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pending.clear();
    _refCounts.clear();
    _accessOrder.clear();
    _prefetchQueue.clear();
  }

  /// Silently pre-initialise [urls] in background so they are ready instantly
  /// when the user scrolls to them.
  void prefetch(List<String> urls) {
    for (final url in urls) {
      if (_controllers.containsKey(url) ||
          _pending.containsKey(url) ||
          _prefetchQueue.contains(url)) {
        continue;
      }
      _prefetchQueue.add(url);
    }
    _runPrefetchQueue();
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  void _markAccessed(String url) {
    _accessOrder.remove(url);
    _accessOrder.add(url);
  }

  Future<VideoPlayerController?> _initController(String url) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {
        // Hint to the platform HTTP stack: treat cached response as valid for 24 h.
        // Cloudflare R2 + Workers can enforce this on the server side too.
        'Cache-Control': 'public, max-age=86400',
      },
    );

    try {
      await controller.initialize().timeout(const Duration(seconds: 8));
      controller.setLooping(true);
      controller.setVolume(0.0); // muted auto-play
      controller.play();
      _controllers[url] = controller;
      debugPrint('[VideoCacheService] ✅ Initialised: $url');
      _trimCache();
    } catch (e) {
      debugPrint('[VideoCacheService] ❌ Failed to init: $url — $e');
      controller.dispose();
      _pending.remove(url);
      return null;
    }

    _pending.remove(url);
    return controller;
  }

  /// Evict oldest idle (refCount == 0) controllers to keep the cache size within limits.
  void _trimCache() {
    if (_controllers.length <= _maxIdleControllers) return;

    // Find all controllers that have no active references
    final idleUrls = _controllers.keys
        .where((url) => (_refCounts[url] ?? 0) == 0)
        .toList();

    // Sort idle controllers by their access order (oldest first)
    idleUrls.sort((a, b) {
      final indexA = _accessOrder.indexOf(a);
      final indexB = _accessOrder.indexOf(b);
      return indexA.compareTo(indexB);
    });

    for (final url in idleUrls) {
      if (_controllers.length <= _maxIdleControllers) break;

      final controller = _controllers.remove(url);
      controller?.dispose();
      _accessOrder.remove(url);
      debugPrint('[VideoCacheService] ♻️ Evicted from cache: $url');
    }
  }

  /// Process the prefetch queue sequentially.
  Future<void> _runPrefetchQueue() async {
    if (_isPrefetching) return;
    _isPrefetching = true;

    while (_prefetchQueue.isNotEmpty) {
      // If the cache is already full of idle/active controllers, stop prefetching
      if (_controllers.length >= _maxIdleControllers) {
        _prefetchQueue.clear();
        break;
      }

      final url = _prefetchQueue.removeAt(0);
      if (_controllers.containsKey(url) || _pending.containsKey(url)) continue;

      // Initialize the controller sequentially
      final controller = await getController(url);
      if (controller != null) {
        // Immediately release it since it was just a prefetch
        release(url);
      }
    }

    _isPrefetching = false;
  }
}
