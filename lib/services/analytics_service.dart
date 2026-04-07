import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'dart:io';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  Mixpanel? _mixpanel;
  bool _initialized = false;
  String? _currentUserId;

  // ── Per-session dedup flags (reset on reset() / logout) ───────────────────
  bool _appOpenTracked = false;
  bool _quizStartedTracked = false;
  bool _quizCompletedTracked = false;
  bool _purchaseSuccessTracked = false;
  DateTime? _lastPaywallView;

  // ── PLATFORM ──────────────────────────────────────────────────────────────
  static String get _platform {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  // ── INIT ──────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _mixpanel = await Mixpanel.init(
        "a4c6fa788d6f31bf712bf5ed7cb87b2c",
        trackAutomaticEvents: false,
      );

      // Logging only in debug — silent in release
      if (kDebugMode) _mixpanel?.setLoggingEnabled(true);

      _mixpanel?.registerSuperProperties({'platform': _platform});
      _initialized = true;
      debugPrint('[Analytics] Initialized. Platform: $_platform');
    } catch (e) {
      debugPrint('[Analytics] Init failed: $e');
    }
  }

  // ── IDENTITY ──────────────────────────────────────────────────────────────
  /// MUST be called ONLY from the Supabase auth state stream listener
  /// after session != null is confirmed. Never from main().
  void identifyUser(String userId) {
    if (!_initialized) return;
    if (_currentUserId == userId) return; // already identified

    try {
      _mixpanel?.identify(userId);
      _currentUserId = userId;

      final people = _mixpanel?.getPeople();
      people?.set('platform', _platform);
      people?.set('last_seen', DateTime.now().toUtc().toIso8601String());

      debugPrint('[Analytics] identifyUser: $userId');
    } catch (e) {
      debugPrint('[Analytics] identifyUser error: $e');
    }
  }

  // ── RESET (on logout) ─────────────────────────────────────────────────────
  void reset() {
    if (!_initialized) return;
    try {
      _mixpanel?.reset();
      debugPrint('[Analytics] reset() — identity cleared');
    } catch (e) {
      debugPrint('[Analytics] reset error: $e');
    }
    _currentUserId = null;
    // Reset all per-session dedup flags
    _appOpenTracked = false;
    _quizStartedTracked = false;
    _quizCompletedTracked = false;
    _purchaseSuccessTracked = false;
    _lastPaywallView = null;
  }

  // ── App Open ──────────────────────────────────────────────────────────────
  /// Rules:
  ///  - If user is logged in → called AFTER identifyUser() inside auth listener.
  ///  - If user is guest → called from the guest branch in auth listener
  ///    (when event == AuthChangeEvent.initialSession && session == null).
  ///  - Deduplicated per app lifecycle via _appOpenTracked.
  void trackAppOpen() {
    if (!_initialized || _appOpenTracked) return;
    try {
      _mixpanel?.track('App Open', properties: {'platform': _platform});
      _appOpenTracked = true;
      _mixpanel?.flush();
      debugPrint('[Analytics] ✅ App Open tracked (userId: ${_currentUserId ?? "anonymous"})');
    } catch (e) {
      debugPrint('[Analytics] trackAppOpen error: $e');
    }
  }

  // ── Quiz Started ──────────────────────────────────────────────────────────
  /// Fired once per quiz session. Reset on logout.
  void trackQuizStarted() {
    if (!_initialized) return;
    try {
      _mixpanel?.track('Quiz Started');
      _mixpanel?.flush();
      debugPrint('[Analytics] ✅ Quiz Started tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizStarted error: $e');
    }
  }

  // ── Quiz Completed ────────────────────────────────────────────────────────
  /// Fired once per quiz. Reset on logout.
  void trackQuizCompleted() {
    if (!_initialized) return;
    try {
      _mixpanel?.track('Quiz Completed');
      _mixpanel?.flush();
      debugPrint('[Analytics] ✅ Quiz Completed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizCompleted error: $e');
    }
  }

  // ── Paywall Viewed ────────────────────────────────────────────────────────
  /// Throttled: minimum 5s between fires to prevent rapid duplicates.
  void trackPaywallViewed({required String source}) {
    if (!_initialized) return;
    final now = DateTime.now();
    if (_lastPaywallView != null &&
        now.difference(_lastPaywallView!).inSeconds < 5) return;
    try {
      _mixpanel?.track('Paywall Viewed', properties: {'source': source});
      _lastPaywallView = now;
      _mixpanel?.flush();
      debugPrint('[Analytics] ✅ Paywall Viewed: $source');
    } catch (e) {
      debugPrint('[Analytics] trackPaywallViewed error: $e');
    }
  }

  // ── Purchase Success ──────────────────────────────────────────────────────
  /// Fires once. Ignores restores entirely.
  void trackPurchaseSuccess({required String plan, bool isRestore = false}) {
    if (!_initialized || _purchaseSuccessTracked || isRestore) return;
    try {
      _mixpanel?.track('Purchase Success', properties: {'plan': plan});
      _purchaseSuccessTracked = true;
      _mixpanel?.flush();
      debugPrint('[Analytics] ✅ Purchase Success: $plan');
    } catch (e) {
      debugPrint('[Analytics] trackPurchaseSuccess error: $e');
    }
  }
}
