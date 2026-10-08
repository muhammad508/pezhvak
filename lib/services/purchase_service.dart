import 'package:flutter/foundation.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/inventory.dart';
import 'package:myket_iap/util/purchase.dart';
import 'package:pezhvak/services/services.dart';

/// Subscription product IDs on Myket
const String skuMonthly = '1m';
const String skuYearly = 'y1';

/// Subscription length in days (includes one bonus day)
const int _durationMonthly = 31;
const int _durationYearly = 366;

/// Myket public RSA key, injected at build time so it is not committed:
/// `flutter run --dart-define-from-file=dart_defines.json` (see README).
/// Purchases stay disabled when it is empty.
const String _rsaKey = String.fromEnvironment('MYKET_RSA_KEY');

/// All subscription SKUs
const List<String> _allSubscriptionSkus = [skuMonthly, skuYearly];

/// Myket in-app subscriptions: purchase, restore and expiry calculation (with stacking).
class PurchaseService {
  static bool _initialized = false;

  // ──────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────
  static Future<bool> init() async {
    if (_initialized) return true;
    if (_rsaKey.isEmpty) {
      debugPrint('MYKET_RSA_KEY is not set; in-app purchases are disabled.');
      return false;
    }
    try {
      final result = await MyketIAP.init(
        rsaKey: _rsaKey,
        enableDebugLogging: false,
      );
      _initialized = result?.isSuccess() ?? false;
      return _initialized;
    } catch (e) {
      debugPrint('Myket initialization failed: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // Subscription status (online check combined with local fallback)
  // ──────────────────────────────────────────────
  static Future<DateTime?> checkSubscriptionExpiry() async {
    final onlineExpiry = await _checkOnlineSubscription();
    if (onlineExpiry != null) {
      await PremiumService.setExpiry(onlineExpiry);
      return onlineExpiry;
    }
    return await PremiumService.getExpiry();
  }

  // ──────────────────────────────────────────────
  // Online check against Myket
  // Primary source: the payload of the latest purchase (it carries the real expiry, including stacking)
  // ──────────────────────────────────────────────
  static Future<DateTime?> _checkOnlineSubscription() async {
    if (!_initialized) await init();
    if (!_initialized) return null;

    try {
      final result = await MyketIAP.queryInventory(querySkuDetails: false);
      final inventory = result[MyketIAP.INVENTORY] as Inventory?;
      if (inventory == null) return null;

      // Both SKUs are checked and the later expiry wins (stacking across plans)
      DateTime? bestExpiry;

      for (final sku in _allSubscriptionSkus) {
        final purchase = inventory.mPurchaseMap[sku];
        if (purchase == null) continue;

        // Priority 1: the payload, which holds the real expiry with stacking
        DateTime? expiry = _expiryFromPayload(purchase.mDeveloperPayload);

        // Priority 2: compute from the purchase time (fallback for purchases without a payload)
        expiry ??= _calculateExpiry(sku, purchase.mPurchaseTime);

        if (expiry == null) continue;

        // The latest expiry date wins
        if (bestExpiry == null || expiry.isAfter(bestExpiry)) {
          bestExpiry = expiry;
        }
      }

      if (bestExpiry != null && bestExpiry.isAfter(DateTime.now())) {
        return bestExpiry;
      }
      return null;
    } catch (e) {
      debugPrint('Myket inventory query failed: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // Purchase a subscription (with stacking support)
  // ──────────────────────────────────────────────
  static Future<PurchaseResult> purchase(String sku) async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) {
        return PurchaseResult.error(
            'اتصال به مایکت ممکن نشد. لطفاً مایکت را نصب کنید.');
      }
    }

    try {
      final now = DateTime.now();

      // The current expiry comes from Myket (primary source); local storage is only a fallback
      final onlineExpiry = await _checkOnlineSubscription();
      final currentExpiry = onlineExpiry ?? await PremiumService.getExpiry();

      // base = end of the current subscription (stacking) or right now
      final base = (currentExpiry != null && currentExpiry.isAfter(now))
          ? currentExpiry
          : now;

      // payload = now + new duration + remaining days of the current subscription
      // which equals currentExpiry + new duration
      final newExpiry = _addDuration(sku, base);
      if (newExpiry == null) {
        return PurchaseResult.error('نوع اشتراک نامعتبر است.');
      }

      // payload = pigir_{sku}_{new_expiry_millis}
      final payload = 'pigir_${sku}_${newExpiry.millisecondsSinceEpoch}';

      // If this SKU is already owned, consume it so it can be bought again
      await _consumeIfOwned(sku);

      final result = await MyketIAP.launchPurchaseFlow(
        sku: sku,
        payload: payload,
      );

      final iabResult = result[MyketIAP.RESULT] as IabResult?;
      final purchase = result[MyketIAP.PURCHASE] as Purchase?;

      if (iabResult == null || !iabResult.isSuccess()) {
        return PurchaseResult.error(iabResult?.mMessage ?? 'خطا در پرداخت');
      }

      // Take the expiry from the purchase payload (same as newExpiry); fall back to newExpiry
      final confirmedExpiry =
          _expiryFromPayload(purchase?.mDeveloperPayload) ?? newExpiry;

      await PremiumService.setExpiry(confirmedExpiry);
      return PurchaseResult.success(confirmedExpiry);
    } catch (e) {
      return PurchaseResult.error('خطا در فرآیند پرداخت: ${e.toString()}');
    }
  }

  // ──────────────────────────────────────────────
  // Restore purchases
  // ──────────────────────────────────────────────
  static Future<RestoreResult> restore() async {
    try {
      if (!await init()) {
        return RestoreResult.error('اتصال به مایکت ممکن نشد');
      }

      final expiry = await _checkOnlineSubscription();
      if (expiry != null) {
        await PremiumService.setExpiry(expiry);
        return RestoreResult.success(expiry);
      }
      return RestoreResult.notFound();
    } catch (e) {
      return RestoreResult.error('خطا در بازیابی خرید: ${e.toString()}');
    }
  }

  // ──────────────────────────────────────────────
  // Add a plan's duration to a base date
  // ──────────────────────────────────────────────
  static DateTime? _addDuration(String sku, DateTime base) {
    switch (sku) {
      case skuMonthly:
        return base.add(const Duration(days: _durationMonthly));
      case skuYearly:
        return base.add(const Duration(days: _durationYearly));
      default:
        return null;
    }
  }

  /// Computes the expiry from the Myket purchase time (compatibility with purchases that have no payload)
  static DateTime? _calculateExpiry(String sku, int? purchaseTimeMillis) {
    if (purchaseTimeMillis == null) return null;
    return _addDuration(
      sku,
      DateTime.fromMillisecondsSinceEpoch(purchaseTimeMillis),
    );
  }

  /// Payload format: pigir_{sku}_{expiry_millis}
  static DateTime? _expiryFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('pigir_')) return null;
    final parts = payload.split('_');
    if (parts.length < 3) return null;
    final millis = int.tryParse(parts.last);
    if (millis == null || millis == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  // If the SKU is already owned, consume it so it can be bought again
  static Future<void> _consumeIfOwned(String sku) async {
    try {
      final result = await MyketIAP.queryInventory(querySkuDetails: false);
      final inventory = result[MyketIAP.INVENTORY] as Inventory?;
      if (inventory == null) return;
      final existing = inventory.mPurchaseMap[sku];
      if (existing == null) return;
      await MyketIAP.consume(purchase: existing);
    } catch (_) {
      // If Myket refuses to consume a subscription, carry on
    }
  }

  static Future<void> dispose() async {
    if (_initialized) {
      try {
        await MyketIAP.dispose();
      } catch (e) {
        debugPrint('Myket dispose failed: $e');
      }
      _initialized = false;
    }
  }
}

// ─── Purchase results ─────────────────────────────────────────────

/// Outcome of a purchase attempt.
class PurchaseResult {
  final bool success;
  final DateTime? expiry;
  final String? errorMessage;

  PurchaseResult._({required this.success, this.expiry, this.errorMessage});

  factory PurchaseResult.success(DateTime expiry) =>
      PurchaseResult._(success: true, expiry: expiry);

  factory PurchaseResult.error(String message) =>
      PurchaseResult._(success: false, errorMessage: message);
}

/// Outcome of a restore-purchases attempt.
class RestoreResult {
  final RestoreStatus status;
  final DateTime? expiry;
  final String? errorMessage;

  RestoreResult._({required this.status, this.expiry, this.errorMessage});

  factory RestoreResult.success(DateTime expiry) =>
      RestoreResult._(status: RestoreStatus.success, expiry: expiry);

  factory RestoreResult.expired(DateTime expiry) =>
      RestoreResult._(status: RestoreStatus.expired, expiry: expiry);

  factory RestoreResult.notFound() =>
      RestoreResult._(status: RestoreStatus.notFound);

  factory RestoreResult.error(String message) =>
      RestoreResult._(status: RestoreStatus.error, errorMessage: message);
}

enum RestoreStatus { success, expired, notFound, error }
