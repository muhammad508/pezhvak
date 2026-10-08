import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pezhvak/app.dart';
import 'package:pezhvak/core/app_globals.dart';

/// Requests the permissions the app needs before the main UI starts.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _requesting = false;
  List<_PermItem> _missing = [];
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _checkPermissions();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final missing = <_PermItem>[];

    if (!await Permission.systemAlertWindow.isGranted) {
      missing.add(_PermItem(
        icon: Icons.layers_rounded,
        title: 'نمایش روی برنامه‌ها',
        desc: 'برای نمایش آلارم روی هر صفحه‌ای',
        color: Colors.deepOrange,
      ));
    }

    if (!await Permission.notification.isGranted) {
      missing.add(_PermItem(
        icon: Icons.notifications_rounded,
        title: 'اعلان‌ها',
        desc: 'برای ارسال نوتیفیکیشن هشدار',
        color: Colors.blue,
      ));
    }

    if (!await NotificationListenerService.isPermissionGranted()) {
      missing.add(_PermItem(
        icon: Icons.hearing_rounded,
        title: 'خواندن اعلان‌ها',
        desc: 'برای بررسی نوتیفیکیشن‌های دریافتی',
        color: Colors.purple,
      ));
    }

    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      missing.add(_PermItem(
        icon: Icons.battery_saver_rounded,
        title: 'غیرفعال‌سازی بهینه‌سازی باتری',
        desc: 'تا سیستم سرویس پژواک را در پس‌زمینه نبندد',
        color: Colors.green,
      ));
    }

    if (missing.isEmpty) {
      _enterApp();
      return;
    }

    setState(() {
      _missing = missing;
      _loading = false;
    });
    _animCtrl.forward();
  }

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);
    await Permission.storage.request();
    await Permission.systemAlertWindow.request();
    await Permission.notification.request();

    if (!await NotificationListenerService.isPermissionGranted()) {
      await NotificationListenerService.requestPermission();
    }

    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    setState(() => _requesting = false);
    _animCtrl.reset();
    setState(() => _loading = true);
    _checkPermissions();
  }

  Future<void> _enterApp() async {
    await _initializeNotifications();
    runApp(const MyApp());
  }

  Future<void> _initializeNotifications() async {
    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.pendingNotificationRequests();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  // Main icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade400
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.security_rounded,
                        size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'نیاز به دسترسی',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'برای کارکرد صحیح پژواک،\nمجوزهای زیر را فعال کنید',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Permission cards
                  ..._missing.map((item) => _PermCard(item: item)),
                  const Spacer(),
                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _requesting ? null : _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: _requesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'اعطای دسترسی',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermItem {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _PermItem(
      {required this.icon,
      required this.title,
      required this.desc,
      required this.color});
}

class _PermCard extends StatelessWidget {
  final _PermItem item;
  const _PermCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(item.desc,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              color: item.color.withValues(alpha: 0.6), size: 18),
        ],
      ),
    );
  }
}
