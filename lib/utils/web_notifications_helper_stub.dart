/// Stub — no-op on non-web platforms.
bool isDesktopWeb() => false;
bool isAndroidChrome() => false;
bool isIOS() => false;
bool isInAppBrowser() => false;
bool supportsWebPush() => false;
bool isWebSubscribed() => false;
bool isWebPermissionDenied() => false;
void requestWebNotificationPermission() {}
void webOneSignalLogin(String userId) {}
void webOneSignalLogout() {}
void webOneSignalSyncTags(Map<String, dynamic> tags) {}
