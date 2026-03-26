// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Navigates the current browser tab to [url] (same-tab, like a redirect).
void openUrlSameTab(String url) {
  html.window.location.assign(url);
}
