import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/core/storage_files.dart';
import 'package:pezhvak/services/file_utils.dart';

/// Persists the apps the user wants monitored. The native listener notices file changes by itself.
class AppService {
  static Future<void> loadSelectedApps() async {
    try {
      final file = await StorageFiles.file(StorageFiles.selectedApps);
      if (await file.exists()) {
        final List<dynamic> jsonApps = jsonDecode(await file.readAsString());
        selectedApps = jsonApps.map((app) => app.toString()).toSet();
      }
    } catch (e) {
      debugPrint('Failed to load selected apps: $e');
    }
  }

  static Future<void> updateSelectedApps(Set<String> apps) async {
    selectedApps = apps;
    try {
      final file = await StorageFiles.file(StorageFiles.selectedApps);
      await writeFileAtomic(file, jsonEncode(apps.toList()));
    } catch (e) {
      debugPrint('Failed to save selected apps: $e');
    }
  }
}
