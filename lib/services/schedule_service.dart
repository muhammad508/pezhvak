import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';
import 'package:pezhvak/services/file_utils.dart';

/// Reads and writes the global alarm schedule (schedule.json), which the native listener also reads.
class ScheduleService {
  static Future<Map<String, dynamic>> getSchedule() async {
    try {
      final file = await StorageFiles.file(StorageFiles.schedule);
      if (await file.exists()) {
        return Map<String, dynamic>.from(
            json.decode(await file.readAsString()));
      }
    } catch (e) {
      debugPrint('Failed to read the schedule: $e');
    }
    return {
      'enabled': false,
      'start_hour': 8,
      'start_minute': 0,
      'end_hour': 22,
      'end_minute': 0,
      'days': [1, 2, 3, 4, 5, 6, 7],
    };
  }

  static Future<void> saveSchedule(Map<String, dynamic> schedule) async {
    try {
      final file = await StorageFiles.file(StorageFiles.schedule);
      await writeFileAtomic(file, json.encode(schedule));
    } catch (e) {
      debugPrint('Failed to save the schedule: $e');
    }
  }
}
