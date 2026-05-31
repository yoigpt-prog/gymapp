import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../utils/web_notifications_helper.dart';

class OneSignalTagService {
  static final OneSignalTagService _instance = OneSignalTagService._internal();
  factory OneSignalTagService() => _instance;
  OneSignalTagService._internal();

  /// Syncs tags to OneSignal
  Future<void> syncTags(Map<String, dynamic> tags) async {
    if (kIsWeb) {
      webOneSignalSyncTags(tags);
      return;
    }

    try {
      final filteredTags = <String, String>{};
      tags.forEach((key, value) {
        if (value != null) {
          filteredTags[key] = value.toString();
        }
      });

      if (filteredTags.isNotEmpty) {
        await OneSignal.User.addTags(filteredTags);
        debugPrint("[OneSignalTagService] Tags synced: $filteredTags");
      }
    } catch (e) {
      debugPrint("[OneSignalTagService] Error syncing tags: $e");
    }
  }

  /// Remove specific tags
  Future<void> removeTags(List<String> keys) async {
    if (kIsWeb) return;
    try {
      await OneSignal.User.removeTags(keys);
      debugPrint("[OneSignalTagService] Tags removed: $keys");
    } catch (e) {
      debugPrint("[OneSignalTagService] Error removing tags: $e");
    }
  }

  /// Set the user's external ID (usually their Supabase user_id)
  Future<void> login(String userId) async {
    if (kIsWeb) {
      webOneSignalLogin(userId);
      return;
    }
    try {
      await OneSignal.login(userId);
      debugPrint("[OneSignalTagService] User logged in to OneSignal: $userId");
    } catch (e) {
      debugPrint("[OneSignalTagService] Error logging in: $e");
    }
  }

  /// Logout of OneSignal
  Future<void> logout() async {
    if (kIsWeb) {
      webOneSignalLogout();
      return;
    }
    try {
      await OneSignal.logout();
      debugPrint("[OneSignalTagService] User logged out of OneSignal");
    } catch (e) {
      debugPrint("[OneSignalTagService] Error logging out: $e");
    }
  }
}
