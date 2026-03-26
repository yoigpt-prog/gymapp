/// Conditional export: uses dart:html on web, no-op stub elsewhere.
export 'platform_url_stub.dart'
    if (dart.library.html) 'platform_url_web.dart';
