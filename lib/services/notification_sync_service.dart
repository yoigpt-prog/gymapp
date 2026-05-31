import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'onesignal_tag_service.dart';
import 'revenue_cat_service.dart';

class NotificationSyncService {
  static final NotificationSyncService _instance = NotificationSyncService._internal();
  factory NotificationSyncService() => _instance;
  NotificationSyncService._internal();

  final _supabase = Supabase.instance.client;
  bool _isSigningInAnonymously = false;

  static bool _authInitDone = false;
  static Completer<void>? _authInitCompleter;

  /// Call this right after Supabase.initialize to track session recovery.
  static void initializeAuthListener() {
    if (_authInitCompleter != null) return;
    _authInitCompleter = Completer<void>();

    // Listen for the first auth state stream event.
    // The stream will emit initialSession (with session or null) once ready.
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!_authInitDone) {
        _authInitDone = true;
        if (_authInitCompleter?.isCompleted == false) {
          _authInitCompleter?.complete();
        }
      }
    });

    // Safety timeout of 2 seconds to avoid hanging if the stream doesn't emit.
    Future.delayed(const Duration(seconds: 2), () {
      if (!_authInitDone) {
        _authInitDone = true;
        if (_authInitCompleter?.isCompleted == false) {
          _authInitCompleter?.complete();
        }
      }
    });
  }

  /// Wait for Supabase to recover any existing session from storage.
  static Future<void> waitForAuthInit() async {
    if (_authInitCompleter == null) {
      initializeAuthListener();
    }
    await _authInitCompleter!.future;
  }

  Future<User?> ensureAnonymousSession() async {
    // Wait for the auth session recovery to complete before checking/creating session
    await waitForAuthInit();

    if (_isSigningInAnonymously) {
      debugPrint("[NotificationSyncService] Anonymous sign-in already in progress, waiting...");
      int attempts = 0;
      while (_supabase.auth.currentUser == null && attempts < 15) {
        await Future.delayed(const Duration(milliseconds: 300));
        attempts++;
      }
      return _supabase.auth.currentUser;
    }

    var user = _supabase.auth.currentUser;
    if (user == null) {
      _isSigningInAnonymously = true;
      try {
        debugPrint("[NotificationSyncService] Calling signInAnonymously...");
        final response = await _supabase.auth.signInAnonymously();
        user = response.user;
        debugPrint("[NotificationSyncService] signInAnonymously complete. User: ${user?.id}");
      } catch (e) {
        debugPrint("[NotificationSyncService] Error during signInAnonymously: $e");
      } finally {
        _isSigningInAnonymously = false;
      }
    }
    return user;
  }

  /// Sync all relevant state for notifications
  /// Call this on app open or when major state changes (quiz finish, purchase)
  Future<void> syncFullState() async {
    debugPrint("[NotificationSyncService] Starting syncFullState...");

    // 1. Establish session if not exists (on mobile)
    var user = _supabase.auth.currentUser;
    if (user == null && !kIsWeb) {
      user = await ensureAnonymousSession();
    }

    final userId = user?.id ?? _supabase.auth.currentUser?.id;
    debugPrint("[NotificationSyncService] Current User ID: $userId");

    if (userId == null) {
      debugPrint("[NotificationSyncService] Cannot sync: User ID is null.");
      return;
    }

    // 2. Get local timezone
    String currentTimeZone = 'UTC';
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      if (tzResult is String) {
        currentTimeZone = tzResult;
      } else {
        try {
          currentTimeZone = tzResult.identifier;
        } catch (_) {
          currentTimeZone = tzResult.toString();
        }
      }
      debugPrint("[NotificationSyncService] Local Timezone: $currentTimeZone");
    } catch (e) {
      debugPrint("[NotificationSyncService] Error getting timezone: $e");
    }

    // 3. Get OneSignal subscription id (if on mobile)
    String? oneSignalSubId;
    if (!kIsWeb) {
      try {
        oneSignalSubId = OneSignal.User.pushSubscription.id;
        debugPrint("[NotificationSyncService] OneSignal Subscription ID: $oneSignalSubId");
      } catch (e) {
        debugPrint("[NotificationSyncService] Error getting OneSignal subscription ID: $e");
      }
    }

    // 4. UPSERT notification_preferences (No premium requirement here!)
    try {
      debugPrint("[NotificationSyncService] Attempting to upsert notification preferences...");
      await _supabase.from('notification_preferences').upsert({
        'user_id': userId,
        'workout_reminders': true,
        'meal_reminders': true,
        'hydration_reminders': true,
        'sleep_reminders': true,
        'motivation_reminders': true,
        'timezone': currentTimeZone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint("[NotificationSyncService] Upsert SUCCESS for user_id: $userId");
    } catch (e) {
      debugPrint("[NotificationSyncService] Upsert ERROR for user_id: $userId - Error: $e");
    }

    // 5. OneSignal login & tag sync (Mobile only)
    if (!kIsWeb) {
      try {
        debugPrint("[NotificationSyncService] Logging into OneSignal...");
        await OneSignalTagService().login(userId);

        // Fetch user state from Supabase to construct tags
        bool quizStarted = false;
        bool quizCompleted = false;
        try {
          final prefs = await _supabase
              .from('user_preferences')
              .select('quiz_started, quiz_completed')
              .eq('user_id', userId)
              .maybeSingle();
          if (prefs != null) {
            quizStarted = prefs['quiz_started'] ?? false;
            quizCompleted = prefs['quiz_completed'] ?? false;
          }
        } catch (e) {
          debugPrint("[NotificationSyncService] Error fetching user_preferences: $e");
        }

        // Get Premium status (keep RevenueCat logic unchanged)
        bool isPremium = false;
        try {
          isPremium = await RevenueCatService().isProUser();
          
          // Sync premium status to database for Smart Notifications edge function
          await _supabase.from('user_preferences').update({
            'premium': isPremium,
          }).eq('user_id', userId);
        } catch (e) {
          debugPrint("[NotificationSyncService] Error fetching RevenueCat status: $e");
        }

        // Build tags
        final Map<String, dynamic> tags = {
          'user_id': userId,
          'timezone': currentTimeZone,
          'premium': isPremium.toString(),
          'quiz_started': quizStarted.toString(),
          'quiz_completed': quizCompleted.toString(),
          'last_active_date': DateTime.now().toIso8601String().split('T')[0],
        };

        debugPrint("[NotificationSyncService] Syncing OneSignal tags: $tags");
        await OneSignalTagService().syncTags(tags);
        debugPrint("[NotificationSyncService] Tag sync SUCCESS");
      } catch (e) {
        debugPrint("[NotificationSyncService] Tag sync ERROR: $e");
      }
    }
  }

  Future<Map<String, dynamic>?> getNotificationPreferences() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint("[NotificationSyncService] Error getting prefs: $e");
      return null;
    }
  }

  Future<void> updateNotificationPreferences(Map<String, dynamic> updates) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('notification_preferences')
          .update(updates)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint("[NotificationSyncService] Error updating prefs: $e");
    }
  }
}
