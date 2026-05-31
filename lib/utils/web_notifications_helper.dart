// Conditional export: uses web-specific APIs on web, stub elsewhere.
export 'web_notifications_helper_stub.dart'
    if (dart.library.html) 'web_notifications_helper_web.dart';
