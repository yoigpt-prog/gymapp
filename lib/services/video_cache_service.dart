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

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns an initialised, looping, muted, auto-playing controller for [url].
  /// Returns `null` if initialisation fails.
  Future<VideoPlayerController?> getController(String url) {
    // 1. Already cached and initialised → return immediately.
    final cached = _controllers[url];
    if (cached != null && cached.value.isInitialized) {
      if (!cached.value.isPlaying) cached.play();
      return Future.value(cached);
    }

    // 2. Initialisation already in progress → wait for it.
    if (_pending.containsKey(url)) return _pending[url]!;

    // 3. New URL → initialise and cache.
    final future = _initController(url);
    _pending[url] = future;
    return future;
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
  }

  // ─── Private ───────────────────────────────────────────────────────────────

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
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0.0); // muted auto-play
      controller.play();
      _controllers[url] = controller;
      debugPrint('[VideoCacheService] ✅ Initialised: $url');
    } catch (e) {
      debugPrint('[VideoCacheService] ❌ Failed to init: $url — $e');
      controller.dispose();
      _pending.remove(url);
      return null;
    }

    _pending.remove(url);
    return controller;
  }
}
