import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';
import 'package:pezhvak/services/file_utils.dart';

/// Reads and clears the pending alarm payload (notification.json) written by the native listener.
class AlarmStateManager {
  static Future<File> _getLocalFile() =>
      StorageFiles.file(StorageFiles.pendingAlarm);

  static Future<Map<String, dynamic>?> getStoredNotification() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        return json.decode(await file.readAsString());
      }
    } catch (e) {
      debugPrint('Failed to read the stored notification: $e');
    }
    return null;
  }

  static Future<void> clearNotification() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to clear the stored notification: $e');
    }
  }
}

/// Remembers which apps were muted after an alarm was dismissed (the native listener enforces the 5 minutes).
class SuppressedAppsService {
  static Future<void> suppressApp(String packageName) async {
    try {
      final file = await StorageFiles.file(StorageFiles.suppressedApps);
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        data =
            Map<String, dynamic>.from(json.decode(await file.readAsString()));
      }
      data[packageName] = DateTime.now().millisecondsSinceEpoch;
      await writeFileAtomic(file, json.encode(data));
    } catch (e) {
      debugPrint('Failed to suppress the app: $e');
    }
  }
}
