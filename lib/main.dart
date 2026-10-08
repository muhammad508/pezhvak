import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/core/app_theme.dart';
import 'package:pezhvak/core/prefs_keys.dart';
import 'package:pezhvak/pages/permission_gate.dart';
import 'package:pezhvak/services/foreground_service.dart';
import 'package:pezhvak/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(PrefsKeys.serviceEnabled) ?? true) {
    ForegroundServiceChannel.startService();
  }
  await PremiumService.refresh();
  WakelockPlus.enable();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin
      .initialize(InitializationSettings(android: androidSettings));

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: rtlAppBuilder,
    home: PermissionGate(),
  ));
}
