import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/core/prefs_keys.dart';
import 'package:pezhvak/pages/alarm_history_page.dart';
import 'package:pezhvak/pages/battery_guide_page.dart';
import 'package:pezhvak/pages/diagnostics_page.dart';
import 'package:pezhvak/pages/notification_history_page.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/pages/schedule_page.dart';
import 'package:pezhvak/services/foreground_service.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/services/system_service.dart';
import 'package:pezhvak/services/tutorial_service.dart';
import 'package:pezhvak/widgets/home_widgets.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home tab: service status, quick stats, settings and tools.
class HomePage extends StatefulWidget {
  final bool showNotificationDetails;
  final bool showSourceApp;
  final Future<void> Function() onToggleDetails;
  final Future<void> Function() onToggleSourceApp;

  const HomePage({
    super.key,
    required this.showNotificationDetails,
    required this.showSourceApp,
    required this.onToggleDetails,
    required this.onToggleSourceApp,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

const String _kPackageName = 'ir.fastflutter.pezhvak';

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  PezhvakServiceStatus? _health;
  Timer? _healthTimer;
  DailySummarySettings _summary =
      const DailySummarySettings(enabled: true, hour: 22, minute: 0);
  int _historyCount = 0;
  int _alarmCount = 0;
  bool _scheduleEnabled = false;
  bool get _isPremium => PremiumService.status.value;
  bool _serviceEnabled = true;
  bool _ratedByUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PremiumService.status.addListener(_onPremiumChanged);
    _loadHealth();
    _loadSummary();
    // Refresh the service status every few seconds while the home page is open.
    _healthTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _loadHealth());
    _loadStats();
    _loadServiceState();
    _initMyket();
    _showHomeTutorial();
  }

  void _showHomeTutorial() {
    TutorialService.showIfNew(
      context,
      key: 'home',
      icon: Icons.notifications_active,
      title: 'خوش آمدید به پژواک',
      color: Colors.orange,
      steps: [
        'پژواک نوتیفیکیشن‌های مهم شما را شناسایی کرده و آلارم صوتی فعال می‌کند.',
        'از تب «برنامه‌ها» اپ‌هایی که می‌خواهید مانیتور شوند را انتخاب کنید.',
        'از تب «هشدارها» کلمات کلیدی و عناوینی که باید آلارم بزنند را وارد کنید.',
        'هشدارها برای همه برنامه‌ها کار می‌کنند، حتی اپ‌هایی که انتخاب نکرده‌اید.',
        'برای توقف اضطراری آلارم، دکمه 🔇 بالای صفحه را بزنید.',
      ],
    );
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    PremiumService.status.removeListener(_onPremiumChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadHealth();
  }

  void _onPremiumChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHealth() async {
    final h = await SystemService.getServiceStatus();
    if (mounted) setState(() => _health = h);
  }

  Future<void> _loadSummary() async {
    final s = await SystemService.getDailySummary();
    if (mounted) setState(() => _summary = s);
  }

  Future<void> _setSummary(DailySummarySettings s) async {
    setState(() => _summary = s);
    await SystemService.setDailySummary(s);
  }

  Future<void> _pickSummaryTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _summary.hour, minute: _summary.minute),
      helpText: 'ساعت ارسال خلاصه‌ی روزانه',
    );
    if (t == null) return;
    await _setSummary(
        _summary.copyWith(enabled: true, hour: t.hour, minute: t.minute));
  }

  Future<void> _testAlarm() async {
    final delay = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.alarm_on_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('تست آلارم', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          'یک آلارم آزمایشی دقیقاً مثل آلارم واقعی بالا می‌آید تا مطمئن شوید صدا، '
          'نمایش روی صفحه و مجوزها درست کار می‌کنند.\n\n'
          'برای تست روی صفحه‌ی قفل، «۱۰ ثانیه دیگر» را بزنید و صفحه را قفل کنید.',
          style: TextStyle(height: 1.8, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 10),
              child: const Text('۱۰ ثانیه دیگر')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('همین حالا')),
        ],
      ),
    );
    if (delay == null) return;
    await SystemService.testAlarm(delaySeconds: delay);
    if (delay > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'آلارم آزمایشی تا ۱۰ ثانیه دیگر می‌زند؛ می‌توانید صفحه را قفل کنید'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Service health banner; shown only when something is wrong.
  Widget _buildHealthBanner() {
    final h = _health;
    if (h == null || !h.serviceEnabled) return const SizedBox.shrink();

    final issues = <Widget>[];
    if (!h.notificationAccess) {
      issues.add(HealthIssue(
        icon: Icons.hearing_disabled_rounded,
        color: Colors.red,
        title: 'دسترسی خواندن اعلان‌ها قطع است',
        subtitle: 'بدون این دسترسی هیچ آلارمی نمی‌زند.',
        action: 'فعال‌سازی',
        onTap: () async {
          await NotificationListenerService.requestPermission();
          _loadHealth();
        },
      ));
    } else if (!h.listenerConnected) {
      issues.add(HealthIssue(
        icon: Icons.link_off_rounded,
        color: Colors.deepOrange,
        title: 'پایش نوتیفیکیشن‌ها وصل نیست',
        subtitle: 'تا وصل شدن دوباره، آلارم‌ها ممکن است از دست بروند.',
        action: 'اتصال مجدد',
        onTap: () async {
          await SystemService.rebindListener();
          await Future.delayed(const Duration(seconds: 2));
          _loadHealth();
        },
      ));
    }
    if (!h.ignoringBatteryOptimizations) {
      issues.add(HealthIssue(
        icon: Icons.battery_alert_rounded,
        color: Colors.amber.shade800,
        title: 'بهینه‌سازی باتری فعال است',
        subtitle: 'ممکن است سیستم سرویس پژواک را در پس‌زمینه ببندد.',
        action: 'راهنما',
        onTap: () => _push(const BatteryGuidePage()),
      ));
    }
    if (issues.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: issues),
    );
  }

  Future<void> _initMyket() async {
    final prefs = await SharedPreferences.getInstance();
    final rated = prefs.getBool(PrefsKeys.myketRated) ?? false;
    final opens = prefs.getInt(PrefsKeys.appOpenCount) ?? 0;
    final newOpens = opens + 1;
    await prefs.setInt(PrefsKeys.appOpenCount, newOpens);
    if (mounted) setState(() => _ratedByUser = rated);
    if (!rated && newOpens % 10 == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRateDialog();
      });
    }
    // Check for updates
    launchUrl(Uri.parse('myket://check-update?id=$_kPackageName'),
            mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }

  Future<void> _openRate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.myketRated, true);
    if (mounted) setState(() => _ratedByUser = true);
    await launchUrl(Uri.parse('myket://comment?id=$_kPackageName'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _openDeveloperApps() async {
    await launchUrl(Uri.parse('myket://developer/$_kPackageName'),
        mode: LaunchMode.externalApplication);
  }

  void _showRateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.star_rounded, color: Colors.amber, size: 26),
          SizedBox(width: 8),
          Text('نظر شما مهم است', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          'آیا از پژواک راضی هستید؟\nلطفاً در مایکت نظر خود را ثبت کنید.',
          style: TextStyle(height: 1.7, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بیخیال', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openRate();
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('نظردهی'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(PrefsKeys.serviceEnabled) ?? true;
    if (mounted) setState(() => _serviceEnabled = enabled);
  }

  void _showServicePremiumHint() => openPremiumPage(context);

  Future<void> _toggleService() async {
    final newState = !_serviceEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.serviceEnabled, newState);
    if (newState) {
      await ForegroundServiceChannel.startService();
    } else {
      await ForegroundServiceChannel.stopService();
    }
    if (mounted) setState(() => _serviceEnabled = newState);
  }

  Future<void> _loadStats() async {
    final histCount = await NotificationHistoryService.getCount();
    final alarmCount = await AlarmHistoryService.getCount();
    final schedule = await ScheduleService.getSchedule();
    _loadHealth();
    if (mounted) {
      setState(() {
        _historyCount = histCount;
        _alarmCount = alarmCount;
        _scheduleEnabled = schedule['enabled'] ?? false;
      });
    }
  }

  void _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 900 ? width * 0.08 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('پژواک'),
            if (_isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.yellow),
                    SizedBox(width: 3),
                    Text('پریمیوم',
                        style: TextStyle(fontSize: 11, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_off),
            tooltip: 'توقف اضطراری آلارم',
            onPressed: Restart.restartApp,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBanner(
                  enabled: _serviceEnabled,
                  isPremium: _isPremium,
                  onToggle:
                      _isPremium ? _toggleService : _showServicePremiumHint,
                ),
                _buildHealthBanner(),
                const SizedBox(height: 16),

                // Quick stats
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        icon: Icons.history_rounded,
                        count: _historyCount,
                        label: 'نوتیفیکیشن‌ها',
                        color: Colors.indigo,
                        onTap: () => _push(const NotificationHistoryPage()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        icon: Icons.alarm_rounded,
                        count: _alarmCount,
                        label: 'آلارم‌ها',
                        color: Colors.red,
                        onTap: () => _push(const AlarmHistoryPage()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Settings
                SectionTitle('تنظیمات'),
                const SizedBox(height: 8),
                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: Icons.audiotrack_rounded,
                      iconColor: Colors.amber.shade700,
                      title: 'صدای آلارم',
                      subtitle: 'انتخاب فایل صوتی',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _pickAudio,
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: widget.showNotificationDetails
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      iconColor: widget.showNotificationDetails
                          ? Colors.green
                          : Colors.grey,
                      title: 'نمایش متن نوتیفیکیشن',
                      subtitle: widget.showNotificationDetails
                          ? 'متن روی صفحه نمایش داده می‌شود'
                          : 'متن مخفی است',
                      trailing: Switch(
                        value: widget.showNotificationDetails,
                        onChanged: (_) async {
                          await widget.onToggleDetails();
                          setState(() {});
                        },
                        activeThumbColor: Colors.orange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () async {
                        await widget.onToggleDetails();
                        setState(() {});
                      },
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: widget.showSourceApp
                          ? Icons.apps_rounded
                          : Icons.apps_outage_rounded,
                      iconColor:
                          widget.showSourceApp ? Colors.blue : Colors.grey,
                      title: 'نمایش برنامه‌ی ردیابی‌شده',
                      subtitle: widget.showSourceApp
                          ? 'نام برنامه‌ی فرستنده روی صفحه‌ی آلارم نوشته می‌شود'
                          : 'نام برنامه‌ی فرستنده روی صفحه‌ی آلارم مخفی است',
                      trailing: Switch(
                        value: widget.showSourceApp,
                        onChanged: (_) async {
                          await widget.onToggleSourceApp();
                          setState(() {});
                        },
                        activeThumbColor: Colors.orange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: () async {
                        await widget.onToggleSourceApp();
                        setState(() {});
                      },
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.summarize_rounded,
                      iconColor: _summary.enabled ? Colors.teal : Colors.grey,
                      title: 'خلاصه‌ی روزانه',
                      subtitle: _summary.enabled
                          ? 'هر شب ساعت ${_summary.timeLabel} (برای تغییر ساعت بزنید)'
                          : 'غیرفعال',
                      trailing: Switch(
                        value: _summary.enabled,
                        onChanged: (v) =>
                            _setSummary(_summary.copyWith(enabled: v)),
                        activeThumbColor: Colors.orange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onTap: _pickSummaryTime,
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.schedule_rounded,
                      iconColor: Colors.deepOrange,
                      title: 'زمان‌بندی آلارم',
                      subtitle: _scheduleEnabled ? 'فعال' : 'غیرفعال',
                      badge: !_isPremium ? '🔒' : null,
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _push(const SchedulePage()),
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.star_rounded,
                      iconColor:
                          _isPremium ? Colors.amber.shade600 : Colors.grey,
                      title: 'اشتراک پریمیوم',
                      subtitle: _isPremium ? 'پریمیوم فعال است' : 'ارتقا دهید',
                      trailing: _isPremium
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Text('فعال',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold)),
                            )
                          : const Icon(Icons.chevron_left, size: 20),
                      onTap: () => _push(const PremiumPage()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Myket
                SectionTitle('مایکت'),
                const SizedBox(height: 8),
                SettingsCard(
                  children: [
                    if (!_ratedByUser)
                      SettingsRow(
                        icon: Icons.star_rounded,
                        iconColor: Colors.amber.shade700,
                        title: 'ثبت نظر',
                        subtitle: 'نظر شما به بهبود پژواک کمک می‌کند',
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: _openRate,
                      ),
                    if (!_ratedByUser) SettingsDivider(),
                    SettingsRow(
                      icon: Icons.apps_rounded,
                      iconColor: Colors.teal,
                      title: 'سایر برنامه‌های فست فلاتر',
                      subtitle: 'مشاهده در مایکت',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _openDeveloperApps,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Help and restart
                SectionTitle('ابزار'),
                const SizedBox(height: 8),
                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: Icons.help_outline_rounded,
                      iconColor: Colors.teal,
                      title: 'راهنما و آموزش',
                      subtitle: 'مشاهده مجدد آموزش تمام صفحات',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () async {
                        await TutorialService.resetAll();
                        if (!context.mounted) return;
                        _showHomeTutorial();
                      },
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.alarm_on_rounded,
                      iconColor: Colors.red,
                      title: 'تست آلارم',
                      subtitle:
                          'مطمئن شوید آلارم، صدا و مجوزها درست کار می‌کنند',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: _testAlarm,
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.battery_charging_full_rounded,
                      iconColor: Colors.green,
                      title: 'ماندگاری در پس‌زمینه',
                      subtitle: 'تنظیمات باتری و شروع خودکار مخصوص گوشی شما',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _push(const BatteryGuidePage()),
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.monitor_heart_rounded,
                      iconColor: Colors.redAccent,
                      title: 'گزارش پایداری',
                      subtitle: 'دلیل بسته شدن برنامه و وضعیت سرویس',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _push(const DiagnosticsPage()),
                    ),
                    SettingsDivider(),
                    SettingsRow(
                      icon: Icons.restart_alt_rounded,
                      iconColor: Colors.blueGrey,
                      title: 'ریستارت سرویس',
                      subtitle: 'توقف همه آلارم‌های فعال و راه‌اندازی مجدد',
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: Restart.restartApp,
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    final picked = result?.files.single.path;
    if (picked == null) return;

    var success = false;
    try {
      final stored =
          await SoundStorage.import(picked, folder: SoundStorage.alarmFolder);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.alarmAudio, stored);
      await SoundStorage.delete(selectedAudioPath);
      selectedAudioPath = stored;
      success = true;
    } catch (e) {
      debugPrint('Failed to import the alarm sound: $e');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(success ? 'فایل صوتی انتخاب شد' : 'انتخاب فایل صوتی ناموفق بود'),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}
