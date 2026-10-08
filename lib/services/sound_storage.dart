import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';

/// Custom alarm sounds, copied into app storage.
///
/// `file_picker` hands out paths inside a cache directory that Android may clear at any time, so a
/// picked sound is copied somewhere permanent before its path is remembered.
abstract final class SoundStorage {
  /// The one sound the user picked for all alarms.
  static const String alarmFolder = 'alarm_sound';

  /// Per-rule sounds (premium).
  static const String ruleFolder = 'rule_sounds';

  /// Copies [pickedPath] into [folder] and returns the new path.
  static Future<String> import(
    String pickedPath, {
    required String folder,
  }) async {
    final base = await StorageFiles.directory();
    final dir = Directory('${base.path}/$folder');
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = pickedPath.split(RegExp(r'[\\/]')).last;
    final destination =
        File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
    await File(pickedPath).copy(destination.path);
    return destination.path;
  }

  /// Deletes a sound returned by [import]. Paths outside the managed folders are left untouched.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final base = (await StorageFiles.directory()).path;
      final managed = [alarmFolder, ruleFolder]
          .any((folder) => path.startsWith('$base/$folder/'));
      if (!managed) return;
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to delete a custom sound: $e');
    }
  }
}
