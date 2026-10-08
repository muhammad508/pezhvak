import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pezhvak/core/storage_files.dart';
import 'package:pezhvak/services/services.dart';

/// Advanced options of a single rule (keyword or title). Premium feature.
/// Stored in rules.json next to the other files and read by the native listener.
class RuleOptions {
  /// urgent: no cooldown | normal | silent: quiet notification only
  String priority;
  String sound;

  /// off | gentle | strong
  String vibration;
  bool repeat;
  int repeatMinutes;
  List<String> excludes;
  bool scheduleEnabled;
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;

  /// Matches Android's Calendar: 1 = Sunday ... 7 = Saturday
  List<int> days;
  bool ignoreGlobalSchedule;

  RuleOptions({
    this.priority = 'normal',
    this.sound = '',
    this.vibration = 'off',
    this.repeat = false,
    this.repeatMinutes = 2,
    List<String>? excludes,
    this.scheduleEnabled = false,
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    List<int>? days,
    this.ignoreGlobalSchedule = false,
  })  : excludes = excludes ?? [],
        days = days ?? [1, 2, 3, 4, 5, 6, 7];

  bool get isDefault =>
      priority == 'normal' &&
      sound.isEmpty &&
      vibration == 'off' &&
      !repeat &&
      excludes.isEmpty &&
      !scheduleEnabled &&
      !ignoreGlobalSchedule;

  RuleOptions copy() => RuleOptions.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'priority': priority,
        'sound': sound,
        'vibration': vibration,
        'repeat': repeat,
        'repeat_minutes': repeatMinutes,
        'excludes': excludes,
        'ignore_global_schedule': ignoreGlobalSchedule,
        if (scheduleEnabled)
          'schedule': {
            'enabled': true,
            'days': days,
            'start_hour': startHour,
            'start_minute': startMinute,
            'end_hour': endHour,
            'end_minute': endMinute,
          },
      };

  factory RuleOptions.fromJson(Map<String, dynamic> j) {
    final s = j['schedule'];
    final sched = s is Map ? Map<String, dynamic>.from(s) : null;
    return RuleOptions(
      priority: (j['priority'] ?? 'normal').toString(),
      sound: (j['sound'] ?? '').toString(),
      vibration: (j['vibration'] ?? 'off').toString(),
      repeat: j['repeat'] == true,
      repeatMinutes: (j['repeat_minutes'] as num?)?.toInt() ?? 2,
      excludes: (j['excludes'] as List?)?.map((e) => e.toString()).toList(),
      ignoreGlobalSchedule: j['ignore_global_schedule'] == true,
      scheduleEnabled: sched != null && sched['enabled'] == true,
      startHour: (sched?['start_hour'] as num?)?.toInt() ?? 8,
      startMinute: (sched?['start_minute'] as num?)?.toInt() ?? 0,
      endHour: (sched?['end_hour'] as num?)?.toInt() ?? 22,
      endMinute: (sched?['end_minute'] as num?)?.toInt() ?? 0,
      days: (sched?['days'] as List?)?.map((e) => (e as num).toInt()).toList(),
    );
  }
}

/// Loads and saves rule options in rules.json, and manages custom sound files.
class RuleOptionsService {
  /// Rule key: `k:` followed by the text for a keyword, `t:` followed by the text for a title.
  static String key(bool isKeyword, String text) =>
      '${isKeyword ? 'k' : 't'}:$text';

  static Future<File> _file() => StorageFiles.file(StorageFiles.ruleOptions);

  static Future<Map<String, RuleOptions>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final raw = json.decode(await f.readAsString());
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(
          k.toString(), RuleOptions.fromJson(Map<String, dynamic>.from(v))));
    } catch (e) {
      debugPrint('Failed to read rule options: $e');
      return {};
    }
  }

  static Future<void> _write(Map<String, RuleOptions> all) async {
    final f = await _file();
    await writeFileAtomic(
        f, json.encode(all.map((k, v) => MapEntry(k, v.toJson()))));
  }

  /// Saves the options (or removes them when everything is default).
  static Future<void> save(String key, RuleOptions options) async {
    final all = await load();
    if (options.isDefault) {
      all.remove(key);
    } else {
      all[key] = options;
    }
    await _write(all);
  }

  static Future<void> remove(String key) async {
    final all = await load();
    if (all.remove(key) != null) await _write(all);
  }
}
