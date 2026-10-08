import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Premium history tools: date-range filter, CSV export, and the "triggered by" rule label.

/// For example a keyword label, a title label, or "selected app". Returns null when no rule was recorded.
String? matchedRuleLabel(Map<String, dynamic> item) {
  final kind = item['matched_kind']?.toString();
  final text = item['matched_text']?.toString() ?? '';
  if (kind == null || kind.isEmpty) return null;
  switch (kind) {
    case 'keyword':
      return 'کلمه «$text»';
    case 'title':
      return 'عنوان «$text»';
    case 'app':
      return 'برنامه‌ی انتخاب‌شده';
    default:
      return text.isEmpty ? null : text;
  }
}

String priorityLabel(String? p) {
  switch (p) {
    case 'urgent':
      return 'فوری';
    case 'silent':
      return 'بی‌صدا';
    case 'normal':
      return 'عادی';
    default:
      return '';
  }
}

String jalaliDate(DateTime dt) {
  final j = Jalali.fromDateTime(dt);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
}

String jalaliDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${jalaliDate(dt)} $hh:$mm';
}

/// Formats a millisecond timestamp (number or numeric string) as `yyyy/MM/dd  HH:mm`.
/// Returns an empty string when the value is missing or invalid.
String formatTimestamp(dynamic ts) {
  if (ts == null) return '';
  final ms = ts is num ? ts.toInt() : int.tryParse(ts.toString());
  if (ms == null) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
}

/// Whether [query] (already lower-cased) occurs in the record's title, text or app name.
bool matchesQuery(Map<String, dynamic> item, String query) {
  bool has(String key) =>
      (item[key] ?? '').toString().toLowerCase().contains(query);
  return has('title') || has('text') || has('app_name');
}

DateTime? _itemTime(Map<String, dynamic> item) {
  final ts = item['timestamp'];
  if (ts == null) return null;
  final ms = int.tryParse(ts.toString());
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

/// Whether a record falls inside the selected range (last day included). Without a range everything passes.
bool inRange(Map<String, dynamic> item, DateTimeRange? range) {
  if (range == null) return true;
  final t = _itemTime(item);
  if (t == null) return false;
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day)
      .add(const Duration(days: 1));
  return !t.isBefore(start) && t.isBefore(end);
}

Future<DateTimeRange?> pickHistoryRange(
    BuildContext context, DateTimeRange? current) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 3),
    lastDate:
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    initialDateRange: current,
    helpText: 'بازه‌ی تاریخ را انتخاب کنید',
    saveText: 'اعمال',
  );
}

String _csvCell(Object? v) {
  final s = (v ?? '').toString().replaceAll('\r', ' ');
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String buildHistoryCsv(List<Map<String, dynamic>> items) {
  final rows = <List<Object?>>[
    [
      'تاریخ شمسی',
      'زمان میلادی',
      'برنامه',
      'عنوان',
      'متن',
      'آلارم',
      'قانون',
      'اولویت'
    ],
  ];
  for (final e in items) {
    final t = _itemTime(e);
    rows.add([
      t == null ? '' : jalaliDateTime(t),
      t?.toIso8601String() ?? '',
      e['app_name'],
      e['title'],
      e['text'],
      e['triggered_alarm'] == true || !e.containsKey('triggered_alarm')
          ? 'بله'
          : 'خیر',
      matchedRuleLabel(e) ?? '',
      priorityLabel(e['priority']?.toString()),
    ]);
  }
  return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
}

/// Saves the CSV through the system "save file" dialog. A BOM is prepended so Persian text displays correctly in Excel.
Future<void> exportHistoryCsv(
  BuildContext context,
  List<Map<String, dynamic>> items,
  String baseName,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (items.isEmpty) {
    messenger.showSnackBar(const SnackBar(
      content: Text('موردی برای خروجی گرفتن وجود ندارد'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }
  try {
    final bytes = Uint8List.fromList(
        [0xEF, 0xBB, 0xBF, ...utf8.encode(buildHistoryCsv(items))]);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = await FilePicker.saveFile(
      dialogTitle: 'ذخیره‌ی فایل CSV',
      fileName: '${baseName}_$stamp.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    if (path != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('${items.length} مورد ذخیره شد'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text('خطا در ذخیره‌ی فایل: $e'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Small "selected range" chip shown under the toolbar.
class RangeChipBar extends StatelessWidget {
  final DateTimeRange range;
  final VoidCallback onClear;
  const RangeChipBar({super.key, required this.range, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: InputChip(
          avatar: const Icon(Icons.date_range_rounded, size: 16),
          label: Text(
              'از ${jalaliDate(range.start)} تا ${jalaliDate(range.end)}',
              style: const TextStyle(fontSize: 12)),
          onDeleted: onClear,
        ),
      ),
    );
  }
}

/// Small "triggered by ..." label for history cards.
class RuleBadge extends StatelessWidget {
  final String label;
  const RuleBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rule_rounded, size: 13, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'فعال شده توسط: $label',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
