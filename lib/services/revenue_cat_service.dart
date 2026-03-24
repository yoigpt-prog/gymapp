import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Singleton service wrapping the RevenueCat SDK.
/// All public methods are safe to call on Web (they become no-ops / return defaults).
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // ── API Keys ──────────────────────────────────────────────────────────────────
  static const String _appleApiKey  = 'appl_YSEYSBfPJHpLwtZFnHIzohFtPsS';
  static const String _googleApiKey = 'goog_iqpkVagCcGjOpwaOybvQvsmTiLh';

  // ── Config ────────────────────────────────────────────────────────────────────
  static const String _entitlement  = 'premium';
  static const String _offeringId   = 'paywellgymguidev2';

  bool _initialized = false;

  // ── Initialization ────────────────────────────────────────────────────────────

  /// Must be called once from main() before any other method.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[RC] Web platform — SDK not supported. Skipping init.');
      return;
    }
    if (_initialized) {
      debugPrint('[RC] Already initialized — skipping.');
      return;
    }

    try {
      // Enable verbose logging to diagnose Error 23 / product issues.
      await Purchases.setLogLevel(LogLevel.debug);

      final String apiKey;
      if (Platform.isAndroid) {
        apiKey = _googleApiKey;
        debugPrint('[RC] Platform: Android — using Google API key.');
      } else if (Platform.isIOS) {
        apiKey = _appleApiKey;
        debugPrint('[RC] Platform: iOS — using Apple API key.');
      } else {
        debugPrint('[RC] Unsupported platform. RevenueCat not initialized.');
        return;
      }

      final configuration = PurchasesConfiguration(apiKey);

      await Purchases.configure(configuration);
      _initialized = true;
      debugPrint('[RC] ✅ SDK initialized successfully.');

      // Eagerly warm the offerings cache so the first paywall open is instant.
      await _warmOfferingsCache();
    } catch (e, st) {
      debugPrint('[RC] ❌ Initialization error: $e\n$st');
    }
  }

  /// Fetches offerings immediately after init to pre-populate the SDK cache.
  /// Errors here are non-fatal — the paywall call will retry.
  Future<void> _warmOfferingsCache() async {
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('[RC] Cache warm — all offerings: ${offerings.all.keys.toList()}');
      debugPrint('[RC] Cache warm — current: ${offerings.current?.identifier ?? "NONE"}');
    } catch (e) {
      debugPrint('[RC] Cache warm failed (non-fatal): $e');
    }
  }

  // ── Auth Sync ─────────────────────────────────────────────────────────────────

  /// Call after Supabase login with the authenticated user's ID.
  Future<void> login(String userId) async {
    if (kIsWeb || !_initialized) return;
    try {
      final result = await Purchases.logIn(userId);
      debugPrint('[RC] Logged in as: ${result.customerInfo.originalAppUserId}');
    } catch (e) {
      debugPrint('[RC] Login error: $e');
    }
  }

  /// Call after the user signs out.
  Future<void> logout() async {
    if (kIsWeb || !_initialized) return;
    try {
      await Purchases.logOut();
      debugPrint('[RC] Logged out.');
    } catch (e) {
      debugPrint('[RC] Logout error: $e');
    }
  }

  // ── Entitlement Checking ──────────────────────────────────────────────────────

  /// Returns true if the user has the "premium" entitlement active.
  /// Always returns true on Web so development is not blocked.
  Future<bool> isProUser() async {
    if (kIsWeb) return true;
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      final hasPro = info.entitlements.active.containsKey(_entitlement);
      debugPrint('[RC] isProUser → $hasPro (active: ${info.entitlements.active.keys.toList()})');
      return hasPro;
    } catch (e) {
      debugPrint('[RC] isProUser error: $e');
      return false;
    }
  }

  // ── Offering Fetch ────────────────────────────────────────────────────────────

  /// Fetches the target offering with a single automatic retry.
  ///
  /// Resolution order:
  ///   1. Named offering "$_offeringId"
  ///   2. Current (default) offering
  ///   3. null  → dashboard configuration issue
  Future<Offering?> _getTargetOffering({bool retried = false}) async {
    try {
      final offerings = await Purchases.getOfferings();

      // ── Full diagnostics ──────────────────────────────────────────────────────
      debugPrint('[RC] All offering keys  : ${offerings.all.keys.toList()}');
      debugPrint('[RC] Current offering   : ${offerings.current?.identifier ?? "NONE"}');
      for (final entry in offerings.all.entries) {
        debugPrint('[RC]   "${entry.key}" → ${entry.value.availablePackages.length} package(s)');
      }

      // 1. Named offering
      final named = offerings.getOffering(_offeringId);
      if (named != null) {
        if (named.availablePackages.isEmpty) {
          debugPrint('[RC] ⚠️  Offering "$_offeringId" has 0 packages — check product IDs in dashboard.');
        } else {
          debugPrint('[RC] ✅ Using offering "$_offeringId" with ${named.availablePackages.length} package(s).');
        }
        return named;
      }

      // 2. Fallback to current
      if (offerings.current != null) {
        debugPrint('[RC] Named offering "$_offeringId" not found. Falling back to current: "${offerings.current!.identifier}".');
        return offerings.current;
      }

      // 3. Retry once — Android Play Billing can return empty on the first call
      if (!retried) {
        debugPrint('[RC] No offerings on first attempt. Retrying in 2 s…');
        await Future.delayed(const Duration(seconds: 2));
        return _getTargetOffering(retried: true);
      }

      debugPrint(
        '[RC] ❌ No offerings found after retry.\n'
        '    Possible causes:\n'
        '      • Offering "$_offeringId" is not live/published on RevenueCat dashboard.\n'
        '      • Products (gym_guide_weekly / gym_guide_yearly) are not linked to the offering.\n'
        '      • Products are not approved / published on Google Play Console.\n'
        '      • Google API key mismatch.\n'
        '    Fix: Dashboard → Products → Offerings → attach products and publish.',
      );
      return null;
    } catch (e) {
      debugPrint('[RC] getOfferings error: $e');
      return null;
    }
  }

  // ── Paywall UI ────────────────────────────────────────────────────────────────

  /// Shows paywall ONLY if the user does NOT already have the premium entitlement.
  /// Returns null if the user is already premium or if the paywall cannot be shown.
  Future<PaywallResult?> presentPaywallIfNeeded() async {
    if (kIsWeb || !_initialized) return null;

    try {
      final info = await Purchases.getCustomerInfo();
      final hasEntitlement = info.entitlements.active.containsKey(_entitlement);
      debugPrint('[RC] presentPaywallIfNeeded — has "$_entitlement": $hasEntitlement');

      if (hasEntitlement) {
        debugPrint('[RC] User already has premium — skipping paywall.');
        return PaywallResult.purchased;
      }

      return await showPaywall();
    } catch (e) {
      debugPrint('[RC] presentPaywallIfNeeded error: $e');
      return null;
    }
  }

  /// Manually presents the paywall regardless of entitlement status.
  /// Uses RevenueCatUI auto-resolve (no explicit offering) to avoid Error 23.
  Future<PaywallResult?> showPaywall() async {
    if (kIsWeb || !_initialized) return null;

    debugPrint('[RC] showPaywall() called — verifying offerings before presentation…');

    try {
      // Fetch offerings first to ensure store is available (prevents Error 2 on emulators)
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null || offerings.current!.availablePackages.isEmpty) {
        debugPrint('[RC] No active offerings found. Skipping Paywall to prevent Error 2.');
        return null;
      }

      debugPrint('[RC] Offerings verified. Presenting paywall (auto-resolve)…');
      final result = await RevenueCatUI.presentPaywall();
      debugPrint('[RC] Paywall result: $result');
      return result;
    } catch (e) {
      debugPrint('[RC] presentPaywall error (store possibly unavailable): $e');
      return null;
    }
  }

  // ── Customer Info ─────────────────────────────────────────────────────────────

  /// Fetches raw customer info. Returns null on Web or error.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (kIsWeb || !_initialized) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('[RC] getCustomerInfo error: $e');
      return null;
    }
  }

  // ── Restore Purchases ─────────────────────────────────────────────────────────

  /// Restores past purchases and returns updated CustomerInfo.
  Future<CustomerInfo?> restorePurchases() async {
    if (kIsWeb || !_initialized) return null;
    try {
      final info = await Purchases.restorePurchases();
      debugPrint('[RC] Restore complete. Active entitlements: ${info.entitlements.active.keys.toList()}');
      return info;
    } catch (e) {
      debugPrint('[RC] restorePurchases error: $e');
      return null;
    }
  }

  // ── Debug Utility ─────────────────────────────────────────────────────────────

  /// Call this from a debug button or initState to print a full RevenueCat health report.
  Future<void> checkRevenueCatSetup() async {
    debugPrint('══════════════ RevenueCat Setup Check ══════════════');

    if (kIsWeb) {
      debugPrint('[RC] Web platform — SDK not available.');
      debugPrint('════════════════════════════════════════════════════');
      return;
    }
    if (!_initialized) {
      debugPrint('[RC] ❌ SDK not initialized! Call initialize() first.');
      debugPrint('════════════════════════════════════════════════════');
      return;
    }

    // Entitlement status
    try {
      final info = await Purchases.getCustomerInfo();
      debugPrint('[RC] App User ID       : ${info.originalAppUserId}');
      debugPrint('[RC] Active entitlements: ${info.entitlements.active.keys.toList()}');
      debugPrint('[RC] Has "$_entitlement"  : ${info.entitlements.active.containsKey(_entitlement)}');
    } catch (e) {
      debugPrint('[RC] CustomerInfo error: $e');
    }

    // Offerings
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('[RC] All offerings     : ${offerings.all.keys.toList()}');
      debugPrint('[RC] Current offering  : ${offerings.current?.identifier ?? "NONE"}');
      for (final entry in offerings.all.entries) {
        final pkgs = entry.value.availablePackages.map((p) => p.identifier).toList();
        debugPrint('[RC]   "${entry.key}" → packages: $pkgs');
      }

      final target = offerings.getOffering(_offeringId);
      if (target != null) {
        debugPrint('[RC] Target "$_offeringId" ✅ found — ${target.availablePackages.length} package(s)');
      } else {
        debugPrint('[RC] Target "$_offeringId" ❌ NOT found in offerings map!');
        debugPrint('[RC]   → Ensure it is published on the RevenueCat dashboard.');
      }
    } catch (e) {
      debugPrint('[RC] Offerings error: $e');
    }

    debugPrint('════════════════════════════════════════════════════');
  }
}
