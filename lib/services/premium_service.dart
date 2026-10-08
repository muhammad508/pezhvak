import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';
import 'package:pezhvak/services/file_utils.dart';

/// Local cache of the subscription expiry (premium.json). Myket remains the source of truth;
/// the native listener reads the same file to enforce premium-only rules.
///
/// The current state is exposed as [status]: listen to it instead of passing an "is premium"
/// flag down the widget tree.
abstract final class PremiumService {
  static final ValueNotifier<bool> _status = ValueNotifier<bool>(false);

  /// Whether the subscription is active. Updated by [refresh], and whenever [setExpiry] runs.
  static ValueListenable<bool> get status => _status;

  /// Re-reads the cached expiry and notifies the listeners of [status].
  static Future<void> refresh() async {
    _status.value = await isPremium();
  }

  /// Whether the cached expiry lies in the future.
  static Future<bool> isPremium() async {
    final expiry = await getExpiry();
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  /// Subscription expiry date, or null when there is none.
  static Future<DateTime?> getExpiry() async {
    try {
      final file = await StorageFiles.file(StorageFiles.premium);
      if (await file.exists()) {
        final data = json.decode(await file.readAsString());
        final expiryStr = data['expiry'] as String?;
        if (expiryStr != null) return DateTime.parse(expiryStr);
      }
    } catch (e) {
      debugPrint('Failed to read the premium expiry: $e');
    }
    return null;
  }

  /// Saves the expiry date and updates [status].
  static Future<void> setExpiry(DateTime expiry) async {
    try {
      final file = await StorageFiles.file(StorageFiles.premium);
      await writeFileAtomic(
          file, json.encode({'expiry': expiry.toIso8601String()}));
    } catch (e) {
      debugPrint('Failed to save the premium expiry: $e');
    }
    await refresh();
  }
}
