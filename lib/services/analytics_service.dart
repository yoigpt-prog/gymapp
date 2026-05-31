import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:uuid/uuid.dart';
import 'web_session.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _initialized = false;
  String? _currentUserId;

  // Attribution tracking
  String? _visitorId;
  String? _sourceVisitorId;

  // Dedup flags
  bool _appOpenTracked = false;
  bool _purchaseSuccessTracked = false;
  DateTime? _lastPaywallView;

  // Platform detection
  static String get _platform {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isIOS) return 'iOS';
      if (Platform.isAndroid) return 'Android';
    } catch (_) {}
    return defaultTargetPlatform.name;
  }

  static String _getDeviceType() {
    if (!kIsWeb) return 'mobile';
    try {
      final width = ui.PlatformDispatcher.instance.views.first.physicalSize.width / 
                    ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
      if (width < 600) return 'mobile';
      if (width < 1024) return 'tablet';
      return 'desktop';
    } catch (_) {
      return 'desktop';
    }
  }

  static String get _appType {
    if (kIsWeb) {
      return _getDeviceType() == 'desktop' ? 'web_desktop' : 'web_mobile';
    }
    try {
      if (Platform.isAndroid) return 'android_app';
      if (Platform.isIOS) return 'ios_app';
    } catch (_) {}
    return 'unknown_app';
  }

  String? get currentVisitorId => kIsWeb ? _visitorId : null;

  String appendVisitorId(String url) {
    if (!kIsWeb || _visitorId == null) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final params = Map<String, dynamic>.from(uri.queryParameters);
    params['visitor_id'] = _visitorId;
    return uri.replace(queryParameters: params).toString();
  }

  Future<void> setSourceVisitorId(String id) async {
    if (kIsWeb) return;
    if (_sourceVisitorId == id) return;
    _sourceVisitorId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('analytics_source_visitor_id', id);
    debugPrint('[Analytics] ✅ Set source_visitor_id=$id from attribution');
  }

  Future<void> _capture(String eventName, {Map<String, dynamic>? properties}) async {
    if (!_initialized) return;
    try {
      final String distinctId = await Posthog().getDistinctId();
      final String? sessionId = await Posthog().getSessionId();

      final enhancedProps = <String, dynamic>{
        'app_type': _appType,
        'platform': _platform,
        'device_type': _getDeviceType(),
        'distinct_id': distinctId,
        'session_id': sessionId ?? 'unknown',
        if (kIsWeb && _visitorId != null) 'visitor_id': _visitorId,
        if (!kIsWeb && _sourceVisitorId != null) 'source_visitor_id': _sourceVisitorId,
        if (properties != null) ...properties,
      };

      await Posthog().capture(
        eventName: eventName,
        properties: enhancedProps.cast<String, Object>(),
      );

      String logMsg = '[Analytics] ✅ Event Tracked: $eventName | distinct_id=$distinctId | session_id=${sessionId ?? 'unknown'} | app_type=$_appType | platform=$_platform | device_type=${_getDeviceType()}';
      if (kIsWeb && _visitorId != null) logMsg += ' | visitor_id=$_visitorId';
      if (!kIsWeb && _sourceVisitorId != null) logMsg += ' | source_visitor_id=$_sourceVisitorId';
      
      debugPrint(logMsg);
    } catch (e) {
      debugPrint('[Analytics] capture error: $eventName - $e');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (kIsWeb) {
        _visitorId = prefs.getString('analytics_visitor_id');
        if (_visitorId == null) {
          _visitorId = const Uuid().v4();
          await prefs.setString('analytics_visitor_id', _visitorId!);
        }
      } else {
        _sourceVisitorId = prefs.getString('analytics_source_visitor_id');
      }

      final config = PostHogConfig('phc_mU7hLvApYe2M9gzG77HzG5GK6RsWwqawQGaCp6mSVuYB');
      config.host = 'https://us.i.posthog.com';
      config.captureApplicationLifecycleEvents = false; // No noisy autocapture
      
      await Posthog().setup(config);

      // Register super properties
      await Posthog().register('platform', _platform);
      await Posthog().register('app_type', _appType);

      _initialized = true;
      debugPrint('[Analytics] Initialized PostHog. platform=$_platform app_type=$_appType');

      if (kIsWeb) {
        debugPrint('POSTHOG WEB INIT SUCCESS');
      }
    } catch (e) {
      debugPrint('[Analytics] Init failed: $e');
    }
  }

  void identifyUser(String userId) {
    if (!_initialized) return;
    if (_currentUserId == userId) return;

    try {
      Posthog().identify(userId: userId);
      _currentUserId = userId;

      Posthog().setPersonProperties(
        userPropertiesToSet: {
          'platform': _platform,
          'app_type': _appType,
          'last_seen': DateTime.now().toUtc().toIso8601String()
        }
      );

      debugPrint('[Analytics] identifyUser: $userId');
    } catch (e) {
      debugPrint('[Analytics] identifyUser error: $e');
    }
  }

  void reset() {
    if (!_initialized) return;
    // We intentionally DO NOT call Posthog().reset() to preserve the anonymous distinct_id
    debugPrint('[Analytics] reset() — local identity cleared');
    _currentUserId = null;
    _appOpenTracked = false;
    _purchaseSuccessTracked = false;
    _lastPaywallView = null;
  }

  Future<void> trackAppOpen() async {
    if (!_initialized || _appOpenTracked) return;

    if (_appType == 'web_desktop') {
      if (WebSession.isDesktopWebAppOpenTracked) {
        return;
      }
      WebSession.setDesktopWebAppOpenTracked();
    }
    try {
      _appOpenTracked = true;
      
      final prefs = await SharedPreferences.getInstance();
      final isFirstOpen = prefs.getBool('analytics_first_open') ?? true;
      
      if (isFirstOpen) {
        await _capture('first_open');
        await prefs.setBool('analytics_first_open', false);
      }
      
      await _capture('app_open');
      debugPrint('[Analytics] ✅ App Open tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAppOpen error: $e');
    }
  }



  Future<void> trackDownloadLinkClicked({required String store}) async {
    if (!kIsWeb || !_initialized) return;
    try {
      debugPrint('DOWNLOAD CLICK TRACKED');
      await _capture(
        'download_link_clicked',
        properties: {
          'store': store,
          'browser': WebSession.browser,
          'current_url': WebSession.currentUrl,
          'page_path': WebSession.pagePath,
        },
      );
      debugPrint('[Analytics] ✅ download_link_clicked: $store');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('[Analytics] trackDownloadLinkClicked error: $e');
    }
  }

  void trackQuizStarted() {
    if (!_initialized || kIsWeb) return;
    try {
      _capture('quiz_started');
      debugPrint('[Analytics] ✅ Quiz Started tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizStarted error: $e');
    }
  }
  
  void trackQuizQuestionAnswered({
    required int questionNumber,
    required String questionId,
    required String answer,
    required int timeSpentSeconds,
  }) {
    if (!_initialized || kIsWeb) return;
    try {
      _capture(
        'quiz_question_answered',
        properties: {
          'question_number': questionNumber,
          'question_id': questionId,
          'answer': answer,
          'time_spent_seconds': timeSpentSeconds,
        },
      );
      debugPrint('[Analytics] ✅ Quiz Question Answered tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizQuestionAnswered error: $e');
    }
  }

  void trackQuizBackPressed() {
    if (!_initialized || kIsWeb) return;
    try {
      _capture('quiz_back_pressed');
      debugPrint('[Analytics] ✅ Quiz Back Pressed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizBackPressed error: $e');
    }
  }
  
  void trackQuizAbandoned() {
    if (!_initialized || kIsWeb) return;
    try {
      _capture('quiz_abandoned');
      debugPrint('[Analytics] ✅ Quiz Abandoned tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizAbandoned error: $e');
    }
  }

  void trackQuizCompleted() {
    if (!_initialized || kIsWeb) return;
    try {
      _capture('quiz_completed');
      debugPrint('[Analytics] ✅ Quiz Completed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackQuizCompleted error: $e');
    }
  }
  
  void trackPlanGenerated() {
    if (!_initialized) return;
    try {
      _capture('plan_generated');
      debugPrint('[Analytics] ✅ Plan Generated tracked');
    } catch (e) {
      debugPrint('[Analytics] trackPlanGenerated error: $e');
    }
  }

  void trackPaywallViewed({
    required String source,
    String? productId,
    double? price,
    String? currency,
    String? platform,
  }) {
    if (!_initialized || kIsWeb) return;
    final now = DateTime.now();
    if (_lastPaywallView != null &&
        now.difference(_lastPaywallView!).inSeconds < 5) { return; }
    try {
      _capture(
        'paywall_viewed',
        properties: {
          'source': source,
          if (productId != null) 'product_id': productId,
          if (price != null) 'price': price,
          if (currency != null) 'currency': currency,
          if (platform != null) 'platform': platform,
        },
      );
      _lastPaywallView = now;
      debugPrint('[Analytics] ✅ Paywall Viewed: $source');
    } catch (e) {
      debugPrint('[Analytics] trackPaywallViewed error: $e');
    }
  }
  
  void trackSubscriptionSelected() {
    if (!_initialized) return;
    try {
      _capture('subscription_selected');
      debugPrint('[Analytics] ✅ Subscription Selected tracked');
    } catch (e) {
      debugPrint('[Analytics] trackSubscriptionSelected error: $e');
    }
  }
  
  void trackPurchaseStarted() {
    if (!_initialized) return;
    try {
      _capture('purchase_started');
      debugPrint('[Analytics] ✅ Purchase Started tracked');
    } catch (e) {
      debugPrint('[Analytics] trackPurchaseStarted error: $e');
    }
  }

  void trackPurchaseSuccess({required String plan, bool isRestore = false}) {
    if (!_initialized || _purchaseSuccessTracked || isRestore) return;
    try {
      _capture(
        'purchase_success',
        properties: {'plan': plan},
      );
      _purchaseSuccessTracked = true;
      debugPrint('[Analytics] ✅ Purchase Success: $plan');
    } catch (e) {
      debugPrint('[Analytics] trackPurchaseSuccess error: $e');
    }
  }
  
  void trackPurchaseFailed() {
    if (!_initialized) return;
    try {
      _capture('purchase_failed');
      debugPrint('[Analytics] ✅ Purchase Failed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackPurchaseFailed error: $e');
    }
  }
  
  void trackAiTransformationOpened() {
    if (!_initialized) return;
    try {
      _capture('ai_transformation_opened');
      debugPrint('[Analytics] ✅ AI Transformation Opened tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationOpened error: $e');
    }
  }
  
  void trackAiTransformationUploadStarted() {
    if (!_initialized) return;
    try {
      _capture('ai_transformation_upload_started');
      debugPrint('[Analytics] ✅ AI Transformation Upload Started tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationUploadStarted error: $e');
    }
  }

  void trackAiTransformationUploadCompleted() {
    if (!_initialized) return;
    try {
      _capture('ai_transformation_upload_completed');
      debugPrint('[Analytics] ✅ AI Transformation Upload Completed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationUploadCompleted error: $e');
    }
  }

  void trackAiTransformationPaywallViewed() {
    if (!_initialized) return;
    try {
      _capture('ai_transformation_paywall_viewed');
      debugPrint('[Analytics] ✅ AI Transformation Paywall Viewed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationPaywallViewed error: $e');
    }
  }

  void trackAiTransformationGenerated({
    required String source,
    required String goal,
    required int weeks,
    required int generationTimeSeconds,
  }) {
    if (!_initialized) return;
    try {
      _capture(
        'ai_transformation_generated',
        properties: {
          'source': source,
          'goal': goal,
          'weeks': weeks,
          'generation_time_seconds': generationTimeSeconds,
        },
      );
      debugPrint('[Analytics] ✅ AI Transformation Generated tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationGenerated error: $e');
    }
  }

  void trackAiTransformationFailed({
    required String source,
    required String goal,
    required int weeks,
    required int generationTimeSeconds,
    required String errorMessage,
  }) {
    if (!_initialized) return;
    try {
      _capture(
        'ai_transformation_failed',
        properties: {
          'source': source,
          'goal': goal,
          'weeks': weeks,
          'generation_time_seconds': generationTimeSeconds,
          'error_message': errorMessage,
        },
      );
      debugPrint('[Analytics] ✅ AI Transformation Failed tracked');
    } catch (e) {
      debugPrint('[Analytics] trackAiTransformationFailed error: $e');
    }
  }

  void trackEvent(String eventName, [Map<String, dynamic>? properties]) {
    if (!_initialized) return;
    try {
      _capture(eventName, properties: properties);
      debugPrint('[Analytics] ✅ Event Tracked: $eventName');
    } catch (e) {
      debugPrint('[Analytics] trackEvent error: $eventName - $e');
    }
  }
}
