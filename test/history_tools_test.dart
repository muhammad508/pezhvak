import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pezhvak/utils/history_tools.dart';
import 'package:pezhvak/utils/week_days.dart';

void main() {
  group('matchedRuleLabel', () {
    test('describes keyword, title and app rules', () {
      expect(matchedRuleLabel({'matched_kind': 'keyword', 'matched_text': 'x'}),
          contains('x'));
      expect(matchedRuleLabel({'matched_kind': 'title', 'matched_text': 'y'}),
          contains('y'));
      expect(matchedRuleLabel({'matched_kind': 'app', 'matched_text': 'Z'}),
          isNotNull);
    });

    test('returns null when no rule was recorded', () {
      expect(matchedRuleLabel({}), isNull);
      expect(matchedRuleLabel({'matched_kind': ''}), isNull);
    });
  });

  group('formatTimestamp', () {
    final moment = DateTime(2025, 3, 9, 7, 5);

    test('formats numbers and numeric strings the same way', () {
      expect(
          formatTimestamp(moment.millisecondsSinceEpoch), '2025/03/09  07:05');
      expect(formatTimestamp(moment.millisecondsSinceEpoch.toString()),
          '2025/03/09  07:05');
    });

    test('returns an empty string for missing or invalid values', () {
      expect(formatTimestamp(null), '');
      expect(formatTimestamp('not-a-number'), '');
    });
  });

  group('inRange', () {
    final noon = DateTime(2025, 3, 10, 12);
    final item = {'timestamp': noon.millisecondsSinceEpoch};

    test('everything passes without a range', () {
      expect(inRange(item, null), isTrue);
    });

    test('includes the first and last day of the range', () {
      final range = DateTimeRange(
        start: DateTime(2025, 3, 10),
        end: DateTime(2025, 3, 10),
      );
      expect(inRange(item, range), isTrue);
    });

    test('excludes records outside the range', () {
      final range = DateTimeRange(
        start: DateTime(2025, 3, 11),
        end: DateTime(2025, 3, 12),
      );
      expect(inRange(item, range), isFalse);
    });

    test('records without a valid timestamp never match a range', () {
      final range = DateTimeRange(
        start: DateTime(2025, 3, 1),
        end: DateTime(2025, 3, 31),
      );
      expect(inRange({}, range), isFalse);
      expect(inRange({'timestamp': 'not-a-number'}, range), isFalse);
    });
  });

  group('buildHistoryCsv', () {
    test('writes a header plus one row per item', () {
      final csv = buildHistoryCsv([
        {'app_name': 'A', 'title': 't', 'text': 'body', 'timestamp': 0},
        {'app_name': 'B', 'title': 't2', 'text': 'body2', 'timestamp': 0},
      ]);
      expect(csv.split('\r\n'), hasLength(3));
    });

    test('quotes cells containing commas, quotes or newlines', () {
      final csv = buildHistoryCsv([
        {
          'app_name': 'A',
          'title': 'a,b',
          'text': 'say "hi"\nbye',
          'timestamp': 0,
        },
      ]);
      expect(csv, contains('"a,b"'));
      expect(csv, contains('"say ""hi""\nbye"'));
    });
  });

  group('weekDayLabels', () {
    test('covers all seven Calendar day indexes, Saturday first', () {
      expect(weekDayLabels.keys.toSet(), {1, 2, 3, 4, 5, 6, 7});
      expect(weekDayLabels.keys.first, 7);
    });
  });
}
