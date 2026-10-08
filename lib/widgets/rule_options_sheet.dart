import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pezhvak/services/rule_options.dart';
import 'package:pezhvak/services/sound_storage.dart';
import 'package:pezhvak/utils/week_days.dart';

/// Bottom sheet with a rule's advanced options (premium). Resolves to true after saving.
Future<bool> showRuleOptionsSheet(
  BuildContext context, {
  required bool isKeyword,
  required String text,
}) async {
  final key = RuleOptionsService.key(isKeyword, text);
  final all = await RuleOptionsService.load();
  final initial = (all[key] ?? RuleOptions()).copy();
  if (!context.mounted) return false;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RuleOptionsSheet(
      storageKey: key,
      isKeyword: isKeyword,
      text: text,
      initial: initial,
    ),
  );
  return saved == true;
}

class _RuleOptionsSheet extends StatefulWidget {
  final String storageKey;
  final bool isKeyword;
  final String text;
  final RuleOptions initial;

  const _RuleOptionsSheet({
    required this.storageKey,
    required this.isKeyword,
    required this.text,
    required this.initial,
  });

  @override
  State<_RuleOptionsSheet> createState() => _RuleOptionsSheetState();
}

class _RuleOptionsSheetState extends State<_RuleOptionsSheet> {
  late RuleOptions _o;
  final _excludeCtrl = TextEditingController();
  late final String _originalSound;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _o = widget.initial;
    _originalSound = _o.sound;
  }

  @override
  void dispose() {
    _excludeCtrl.dispose();
    super.dispose();
  }

  bool get _silent => _o.priority == 'silent';

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String get _priorityHint {
    switch (_o.priority) {
      case 'urgent':
        return 'آلارم بدون کولداون: حتی اگر چند لحظه پیش آلارم همین برنامه را بسته باشید، دوباره فوراً می‌زند.';
      case 'silent':
        return 'آلارم نمی‌زند؛ فقط یک نوتیفیکیشن بدون صدا نشان داده می‌شود و در تاریخچه ثبت می‌شود.';
      default:
        return 'آلارم معمولی (با کولداون ۱ دقیقه‌ای و توقف ۵ دقیقه‌ای بعد از بستن).';
    }
  }

  Future<void> _pickSound() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final copied =
          await SoundStorage.import(path, folder: SoundStorage.ruleFolder);
      // If another sound was picked earlier in this session, delete the extra file.
      if (_o.sound.isNotEmpty && _o.sound != _originalSound) {
        await SoundStorage.delete(_o.sound);
      }
      if (mounted) setState(() => _o.sound = copied);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('خطا در انتخاب فایل صوتی'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: start
          ? TimeOfDay(hour: _o.startHour, minute: _o.startMinute)
          : TimeOfDay(hour: _o.endHour, minute: _o.endMinute),
    );
    if (t == null) return;
    setState(() {
      if (start) {
        _o.startHour = t.hour;
        _o.startMinute = t.minute;
      } else {
        _o.endHour = t.hour;
        _o.endMinute = t.minute;
      }
    });
  }

  void _addExclude() {
    final v = _excludeCtrl.text.trim();
    _excludeCtrl.clear();
    if (v.isEmpty || _o.excludes.contains(v)) return;
    setState(() => _o.excludes.add(v));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // If the user typed a negative word but did not press "add", keep it as well.
    _addExclude();
    if (_o.scheduleEnabled && _o.days.isEmpty) _o.days = [1, 2, 3, 4, 5, 6, 7];
    if (_originalSound.isNotEmpty && _originalSound != _o.sound) {
      await SoundStorage.delete(_originalSound);
    }
    await RuleOptionsService.save(widget.storageKey, _o);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    if (_o.sound.isNotEmpty) await SoundStorage.delete(_o.sound);
    if (_originalSound.isNotEmpty && _originalSound != _o.sound) {
      await SoundStorage.delete(_originalSound);
    }
    await RuleOptionsService.save(widget.storageKey, RuleOptions());
    if (mounted) Navigator.pop(context, true);
  }

  Widget _section(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(subtitle,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey[500], height: 1.5)),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final soundName = _o.sound.isEmpty
        ? 'صدای پیش‌فرض برنامه'
        : _o.sound
            .split(RegExp(r'[\\/]'))
            .last
            .replaceFirst(RegExp(r'^\d+_'), '');

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تنظیمات پیشرفته',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${widget.isKeyword ? 'کلمه' : 'عنوان'}: «${widget.text}»',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              ],
            ),

            // ── Priority
            _section('اولویت'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: 'urgent',
                      label: Text('فوری'),
                      icon: Icon(Icons.bolt_rounded, size: 18)),
                  ButtonSegment(
                      value: 'normal',
                      label: Text('عادی'),
                      icon: Icon(Icons.notifications_active_rounded, size: 18)),
                  ButtonSegment(
                      value: 'silent',
                      label: Text('بی‌صدا'),
                      icon: Icon(Icons.notifications_off_rounded, size: 18)),
                ],
                selected: {_o.priority},
                onSelectionChanged: (s) =>
                    setState(() => _o.priority = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_priorityHint,
                  style: TextStyle(
                      fontSize: 11.5, color: Colors.grey[500], height: 1.6)),
            ),

            if (!_silent) ...[
              // ── Sound
              _section('صدای اختصاصی',
                  subtitle: 'برای همین قانون صدای جداگانه بگذارید.'),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading:
                      const Icon(Icons.audiotrack_rounded, color: Colors.amber),
                  title: Text(soundName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_o.sound.isNotEmpty)
                        IconButton(
                          tooltip: 'حذف صدای اختصاصی',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () async {
                            if (_o.sound != _originalSound) {
                              await SoundStorage.delete(_o.sound);
                            }
                            if (mounted) setState(() => _o.sound = '');
                          },
                        ),
                      TextButton(
                          onPressed: _pickSound, child: const Text('انتخاب')),
                    ],
                  ),
                ),
              ),

              // ── Vibration
              _section('لرزش'),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'off', label: Text('خاموش')),
                    ButtonSegment(value: 'gentle', label: Text('ملایم')),
                    ButtonSegment(value: 'strong', label: Text('قوی')),
                  ],
                  selected: {_o.vibration},
                  onSelectionChanged: (s) =>
                      setState(() => _o.vibration = s.first),
                ),
              ),

              // ── Repeat
              _section('تکرار تا تأیید',
                  subtitle:
                      'تا وقتی آلارم را نبسته‌اید، صفحه‌ی آلارم دوباره بالا می‌آید (حداکثر ۱۰ بار).'),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _o.repeat,
                      activeThumbColor: Colors.orange,
                      title: const Text('تکرار آلارم',
                          style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setState(() => _o.repeat = v),
                    ),
                    if (_o.repeat)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Wrap(
                          spacing: 8,
                          children: [1, 2, 5, 10]
                              .map((m) => ChoiceChip(
                                    label: Text('هر $m دقیقه'),
                                    selected: _o.repeatMinutes == m,
                                    onSelected: (_) =>
                                        setState(() => _o.repeatMinutes = m),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── Negative words
            _section('کلمات منفی',
                subtitle:
                    'اگر هرکدام از این کلمات در عنوان یا متن بود، این قانون آلارم نمی‌زند. مثال: «کد تخفیف».'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _excludeCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addExclude(),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'کلمه‌ی منفی',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _addExclude, child: const Text('افزودن')),
              ],
            ),
            if (_o.excludes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _o.excludes
                      .map((w) => InputChip(
                            label: Text(w),
                            avatar: const Icon(Icons.block_rounded, size: 16),
                            onDeleted: () =>
                                setState(() => _o.excludes.remove(w)),
                          ))
                      .toList(),
                ),
              ),

            // ── Dedicated schedule
            _section('زمان‌بندی اختصاصی',
                subtitle:
                    'این قانون فقط در بازه و روزهای زیر فعال باشد (جدا از زمان‌بندی کلی برنامه).'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: _o.scheduleEnabled,
                    activeThumbColor: Colors.orange,
                    title: const Text('زمان‌بندی مخصوص این قانون',
                        style: TextStyle(fontSize: 13)),
                    onChanged: (v) => setState(() => _o.scheduleEnabled = v),
                  ),
                  if (_o.scheduleEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(true),
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: Text(
                                      'از ${_fmt(_o.startHour, _o.startMinute)}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickTime(false),
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: Text(
                                      'تا ${_fmt(_o.endHour, _o.endMinute)}'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 0,
                            children: weekDayLabels.entries
                                .map((e) => FilterChip(
                                      label: Text(e.value,
                                          style: const TextStyle(fontSize: 12)),
                                      selected: _o.days.contains(e.key),
                                      onSelected: (sel) => setState(() {
                                        if (sel) {
                                          _o.days.add(e.key);
                                        } else {
                                          _o.days.remove(e.key);
                                        }
                                      }),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                value: _o.ignoreGlobalSchedule,
                activeThumbColor: Colors.orange,
                title: const Text('حتی خارج از زمان‌بندی کلی هم آلارم بزن',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                    'برای موارد مهم که در ساعت خواب هم نباید از دست بروند.',
                    style: TextStyle(fontSize: 11.5)),
                onChanged: (v) => setState(() => _o.ignoreGlobalSchedule = v),
              ),
            ),

            const SizedBox(height: 22),
            Row(
              children: [
                TextButton(
                    onPressed: _saving ? null : _reset,
                    child: const Text('بازگشت به پیش‌فرض')),
                const Spacer(),
                TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    child: const Text('انصراف')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Text('ذخیره')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
