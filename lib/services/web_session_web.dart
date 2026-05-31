import 'dart:html' as html;

class WebSession {


  static bool get isDesktopWebAppOpenTracked {
    return html.window.sessionStorage['gymguide_desktop_web_app_open_tracked'] == 'true';
  }

  static void setDesktopWebAppOpenTracked() {
    html.window.sessionStorage['gymguide_desktop_web_app_open_tracked'] = 'true';
  }

  static String get currentUrl => html.window.location.href;
  static String get pagePath => html.window.location.pathname ?? '';
  static String get referrer => html.document.referrer;
  static String get browser => html.window.navigator.userAgent;
}
