import 'package:flutter/material.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/services/tutorial_service.dart';
import 'package:pezhvak/utils/week_days.dart';

/// Global alarm schedule: time window and days of the week (premium).
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool get _isPremium => PremiumService.status.value;
  bool _enabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);

  // Day indexes follow Android's Calendar: 1 = Sunday ... 7 = Saturday.
  final List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    PremiumService.status.addListener(_onPremiumChanged);
    _loadSchedule();
    TutorialService.showIfNew(
      context,
      key: 'schedule',
      icon: Icons.schedule,
      title: 'زمان‌بندی آلارم',
      color: Colors.deepOrange,
      steps: [
        'با این قابلیت آلارم فقط در ساعات و روزهای مشخصی فعال خواهد بود.',
        'مثال: آلارم فقط روزهای کاری از ساعت ۸ صبح تا ۱۰ شب فعال باشد.',
        'خارج از این بازه، نوتیفیکیشن‌ها نادیده گرفته می‌شوند.',
        'این قابلیت نیاز به اشتراک پریمیوم دارد.',
      ],
    );
  }

  @override
  void dispose() {
    PremiumService.status.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSchedule() async {
    final schedule = await ScheduleService.getSchedule();
    if (!mounted) return;
    setState(() {
      _enabled = schedule['enabled'] ?? false;
      _startTime = TimeOfDay(
        hour: schedule['start_hour'] ?? 8,
        minute: schedule['start_minute'] ?? 0,
      );
      _endTime = TimeOfDay(
        hour: schedule['end_hour'] ?? 22,
        minute: schedule['end_minute'] ?? 0,
      );
      final days = schedule['days'];
      if (days != null) {
        _selectedDays.clear();
        _selectedDays
            .addAll((days as List).map((e) => int.parse(e.toString())));
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ScheduleService.saveSchedule({
      'enabled': _enabled,
      'start_hour': _startTime.hour,
      'start_minute': _startTime.minute,
      'end_hour': _endTime.hour,
      'end_minute': _endTime.minute,
      'days': _selectedDays,
    });
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('زمان‌بندی ذخیره شد'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('زمان‌بندی آلارم'),
        actions: [
          if (_isPremium)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              onPressed: _saving ? null : _save,
              tooltip: 'ذخیره',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_isPremium
            ? _buildPremiumGate()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enabled/disabled card
                    Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        title: const Text('فعال کردن زمان‌بندی',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          _enabled
                              ? 'آلارم فقط در بازه زمانی مشخص شده فعال است'
                              : 'آلارم در تمام ساعات فعال است',
                          style: TextStyle(
                              color:
                                  _enabled ? Colors.green : Colors.grey[600]),
                        ),
                        value: _enabled,
                        activeThumbColor: Colors.orange,
                        onChanged: (val) => setState(() => _enabled = val),
                        secondary: Icon(
                          _enabled ? Icons.schedule : Icons.schedule_outlined,
                          color: _enabled ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_enabled) ...[
                      // Time window
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('بازه زمانی',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimeCard(
                                      label: 'شروع',
                                      time: _startTime,
                                      icon: Icons.play_circle_outline,
                                      color: Colors.green,
                                      onTap: () async {
                                        final t = await showTimePicker(
                                          context: context,
                                          initialTime: _startTime,
                                          builder: (ctx, child) => child!,
                                        );
                                        if (t != null) {
                                          setState(() => _startTime = t);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward,
                                      color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TimeCard(
                                      label: 'پایان',
                                      time: _endTime,
                                      icon: Icons.stop_circle_outlined,
                                      color: Colors.red,
                                      onTap: () async {
                                        final t = await showTimePicker(
                                          context: context,
                                          initialTime: _endTime,
                                          builder: (ctx, child) => child!,
                                        );
                                        if (t != null) {
                                          setState(() => _endTime = t);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Days of the week
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('روزهای هفته',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: weekDayLabels.entries.map((day) {
                                  final idx = day.key;
                                  final selected = _selectedDays.contains(idx);
                                  return FilterChip(
                                    label: Text(day.value),
                                    selected: selected,
                                    selectedColor:
                                        Colors.orange.withValues(alpha: 0.2),
                                    checkmarkColor: Colors.orange,
                                    onSelected: (val) {
                                      setState(() {
                                        if (val) {
                                          _selectedDays.add(idx);
                                        } else {
                                          _selectedDays.remove(idx);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Summary
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'آلارم از ساعت ${_formatTime(_startTime)} تا ${_formatTime(_endTime)} فعال خواهد بود.',
                                  style: const TextStyle(
                                      color: Colors.orange, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('ذخیره تنظیمات',
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPremiumGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.deepOrange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.lock, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('قابلیت پریمیوم',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange)),
            const SizedBox(height: 12),
            const Text(
              'زمان‌بندی آلارم یک قابلیت پریمیوم است.\nبا خرید اشتراک می‌توانید ساعت و روز فعال بودن آلارم را تعیین کنید.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.black54, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => openPremiumPage(context),
              icon: const Icon(Icons.star),
              label: const Text('خرید اشتراک پریمیوم',
                  style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
