// Web override — compiled ONLY when dart.library.html is available (Flutter Web).
// Loaded via: import 'analytics_service_stub.dart'
//                 if (dart.library.html) 'analytics_service_web.dart'
// Uses package:web (not deprecated dart:html) for userAgent access.
import 'package:web/web.dart' as web;

/// Returns the browser's user-agent string.
String getUserAgent() {
  try {
    return web.window.navigator.userAgent;
  } catch (_) {
    return '';
  }
}
