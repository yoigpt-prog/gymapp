import 'package:flutter/services.dart';
void main() {
  SystemNavigator.routeInformationUpdated(location: '/test');
  SystemNavigator.routeInformationUpdated(uri: Uri.parse('/test'));
}
