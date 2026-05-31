import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/material.dart';
import 'analytics_service.dart';
import 'revenue_cat_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  bool _isInitialized = false;

  /// Initialize OneSignal. 
  /// This should be called in main.dart safely.
  Future<void> initialize(GlobalKey<NavigatorState>? navigatorKey) async {
    if (_isInitialized) return;
    if (kIsWeb) return; // OneSignal Flutter SDK does not fully support Web right now or needs different setup

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      OneSignal.initialize("835968ac-39d8-4125-9246-fe243ba89e35");

      // Handle notification clicks
      OneSignal.Notifications.addClickListener((event) {
        AnalyticsService().trackEvent('Push Notification Opened');
        final data = event.notification.additionalData;
        if (data != null && data['route'] != null) {
          final route = data['route'] as String;
          _handleRouting(route, navigatorKey);
        }
      });

      _isInitialized = true;
      debugPrint("[PushNotificationService] Initialized safely");
    } catch (e) {
      debugPrint("[PushNotificationService] Error initializing OneSignal: $e");
    }
  }

  void _handleRouting(String route, GlobalKey<NavigatorState>? navigatorKey) async {
    debugPrint("[PushNotificationService] Routing to $route");
    
    // Wait for the navigator to be ready if the app was killed
    int retries = 0;
    while (navigatorKey?.currentState == null && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }

    if (navigatorKey?.currentState == null) {
      debugPrint("[PushNotificationService] Navigator not ready, aborting route");
      return;
    }

    final validRoutes = ['/onboarding', '/home', '/ai-transformation-simulator', '/rate-your-body', '/meal-plan'];
    
    if (route == '/paywall') {
      RevenueCatService().showPaywall();
      return;
    }

    if (validRoutes.contains(route)) {
      navigatorKey!.currentState?.pushNamed(route);
    } else {
      navigatorKey!.currentState?.pushNamed('/home');
    }
  }
}
