import 'package:flutter_test/flutter_test.dart';
import 'package:pezhvak/services/rule_options.dart';

void main() {
  group('RuleOptions', () {
    test('a fresh instance is the default and is not worth persisting', () {
      expect(RuleOptions().isDefault, isTrue);
    });

    test('any customization makes it non-default', () {
      expect(RuleOptions(priority: 'urgent').isDefault, isFalse);
      expect(RuleOptions(repeat: true).isDefault, isFalse);
      expect(RuleOptions(excludes: ['x']).isDefault, isFalse);
      expect(RuleOptions(scheduleEnabled: true).isDefault, isFalse);
      expect(RuleOptions(ignoreGlobalSchedule: true).isDefault, isFalse);
    });

    test('JSON round trip keeps every field', () {
      final original = RuleOptions(
        priority: 'silent',
        sound: '/data/sound.mp3',
        vibration: 'strong',
        repeat: true,
        repeatMinutes: 5,
        excludes: ['promo', 'ad'],
        scheduleEnabled: true,
        startHour: 9,
        startMinute: 30,
        endHour: 17,
        endMinute: 45,
        days: [1, 7],
        ignoreGlobalSchedule: true,
      );
      final copy = RuleOptions.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
      expect(copy.excludes, ['promo', 'ad']);
      expect(copy.days, [1, 7]);
    });

    test('the schedule block is written only when enabled', () {
      expect(RuleOptions().toJson().containsKey('schedule'), isFalse);
      expect(RuleOptions(scheduleEnabled: true).toJson()['schedule'],
          isA<Map<String, dynamic>>());
    });

    test('copy() is independent of the original', () {
      final original = RuleOptions(excludes: ['a']);
      final copy = original.copy()..excludes.add('b');
      expect(original.excludes, ['a']);
      expect(copy.excludes, ['a', 'b']);
    });
  });

  group('RuleOptionsService.key', () {
    test('prefixes keywords with k and titles with t', () {
      expect(RuleOptionsService.key(true, 'deposit'), 'k:deposit');
      expect(RuleOptionsService.key(false, 'Bank'), 't:Bank');
    });
  });
}
