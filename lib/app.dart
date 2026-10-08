import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/core/app_theme.dart';
import 'package:pezhvak/core/prefs_keys.dart';
import 'package:pezhvak/pages/alarm_page.dart';
import 'package:pezhvak/pages/main_shell.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/services/purchase_service.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/utils/history_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root widget: themes, subscription sync, and routing between the alarm screen and the main UI.
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Subscription reminders start this many days before the expiry.
  static const int _expiryReminderDays = 3;

  bool showNotificationDetails = true;
  bool showSourceApp = true;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// Created once: a FutureBuilder given a fresh future on every build would reload on each rebuild.
  late final Future<void> _pendingAlarmLoad;

  @override
  void initState() {
    super.initState();
    _pendingAlarmLoad = _loadPendingAlarm();
    _init();
  }

  Future<void> _loadPendingAlarm() async {
    pendingAlarm = await AlarmStateManager.getStoredNotification();
    if (pendingAlarm != null) isAlarmPlaying = false;
  }

  Future<void> _init() async {
    await AppService.loadSelectedApps();
    final prefs = await SharedPreferences.getInstance();

    // Sync the subscription state from Myket (falling back to local storage)
    final expiry = await PurchaseService.checkSubscriptionExpiry();
    final now = DateTime.now();
    final premium = expiry != null && expiry.isAfter(now);

    if (mounted) {
      setState(() {
        showNotificationDetails =
            prefs.getBool(PrefsKeys.showNotificationDetails) ?? true;
        showSourceApp = prefs.getBool(PrefsKeys.showSourceApp) ?? true;
      });
    }
    if (expiry == null) return;

    // If a subscription existed but has expired, tell the user once
    if (!premium) {
      final millis = expiry.millisecondsSinceEpoch;
      if (prefs.getInt(PrefsKeys.premiumExpiryNotified) != millis) {
        await prefs.setInt(PrefsKeys.premiumExpiryNotified, millis);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSubscriptionDialog(
            icon: Icons.workspace_premium,
            color: Colors.orange,
            title: 'اشتراک منقضی شد',
            message:
                'اشتراک پریمیوم شما در تاریخ ${jalaliDate(expiry)} به پایان رسید.\n'
                'برای ادامه‌ی استفاده از امکانات پریمیوم، اشتراک خود را تمدید کنید.',
          );
        });
      }
      return;
    }

    // If the subscription is active but about to expire, remind the user once
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = expiryDay.difference(today).inDays;
    if (daysLeft > _expiryReminderDays) return;

    final millis = expiry.millisecondsSinceEpoch;
    if (prefs.getInt(PrefsKeys.premiumExpirySoonNotified) != millis) {
      await prefs.setInt(PrefsKeys.premiumExpirySoonNotified, millis);
      final remaining = daysLeft <= 0
          ? 'اشتراک پریمیوم شما امروز به پایان می‌رسد.'
          : 'تنها $daysLeft روز تا پایان اشتراک پریمیوم شما باقی مانده است.';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSubscriptionDialog(
          icon: Icons.access_time_filled,
          color: Colors.deepOrange,
          title: 'اشتراک رو به پایان',
          message: '$remaining\n'
              'تاریخ پایان: ${jalaliDate(expiry)}\n'
              'برای جلوگیری از قطع امکانات، همین حالا تمدید کنید.',
        );
      });
    }
  }

  /// Dialog with a "renew" shortcut, shared by the "expired" and "expires soon" reminders.
  void _showSubscriptionDialog({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    final navigatorContext = _navKey.currentContext;
    if (navigatorContext == null) return;
    showDialog(
      context: navigatorContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title),
        ]),
        content: Text(message, style: const TextStyle(height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                navigatorContext,
                MaterialPageRoute(
                  builder: (_) => const PremiumPage(),
                ),
              );
            },
            child: const Text('تمدید اشتراک'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => showNotificationDetails = !showNotificationDetails);
    await prefs.setBool(
        PrefsKeys.showNotificationDetails, showNotificationDetails);
  }

  Future<void> _toggleSourceApp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => showSourceApp = !showSourceApp);
    await prefs.setBool(PrefsKeys.showSourceApp, showSourceApp);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fa', ''), Locale('en', '')],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: rtlAppBuilder,
      home: FutureBuilder<void>(
        future: _pendingAlarmLoad,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final alarm = pendingAlarm;
          if (alarm != null) {
            return AlarmPage(
              alarm: alarm,
              showNotificationDetails: showNotificationDetails,
              showSourceApp: showSourceApp,
            );
          }
          return MainShell(
            showNotificationDetails: showNotificationDetails,
            showSourceApp: showSourceApp,
            onToggleDetails: _toggleDetails,
            onToggleSourceApp: _toggleSourceApp,
          );
        },
      ),
    );
  }
}
