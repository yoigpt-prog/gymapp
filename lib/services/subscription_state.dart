import 'package:flutter/foundation.dart';
import 'revenue_cat_service.dart';

/// Lightweight subscription state cache so individual widgets don't each
/// need to make async RevenueCat calls on every build.
///
/// Usage:
///   await SubscriptionState().refresh();
///   final isPro = SubscriptionState().isPro;
///
/// Widgets can also listen for changes:
///   SubscriptionState().addListener(() => setState(() {}));
class SubscriptionState extends ChangeNotifier {
  static final SubscriptionState _instance = SubscriptionState._internal();
  factory SubscriptionState() => _instance;
  SubscriptionState._internal();

  bool _isPro = false;
  bool _hasChecked = false;

  /// Returns the cached subscription status.
  bool get isPro => _isPro;

  bool get hasChecked => _hasChecked;

  /// Fetches fresh status from RevenueCat and notifies listeners.
  Future<void> refresh() async {
    try {
      final result = await RevenueCatService().isProUser();
      if (_isPro != result || !_hasChecked) {
        _isPro = result;
        _hasChecked = true;
        notifyListeners();
      } else {
        _hasChecked = true;
      }
    } catch (e) {
      debugPrint('[SubscriptionState] refresh error: $e');
      _hasChecked = true;
    }
  }

  /// Call this after a successful purchase or restore to immediately
  /// update all listening widgets.
  void markPro() {
    if (!_isPro) {
      _isPro = true;
      _hasChecked = true;
      notifyListeners();
    }
  }

  /// Call on sign-out to reset the cached state.
  void reset() {
    _isPro = false;
    _hasChecked = false;
    notifyListeners();
  }
}
