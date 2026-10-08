import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pezhvak/core/channels.dart';

/// Snapshot of the monitoring service health reported by the native side.
class PezhvakServiceStatus {
  final bool serviceEnabled;
  final bool notificationAccess;
  final bool listenerConnected;
  final bool ignoringBatteryOptimizations;
  final bool exactAlarms;
  final int sdk;

  const PezhvakServiceStatus({
    required this.serviceEnabled,
    required this.notificationAccess,
    required this.listenerConnected,
    required this.ignoringBatteryOptimizations,
    required this.exactAlarms,
    required this.sdk,
  });

  factory PezhvakServiceStatus.fromMap(Map<dynamic, dynamic> m) =>
      PezhvakServiceStatus(
        serviceEnabled: m['serviceEnabled'] == true,
        notificationAccess: m['notificationAccess'] == true,
        listenerConnected: m['listenerConnected'] == true,
        ignoringBatteryOptimizations: m['ignoringBatteryOptimizations'] == true,
        exactAlarms: m['exactAlarms'] == true,
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
      );
}

/// User settings of the nightly summary notification.
class DailySummarySettings {
  final bool enabled;
  final int hour;
  final int minute;
  const DailySummarySettings(
      {required this.enabled, required this.hour, required this.minute});

  DailySummarySettings copyWith({bool? enabled, int? hour, int? minute}) =>
      DailySummarySettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Basic device information used to tailor the background-survival guide.
class DeviceInfo {
  final String manufacturer;
  final String brand;
  final String model;
  final int sdk;

  const DeviceInfo({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.sdk,
  });

  String get label => '$manufacturer $model (Android SDK $sdk)';
}

/// Bridge to the native system channel ([AppChannels.system]): diagnostics, service status and
/// manufacturer-specific settings.
class SystemService {
  static const _channel = MethodChannel(AppChannels.system);

  static Future<List<Map<String, dynamic>>> getDiagnostics() async {
    try {
      final raw = await _channel.invokeMethod<String>('getDiagnostics');
      final list = json.decode(raw ?? '[]') as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Failed to read diagnostics: $e');
      return [];
    }
  }

  static Future<void> clearDiagnostics() async {
    try {
      await _channel.invokeMethod('clearDiagnostics');
    } catch (e) {
      debugPrint('Failed to clear diagnostics: $e');
    }
  }

  static Future<PezhvakServiceStatus?> getServiceStatus() async {
    try {
      final m = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return m == null ? null : PezhvakServiceStatus.fromMap(m);
    } catch (e) {
      debugPrint('Failed to read service status: $e');
      return null;
    }
  }

  static Future<void> rebindListener() async {
    try {
      await _channel.invokeMethod('rebindListener');
    } catch (e) {
      debugPrint('Failed to rebind the listener: $e');
    }
  }

  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      final m =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceInfo');
      if (m != null) {
        return DeviceInfo(
          manufacturer: (m['manufacturer'] ?? '').toString(),
          brand: (m['brand'] ?? '').toString(),
          model: (m['model'] ?? '').toString(),
          sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Failed to read device info: $e');
    }
    return const DeviceInfo(manufacturer: '', brand: '', model: '', sdk: 0);
  }

  /// true: a manufacturer-specific screen opened. false: only the generic app info page.
  static Future<bool> openAutoStartSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAutoStartSettings') ??
          false;
    } catch (e) {
      debugPrint('Failed to open settings: $e');
      return false;
    }
  }

  /// Fires a test alarm; with a positive [delaySeconds] it fires after that delay (so the screen can be locked first).
  static Future<void> testAlarm({int delaySeconds = 0}) async {
    try {
      await _channel.invokeMethod('testAlarm', {'delaySeconds': delaySeconds});
    } catch (e) {
      debugPrint('Failed to fire the test alarm: $e');
    }
  }

  static Future<DailySummarySettings> getDailySummary() async {
    try {
      final m =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDailySummary');
      if (m != null) {
        return DailySummarySettings(
          enabled: m['enabled'] == true,
          hour: (m['hour'] as num?)?.toInt() ?? 22,
          minute: (m['minute'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Failed to read daily summary settings: $e');
    }
    return const DailySummarySettings(enabled: true, hour: 22, minute: 0);
  }

  static Future<void> setDailySummary(DailySummarySettings s) async {
    try {
      await _channel.invokeMethod('setDailySummary',
          {'enabled': s.enabled, 'hour': s.hour, 'minute': s.minute});
    } catch (e) {
      debugPrint('Failed to save daily summary settings: $e');
    }
  }
}
