import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pezhvak/services/system_service.dart';

/// Background-survival guide; the steps depend on the phone manufacturer.
class BatteryGuidePage extends StatefulWidget {
  const BatteryGuidePage({super.key});

  @override
  State<BatteryGuidePage> createState() => _BatteryGuidePageState();
}

class _BrandGuide {
  final String name;
  final List<String> steps;
  const _BrandGuide(this.name, this.steps);
}

class _BatteryGuidePageState extends State<BatteryGuidePage>
    with WidgetsBindingObserver {
  DeviceInfo? _device;
  PezhvakServiceStatus? _status;

  static const _generic = _BrandGuide('اندروید', [
    'تنظیمات ← برنامه‌ها ← پژواک ← باتری را باز کنید.',
    'گزینه‌ی «بدون محدودیت» (Unrestricted) را انتخاب کنید.',
    'اگر گزینه‌ی «شروع خودکار» یا «اجرا در پس‌زمینه» دارید، روشن کنید.',
  ]);

  static const _guides = <String, _BrandGuide>{
    'xiaomi': _BrandGuide('شیائومی / ردمی / پوکو', [
      'تنظیمات ← برنامه‌ها ← مدیریت برنامه‌ها ← پژواک ← «شروع خودکار» (Autostart) را روشن کنید.',
      'همان صفحه: «صرفه‌جویی باتری» ← «بدون محدودیت».',
      'در صفحه‌ی برنامه‌های اخیر، روی کارت پژواک نگه دارید و آیکون قفل 🔒 را بزنید.',
    ]),
    'samsung': _BrandGuide('سامسونگ', [
      'تنظیمات ← باتری ← محدودیت‌های استفاده در پس‌زمینه ← «برنامه‌هایی که هرگز نمی‌خوابند» ← پژواک را اضافه کنید.',
      'تنظیمات ← برنامه‌ها ← پژواک ← باتری ← «بدون محدودیت».',
      'گزینه‌ی «خواب خودکار برنامه‌های استفاده‌نشده» را برای پژواک غیرفعال کنید.',
    ]),
    'huawei': _BrandGuide('هواوی / آنر', [
      'تنظیمات ← برنامه‌ها ← راه‌اندازی برنامه ← پژواک ← «مدیریت دستی».',
      'هر سه گزینه‌ی «راه‌اندازی خودکار»، «راه‌اندازی ثانویه» و «اجرا در پس‌زمینه» را روشن کنید.',
    ]),
    'oppo': _BrandGuide('اوپو / ریلمی / وان‌پلاس', [
      'تنظیمات ← باتری ← مصرف باتری برنامه‌ها ← پژواک ← «اجازه‌ی فعالیت در پس‌زمینه» و «شروع خودکار» را روشن کنید.',
      'در صفحه‌ی برنامه‌های اخیر، کارت پژواک را قفل کنید.',
    ]),
    'vivo': _BrandGuide('ویوو / آی‌کیو', [
      'تنظیمات ← باتری ← مصرف پس‌زمینه ← پژواک ← «اجازه‌ی اجرای پس‌زمینه با مصرف زیاد».',
      'iManager ← مدیریت برنامه‌ها ← شروع خودکار ← پژواک را روشن کنید.',
    ]),
  };

  static const _aliases = <String, String>{
    'redmi': 'xiaomi',
    'poco': 'xiaomi',
    'honor': 'huawei',
    'realme': 'oppo',
    'oneplus': 'oppo',
    'iqoo': 'vivo',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh the status after returning from the system settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final device = await SystemService.getDeviceInfo();
    final status = await SystemService.getServiceStatus();
    if (!mounted) return;
    setState(() {
      _device = device;
      _status = status;
    });
  }

  _BrandGuide get _guide {
    final hay = '${_device?.manufacturer} ${_device?.brand}'.toLowerCase();
    for (final key in _guides.keys) {
      if (hay.contains(key)) return _guides[key]!;
    }
    for (final entry in _aliases.entries) {
      if (hay.contains(entry.key)) return _guides[entry.value]!;
    }
    return _generic;
  }

  Future<void> _requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
    _load();
  }

  Future<void> _openAutoStart() async {
    final specific = await SystemService.openAutoStartSettings();
    if (!specific && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('صفحه‌ی اختصاصی گوشی پیدا نشد؛ تنظیمات برنامه باز شد'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    final status = _status;
    final batteryOk = status?.ignoringBatteryOptimizations ?? false;
    final accessOk = status?.notificationAccess ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('ماندگاری در پس‌زمینه')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بعضی گوشی‌ها برنامه‌های پس‌زمینه را خودسرانه می‌بندند. '
                      'برای اینکه پژواک همیشه گوش‌به‌زنگ بماند، این تنظیمات را یک‌بار انجام دهید.',
                      style: TextStyle(fontSize: 13, height: 1.7),
                    ),
                    if (_device != null) ...[
                      const SizedBox(height: 8),
                      Text(_device!.label,
                          textDirection: TextDirection.ltr,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _actionTile(
              icon: Icons.battery_saver_rounded,
              color: Colors.green,
              title: 'معافیت از بهینه‌سازی باتری',
              subtitle: batteryOk ? 'فعال است ✓' : 'هنوز فعال نشده',
              done: batteryOk,
              onTap: _requestBatteryExemption,
            ),
            _actionTile(
              icon: Icons.hearing_rounded,
              color: Colors.purple,
              title: 'دسترسی خواندن اعلان‌ها',
              subtitle: accessOk ? 'فعال است ✓' : 'هنوز فعال نشده',
              done: accessOk,
              onTap: () async {
                await NotificationListenerService.requestPermission();
                _load();
              },
            ),
            _actionTile(
              icon: Icons.rocket_launch_rounded,
              color: Colors.deepOrange,
              title: 'شروع خودکار / اجرا در پس‌زمینه',
              subtitle: 'باز کردن صفحه‌ی تنظیمات مخصوص ${guide.name}',
              done: false,
              onTap: _openAutoStart,
            ),
            _actionTile(
              icon: Icons.settings_applications_rounded,
              color: Colors.blueGrey,
              title: 'اطلاعات برنامه',
              subtitle: 'باتری، مجوزها و حافظه‌ی پژواک',
              done: false,
              onTap: openAppSettings,
            ),
            const SizedBox(height: 20),
            Text('مراحل مخصوص ${guide.name}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500])),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < guide.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.15),
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(guide.steps[i],
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.7)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('نکته‌های عمومی',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500])),
            const SizedBox(height: 8),
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '• حالت «صرفه‌جویی باتری» را خاموش نگه دارید.\n'
                  '• پژواک را از برنامه‌های اخیر حذف (Swipe) نکنید؛ در بعضی گوشی‌ها این کار سرویس را می‌بندد.\n'
                  '• اگر آلارم‌ها بعد از مدتی قطع می‌شود، «گزارش پایداری» دلیل دقیق را نشان می‌دهد.',
                  style: TextStyle(fontSize: 13, height: 1.9),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool done,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(
            done ? Icons.check_circle_rounded : Icons.chevron_left_rounded,
            color: done ? Colors.green : Colors.grey[400]),
      ),
    );
  }
}
