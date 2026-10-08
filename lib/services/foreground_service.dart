import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pezhvak/core/channels.dart';

/// Starts and stops the native foreground service through its method channel.
class ForegroundServiceChannel {
  static const MethodChannel _channel = MethodChannel(AppChannels.service);

  static Future<void> startService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      debugPrint('Failed to start service: ${e.message}');
    }
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      debugPrint('Failed to stop service: ${e.message}');
    }
  }
}
