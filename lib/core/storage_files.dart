import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// JSON files in the app's support directory.
///
/// That directory is the native `filesDir`, so the Kotlin side reads and writes the very same
/// files (see `StorageFiles` in `AppPrefs.kt`). Rename a file on both sides or on neither.
abstract final class StorageFiles {
  static const String selectedApps = 'selected_apps.json';
  static const String schedule = 'schedule.json';
  static const String suppressedApps = 'suppressed_apps.json';
  static const String ruleOptions = 'rules.json';
  static const String premium = 'premium.json';

  /// Exists while an alarm is waiting to be dismissed; holds the alarm payload.
  static const String pendingAlarm = 'notification.json';

  /// History base names. The native side writes `<name>.jsonl` (older versions wrote `<name>.json`).
  static const String notificationHistory = 'notification_history';
  static const String alarmHistory = 'alarm_history';

  static Future<Directory> directory() => getApplicationSupportDirectory();

  static Future<File> file(String name) async =>
      File('${(await directory()).path}/$name');
}
