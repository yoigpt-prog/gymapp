import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

// Conditional import — web file uses dart:html/package:web, stub returns '' on native.
// Using dart.library.html (not dart.library.io) is the correct idiom:
//   • dart.library.html is ONLY available on Flutter Web
//   • dart.library.io   is available on BOTH native AND web (unreliable as a guard)
import 'analytics_service_stub.dart'
    if (dart.library.html) 'analytics_service_web.dart' as web_ua;

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  Mixpanel? _mixpanel;
  bool _initialized = false;
  String? _currentUserId;

  // ── Per-lifecycle dedup flags ──────────────────────────────────────────────
  // NOTE: App Open uses persistent session logic (SharedPreferences),
  //       so _appOpenTracked only guards against double-fire in the same
  //       app lifecycle before prefs are written.
  bool _appOpenTracked = false;
  bool _quizStartedTracked = false;
  bool _quizCompletedTracked = false;
  bool _purchaseSuccessTracked = false;
  DateTime? _lastPaywallView;

  // ── SHARED PREFERENCES KEYS ───────────────────────────────────────────────
  static const _kLastOpenKey   = 'gg_analytics_last_open_ms';
  static const _kSessionIdKey  = 'gg_analytics_session_id';
  static const _kSessionThreshold = Duration(minutes: 30);

  // ── UUID GENERATOR ────────────────────────────────────────────────────────
  static const _uuid = Uuid();

  // ── PLATFORM DETECTION ───────────────────────────────────────────────────
  /// Web:    sniffs browser user-agent → "iOS" | "Android" | "Web"
  /// Native: uses dart:io Platform flags → "iOS" | "Android"
  ///
  /// IMPORTANT: dart:io must NEVER be called when kIsWeb == true.
  static String get _platform {
    if (kIsWeb) {
      // getUserAgent() is provided by analytics_service_web.dart on web,
      // and returns '' from analytics_service_stub.dart on native
      // (though this branch is unreachable on native).
      final ua = web_ua.getUserAgent().toLowerCase();
      if (ua.contains('iphone') || ua.contains('ipad')) return 'iOS';
      if (ua.contains('android')) return 'Android';
      return 'Web';
    }
    // kIsWeb == false → safe to call dart:io
    try {
      if (Platform.isIOS) return 'iOS';
      if (Platform.isAndroid) return 'Android';
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  /// "browser" when running as a web app, "app" for native binary.
  static String get _appType => kIsWeb ? 'browser' : 'app';

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

      // Register platform + app_type as super properties so EVERY event
      // automatically carries them without manual per-call inclusion.
      // session_id is registered later in trackAppOpen() once we know
      // whether this is a new session or a continuation.
      _mixpanel?.registerSuperProperties({
        'platform': _platform,
        'app_type': _appType,
      });

      _initialized = true;
      debugPrint('[Analytics] Initialized. platform=$_platform  app_type=$_appType');
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
      people?.set('app_type', _appType);
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
    // Reset per-lifecycle dedup flags.
    // NOTE: We do NOT clear last_open_time or session_id here —
    // a logout does not constitute a new session for App Open purposes.
    _appOpenTracked = false;
    _quizStartedTracked = false;
    _quizCompletedTracked = false;
    _purchaseSuccessTracked = false;
    _lastPaywallView = null;
  }

  // ── App Open ──────────────────────────────────────────────────────────────
  /// Session-aware: fires at most once per 30-minute inactivity window per device.
  ///
  /// Session lifecycle:
  ///  1. Read last_open_time from SharedPreferences.
  ///  2. If null OR now - last_open_time > 30 min → NEW session:
  ///       • Generate a fresh session_id UUID.
  ///       • Register it as a Mixpanel super property.
  ///       • Track "App Open".
  ///  3. If within 30 min → EXISTING session:
  ///       • Restore the persisted session_id as a super property (so all
  ///         events within this lifecycle carry the correct session_id).
  ///       • Skip "App Open" (already fired this session).
  ///  4. Always update last_open_time = now.
  ///
  ///  _appOpenTracked (in-memory) prevents a second check within the same
  ///  app lifecycle before prefs are written.
  Future<void> trackAppOpen() async {
    if (!_initialized || _appOpenTracked) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final lastMs = prefs.getInt(_kLastOpenKey);

      final bool isNewSession = lastMs == null ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) >
              _kSessionThreshold;

      String sessionId;

      if (isNewSession) {
        // Generate a fresh UUID for this session.
        sessionId = _uuid.v4();
        await prefs.setString(_kSessionIdKey, sessionId);

        // Register session_id alongside platform + app_type so every
        // subsequent event in this session carries all three.
        _mixpanel?.registerSuperProperties({'session_id': sessionId});

        _mixpanel?.track('App Open');
        _mixpanel?.flush();

        debugPrint(
          '[Analytics] ✅ App Open tracked — NEW session\n'
          '  session_id : $sessionId\n'
          '  platform   : $_platform\n'
          '  app_type   : $_appType\n'
          '  userId     : ${_currentUserId ?? "anonymous"}',
        );
      } else {
        // Restore the existing session_id as a super property for this lifecycle.
        sessionId = prefs.getString(_kSessionIdKey) ?? _uuid.v4();
        _mixpanel?.registerSuperProperties({'session_id': sessionId});

        debugPrint(
          '[Analytics] ⏭ App Open skipped — existing session\n'
          '  session_id : $sessionId',
        );
      }

      // Always refresh the timestamp and set the in-memory guard.
      await prefs.setInt(_kLastOpenKey, now.millisecondsSinceEpoch);
      _appOpenTracked = true;
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
        now.difference(_lastPaywallView!).inSeconds < 5) { return; }
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
