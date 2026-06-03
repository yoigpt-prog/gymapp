import 'dart:js_interop' as js;
import 'package:flutter/foundation.dart';

@js.JS('setExerciseSEO')
external void _setExerciseSEO(js.JSString title, js.JSString description, js.JSString canonicalUrl, js.JSString schemaJson);

void setExerciseSEO(String title, String description, String canonicalUrl, String schemaJson) {
  try {
    _setExerciseSEO(title.toJS, description.toJS, canonicalUrl.toJS, schemaJson.toJS);
  } catch (e) {
    debugPrint('Error injecting SEO via JS: $e');
  }
}
