import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';

/// How many history records are shown. The native side keeps up to 10,000 of each history.
abstract final class HistoryLimits {
  static const int free = 10;
  static const int premium = 10000;
}

/// Reads a JSONL history (oldest first on disk, returned newest first). Heavy parsing runs in a separate isolate.
/// If the JSONL file does not exist yet, the legacy JSON-array format is read instead.
class _HistoryFile {
  final String name;
  const _HistoryFile(this.name);

  Future<String> _dir() async => (await StorageFiles.directory()).path;

  Future<List<Map<String, dynamic>>> read({int? limit}) async {
    final dir = await _dir();
    try {
      return await Isolate.run(() => _readSync(dir, name, limit));
    } catch (e) {
      debugPrint('Failed to read history ($name): $e');
      return [];
    }
  }

  Future<int> count() async {
    final dir = await _dir();
    try {
      return await Isolate.run(() => _countSync(dir, name));
    } catch (e) {
      return 0;
    }
  }

  Future<void> clear() async {
    final dir = await _dir();
    for (final f in ['$dir/$name.jsonl', '$dir/$name.json']) {
      try {
        final file = File(f);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Failed to clear history ($name): $e');
      }
    }
  }
}

List<Map<String, dynamic>> _readSync(String dir, String name, int? limit) {
  final jsonl = File('$dir/$name.jsonl');
  if (jsonl.existsSync()) {
    final text = utf8.decode(jsonl.readAsBytesSync(), allowMalformed: true);
    final lines = const LineSplitter().convert(text);
    final out = <Map<String, dynamic>>[];
    for (var i = lines.length - 1; i >= 0; i--) {
      if (limit != null && out.length >= limit) break;
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        final v = json.decode(line);
        if (v is Map) out.add(Map<String, dynamic>.from(v));
      } catch (_) {
        // Skip a partial line (a write that was cut short).
      }
    }
    return out;
  }
  final legacy = File('$dir/$name.json');
  if (legacy.existsSync()) {
    final List<dynamic> list = json.decode(legacy.readAsStringSync());
    final all = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return limit == null ? all : all.take(limit).toList();
  }
  return [];
}

int _countSync(String dir, String name) {
  final jsonl = File('$dir/$name.jsonl');
  if (jsonl.existsSync()) {
    var n = 0;
    var lineHasData = false;
    for (final b in jsonl.readAsBytesSync()) {
      if (b == 10) {
        if (lineHasData) n++;
        lineHasData = false;
      } else if (b != 13 && b != 32) {
        lineHasData = true;
      }
    }
    return lineHasData ? n + 1 : n;
  }
  final legacy = File('$dir/$name.json');
  if (legacy.existsSync()) {
    return (json.decode(legacy.readAsStringSync()) as List).length;
  }
  return 0;
}

/// Access to the full notification history written by the native listener.
class NotificationHistoryService {
  static const _file = _HistoryFile(StorageFiles.notificationHistory);

  /// Newest first. With [limit], only that many records are parsed.
  static Future<List<Map<String, dynamic>>> getHistory({int? limit}) =>
      _file.read(limit: limit);

  static Future<int> getCount() => _file.count();

  static Future<void> clearHistory() => _file.clear();
}

/// Access to the history of fired alarms written by the native listener.
class AlarmHistoryService {
  static const _file = _HistoryFile(StorageFiles.alarmHistory);

  static Future<List<Map<String, dynamic>>> getHistory({int? limit}) =>
      _file.read(limit: limit);

  static Future<int> getCount() => _file.count();

  static Future<void> clearHistory() => _file.clear();
}
