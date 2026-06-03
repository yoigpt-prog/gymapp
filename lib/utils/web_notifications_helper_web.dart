// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:convert';
import 'package:web/web.dart' as web;

bool isDesktopWeb() {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    final isMobile = ua.contains('mobi') || 
                     ua.contains('android') || 
                     ua.contains('iphone') || 
                     ua.contains('ipad') || 
                     ua.contains('ipod') ||
                     (web.window.navigator.platform.toLowerCase().contains('mac') && web.window.navigator.maxTouchPoints > 0);
    return !isMobile;
  } catch (_) {
    return false;
  }
}

bool isAndroidChrome() {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('android') && (ua.contains('chrome') || ua.contains('chromium')) && !isInAppBrowser();
  } catch (_) {
    return false;
  }
}

bool isIOS() {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    final isMacIntel = web.window.navigator.platform.toLowerCase().contains('mac');
    final hasTouch = web.window.navigator.maxTouchPoints > 0;
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod') || (isMacIntel && hasTouch);
  } catch (_) {
    return false;
  }
}

bool isIOSSafari() {
  if (!isIOS()) return false;
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return !ua.contains('crios') && !ua.contains('fxios') && !ua.contains('edgios');
  } catch (_) {
    return false;
  }
}

bool isInAppBrowser() {
  try {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('fbav') || 
           ua.contains('instagram') || 
           ua.contains('tiktok') || 
           ua.contains('snapchat') || 
           ua.contains('twitter') || 
           ua.contains('wechat') || 
           ua.contains('micromessenger') ||
           ua.contains('line');
  } catch (_) {
    return false;
  }
}

bool supportsWebPush() {
  try {
    return js.context.callMethod('eval', [
      'typeof window.Notification !== "undefined" && typeof navigator.serviceWorker !== "undefined"'
    ]) as bool;
  } catch (_) {
    return false;
  }
}

bool isWebSubscribed() {
  try {
    final hasSDKOptedIn = js.context.callMethod('eval', [
      'window.OneSignal && window.OneSignal.User && window.OneSignal.User.PushSubscription ? window.OneSignal.User.PushSubscription.optedIn : null'
    ]);
    if (hasSDKOptedIn is bool) {
      return hasSDKOptedIn;
    }
    final status = js.context.callMethod('eval', ['Notification.permission']) as String;
    return status == 'granted';
  } catch (_) {
    return false;
  }
}

/// Check if the browser permission for notifications is denied
bool isWebPermissionDenied() {
  try {
    final status = js.context.callMethod('eval', ['Notification.permission']) as String;
    return status == 'denied';
  } catch (_) {
    return false;
  }
}

/// Programmatically trigger the OneSignal push notification prompt on web.
void requestWebNotificationPermission() {
  try {
    js.context.callMethod('eval', [
      'if (window.OneSignal) { '
      '  console.log("[OneSignal] Opting in user to push notifications synchronously."); '
      '  if (window.OneSignal.User && window.OneSignal.User.PushSubscription && typeof window.OneSignal.User.PushSubscription.optIn === "function") { '
      '    window.OneSignal.User.PushSubscription.optIn(); '
      '  } else if (typeof window.OneSignal.optIn === "function") { '
      '    window.OneSignal.optIn(); '
      '  } else if (window.OneSignal.Notifications && typeof window.OneSignal.Notifications.requestPermission === "function") { '
      '    window.OneSignal.Notifications.requestPermission(); '
      '  } '
      '} else { '
      '  console.log("[OneSignal] OneSignal not loaded yet, pushing opt-in request to deferred queue."); '
      '  window.OneSignalDeferred = window.OneSignalDeferred || []; '
      '  window.OneSignalDeferred.push(function(OneSignal) { '
      '    if (OneSignal.User && OneSignal.User.PushSubscription && typeof OneSignal.User.PushSubscription.optIn === "function") { '
      '      OneSignal.User.PushSubscription.optIn(); '
      '    } else if (typeof OneSignal.optIn === "function") { '
      '      OneSignal.optIn(); '
      '    } else { '
      '      OneSignal.Notifications.requestPermission(); '
      '    } '
      '  }); '
      '}'
    ]);
  } catch (_) {
    // Fail silently
  }
}

/// Log in a user on web to OneSignal
void webOneSignalLogin(String userId) {
  try {
    js.context.callMethod('eval', [
      'if (window.OneSignal) { '
      '  console.log("[OneSignal] Logging in user: ' + userId + '"); '
      '  window.OneSignal.login("' + userId + '"); '
      '} else { '
      '  window.OneSignalDeferred = window.OneSignalDeferred || []; '
      '  window.OneSignalDeferred.push(function(OneSignal) { '
      '    OneSignal.login("' + userId + '"); '
      '  }); '
      '}'
    ]);
  } catch (_) {
    // Fail silently
  }
}

/// Log out a user on web from OneSignal
void webOneSignalLogout() {
  try {
    js.context.callMethod('eval', [
      'if (window.OneSignal) { '
      '  console.log("[OneSignal] Logging out user"); '
      '  window.OneSignal.logout(); '
      '} else { '
      '  window.OneSignalDeferred = window.OneSignalDeferred || []; '
      '  window.OneSignalDeferred.push(function(OneSignal) { '
      '    OneSignal.logout(); '
      '  }); '
      '}'
    ]);
  } catch (_) {
    // Fail silently
  }
}

/// Sync tags on web to OneSignal
void webOneSignalSyncTags(Map<String, dynamic> tags) {
  try {
    final jsonStr = jsonEncode(tags);
    js.context.callMethod('eval', [
      'var tags = ' + jsonStr + '; '
      'if (window.OneSignal && window.OneSignal.User) { '
      '  console.log("[OneSignal] Syncing tags:", tags); '
      '  window.OneSignal.User.addTags(tags); '
      '} else { '
      '  window.OneSignalDeferred = window.OneSignalDeferred || []; '
      '  window.OneSignalDeferred.push(function(OneSignal) { '
      '    OneSignal.User.addTags(tags); '
      '  }); '
      '}'
    ]);
  } catch (_) {
    // Fail silently
  }
}
