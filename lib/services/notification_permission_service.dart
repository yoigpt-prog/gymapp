import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'analytics_service.dart';
import '../utils/web_notifications_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'notification_sync_service.dart';

class NotificationPermissionService {
  static final NotificationPermissionService _instance = NotificationPermissionService._internal();
  factory NotificationPermissionService() => _instance;
  NotificationPermissionService._internal();

  /// Request push permission safely
  /// Only call this after onboarding quiz started or completed
  Future<void> requestPermission([BuildContext? context, bool isManual = false]) async {
    if (kIsWeb) {
      _handleWebPermission(context, isManual);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasRequested = prefs.getBool('push_permission_requested') ?? false;

    if (hasRequested) {
      debugPrint("[NotificationPermissionService] Permission already requested previously.");
      return;
    }

    try {
      debugPrint("[NotificationPermissionService] Requesting Push Permissions");
      AnalyticsService().trackEvent('Push Permission Requested');

      final accepted = await OneSignal.Notifications.requestPermission(true);

      await prefs.setBool('push_permission_requested', true);

      if (accepted) {
        debugPrint("[NotificationPermissionService] Permission Accepted");
        AnalyticsService().trackEvent('Push Permission Accepted');
        unawaited(NotificationSyncService().syncFullState());
      } else {
        debugPrint("[NotificationPermissionService] Permission Denied");
        AnalyticsService().trackEvent('Push Permission Denied');
      }
    } catch (e) {
      debugPrint("[NotificationPermissionService] Error requesting permission: $e");
    }
  }

  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    return OneSignal.Notifications.permission;
  }

  void _handleWebPermission(BuildContext? context, bool isManual) {
    if (context == null) {
      if (isDesktopWeb()) {
        requestWebNotificationPermission();
      }
      return;
    }
    maybeShowWebPushBrandedPrompt(context, isManual: isManual);
  }

  Future<void> maybeShowWebPushBrandedPrompt(BuildContext context, {bool isManual = false}) async {
    if (!kIsWeb) return;

    if (isInAppBrowser()) {
      _showInstallAppDialog(
        context,
        title: "Reminders & Full Experience",
        message: "In-app browsers (like TikTok, Instagram, or Facebook) do not support browser push notifications. "
            "Please download the Gym Guide mobile app for workout reminders, meal plans, and the full experience.",
      );
      return;
    }

    if (isIOS()) {
      if (!isManual && isIOSSafari()) return;
      
      _showInstallAppDialog(
        context,
        title: "Install Gym Guide App",
        message: "iOS Safari does not support native web push notifications directly without adding the app to your Home Screen. "
            "For instant workout reminders and the best performance, download the mobile app.\n\n"
            "Alternatively, tap the Share button (up-arrow) and select 'Add to Home Screen' to enable reminders.",
        optionalText: "Install the app for reminders and full experience.",
      );
      return;
    }

    if (!supportsWebPush()) {
      _showInstallAppDialog(
        context,
        title: "Notifications Unsupported",
        message: "Your current browser does not support push notifications. "
            "Download the Gym Guide mobile app to get daily workout reminders and meal plan updates.",
      );
      return;
    }

    // 1. Check if already subscribed
    if (isWebSubscribed()) {
      debugPrint("[NotificationPermissionService] Web user already subscribed, ignoring prompt.");
      return;
    }

    // 2. Check if dismissed in last 7 days
    final prefs = await SharedPreferences.getInstance();
    final dismissedAtStr = prefs.getString('gg_web_push_dismissed_at');
    if (dismissedAtStr != null) {
      try {
        final dismissedAt = DateTime.parse(dismissedAtStr);
        final diff = DateTime.now().difference(dismissedAt);
        if (diff.inDays < 7) {
          debugPrint("[NotificationPermissionService] Branded prompt dismissed recently ($diff ago), suppressing.");
          return;
        }
      } catch (e) {
        debugPrint("Error parsing gg_web_push_dismissed_at: $e");
      }
    }

    // 3. Show custom premium branded dialog
    if (context.mounted) {
      _showBrandedPushDialog(context);
    }
  }

  void _showBrandedPushDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth <= 600;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: isMobile ? screenWidth * 0.90 : 420.0,
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: const Color(0xFF121212), // Black background accents
                borderRadius: BorderRadius.circular(24.0), // Rounded corners
                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 12), // Soft shadow
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // GymGuide brand logo SVG
                  SvgPicture.asset(
                    'assets/svg/logo/popuplogo.svg',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  // Title
                  const Text(
                    "Subscribe to our notifications for the latest news and updates.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.white, // White text
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Subtitle
                  Text(
                    "You can disable anytime.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.65), // White subtle text
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Buttons (Column layout)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subscribe Primary Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isWebPermissionDenied()) {
                              Navigator.of(context).pop();
                              _showPermissionDeniedDialog(context);
                            } else {
                              requestWebNotificationPermission();
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000), // Primary Red
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0),
                            ),
                            elevation: 8,
                            shadowColor: const Color(0xFFFF0000).withOpacity(0.4),
                          ),
                          child: const Text(
                            "Subscribe",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Not Now Secondary Ghost Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'gg_web_push_dismissed_at',
                              DateTime.now().toIso8601String(),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0),
                            ),
                          ),
                          child: const Text(
                            "Not Now",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInstallAppDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? optionalText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.cloud_download_outlined, color: Color(0xFFE53935), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (optionalText != null) ...[
                const SizedBox(height: 14),
                Text(
                  optionalText,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.only(bottom: 12, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                "Close",
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse('https://www.gymguide.co/download');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (_) {}
              },
              child: const Text("Download App", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF0000), size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Notifications Blocked",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "It looks like notifications are blocked for Gym Guide in your browser settings.\n\n"
            "To subscribe, please click the site settings icon (lock/tune icon) in your browser's address bar and change the Notifications permission to 'Allow'.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.only(bottom: 12, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "Got It",
                style: TextStyle(
                  color: Color(0xFFFF0000),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
