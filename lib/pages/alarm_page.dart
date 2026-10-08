import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/core/prefs_keys.dart';
import 'package:pezhvak/services/services.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';

/// Full-screen alarm shown when a rule matches; plays sound and vibration until dismissed.
class AlarmPage extends StatefulWidget {
  final Map<String, dynamic> alarm;
  final bool showNotificationDetails;
  final bool showSourceApp;

  const AlarmPage(
      {super.key,
      required this.alarm,
      this.showNotificationDetails = true,
      this.showSourceApp = true});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> with TickerProviderStateMixin {
  bool _dismissed = false;

  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _ringAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.linear));

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );

    _playAlarm();
    _startVibration();
  }

  bool get _isTest => widget.alarm['is_test'] == true;

  // Per-rule vibration (premium): off | gentle | strong
  Future<void> _startVibration() async {
    final mode = (widget.alarm['vibration'] ?? 'off').toString();
    if (mode == 'off') return;
    try {
      if (await Vibration.hasVibrator() != true) return;
      final pattern =
          mode == 'strong' ? [0, 1000, 400, 1000, 400] : [0, 500, 1200];
      await Vibration.vibrate(pattern: pattern, repeat: 0);
    } catch (e) {
      debugPrint('Failed to start the vibration: $e');
    }
  }

  @override
  void dispose() {
    Vibration.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _playAlarm() async {
    // Maximum volume (the plugin clamps the value to 1.0).
    await VolumeController.instance.setVolume(1.0);
    if (isAlarmPlaying) return;
    isAlarmPlaying = true;
    await alarmPlayer.setReleaseMode(ReleaseMode.loop);
    try {
      await alarmPlayer.play(await _resolveSound());
    } catch (e) {
      debugPrint('Failed to play the alarm sound: $e');
    }
  }

  /// The rule's own sound (premium), then the sound the user picked, then the bundled default.
  /// A custom file that no longer exists is skipped, so an alarm never ends up silent.
  Future<Source> _resolveSound() async {
    final prefs = await SharedPreferences.getInstance();
    selectedAudioPath = prefs.getString(PrefsKeys.alarmAudio);
    for (final path in [widget.alarm['sound_path'], selectedAudioPath]) {
      if (path is String && path.isNotEmpty && await File(path).exists()) {
        return DeviceFileSource(path);
      }
    }
    // The bundled default sound is not included in the public repository (see assets/README.md);
    // without it the alarm is silent unless the user or a rule picked a sound.
    return AssetSource('audio.mp3');
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    setState(() => _dismissed = true);

    final packageName = widget.alarm['package_name'] as String? ?? '';
    final appName = widget.alarm['app_name'] as String? ?? '';

    Vibration.cancel();

    // Test alarm: no 5-minute suppression and no explanation dialog; just close it and restart the app normally.
    if (_isTest) {
      await AlarmStateManager.clearNotification();
      isAlarmPlaying = false;
      await alarmPlayer.dispose();
      alarmPlayer = AudioPlayer();
      await Restart.restartApp();
      return;
    }

    if (packageName.isNotEmpty) {
      await SuppressedAppsService.suppressApp(packageName);
    }

    await AlarmStateManager.clearNotification();
    isAlarmPlaying = false;
    await alarmPlayer.dispose();
    alarmPlayer = AudioPlayer();

    if (packageName.isNotEmpty && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1E1E2E),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_off_rounded,
                    color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('آلارم بسته شد',
                  style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: Text(
            '${widget.showSourceApp ? 'نوتیفیکیشن‌های "$appName"' : 'نوتیفیکیشن‌های این برنامه'} تا ۵ دقیقه آینده آلارم نخواهند داشت.\n\nبرای سایر برنامه‌ها آلارم همچنان فعال است.',
            style: const TextStyle(
                fontSize: 14, height: 1.7, color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      );
    }

    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            // Animated background rings
            AnimatedBuilder(
              animation: _ringAnim,
              builder: (_, __) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _RingPainter(_ringAnim.value),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  _AlertIcon(
                    animation: _pulseCtrl,
                    pulse: _pulseAnim,
                    shake: _shakeAnim,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'هشدار دریافت شد!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isTest
                        ? 'این یک آلارم آزمایشی است'
                        : 'یک نوتیفیکیشن مهم منتظر شماست',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _NotificationCard(
                      appName: alarm['app_name'] as String? ?? '',
                      title: alarm['title'] as String? ?? '',
                      text: alarm['text'] as String? ?? '',
                      showDetails: widget.showNotificationDetails,
                      showSourceApp: widget.showSourceApp,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _DismissButton(
                      pulse: _pulseAnim,
                      dismissed: _dismissed,
                      onTap: _dismiss,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isTest
                        ? 'با بستن هشدار، به برنامه برمی‌گردید'
                        : 'این اپ تا ۵ دقیقه آلارم نخواهد داشت',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pulsing, shaking bell at the top of the alarm screen.
class _AlertIcon extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> pulse;
  final Animation<double> shake;

  const _AlertIcon({
    required this.animation,
    required this.pulse,
    required this.shake,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Transform.scale(
        scale: pulse.value,
        child: Transform.rotate(
          angle: shake.value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.orange.shade300, Colors.deepOrange.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: pulse.value * 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card with the app name and the notification title and text (each can be hidden by the user).
class _NotificationCard extends StatelessWidget {
  final String appName;
  final String title;
  final String text;
  final bool showDetails;
  final bool showSourceApp;

  const _NotificationCard({
    required this.appName,
    required this.title,
    required this.text,
    required this.showDetails,
    required this.showSourceApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161628),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: showDetails ? _buildContent() : _buildHiddenNotice(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.09),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              showSourceApp ? Icons.apps_rounded : Icons.visibility_off_rounded,
              color: Colors.orange,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              showSourceApp ? appName : 'نام برنامه مخفی است',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'جدید',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (text.isNotEmpty) const SizedBox(height: 8),
        ],
        if (text.isNotEmpty)
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        if (title.isEmpty && text.isEmpty)
          Text(
            'بدون متن',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  Widget _buildHiddenNotice() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.visibility_off_rounded,
          color: Colors.white.withValues(alpha: 0.3),
          size: 17,
        ),
        const SizedBox(width: 8),
        Text(
          'عنوان و متن نوتیفیکیشن مخفی است',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// The big pulsing "dismiss" button; turns grey while the alarm is being closed.
class _DismissButton extends StatelessWidget {
  final Animation<double> pulse;
  final bool dismissed;
  final VoidCallback onTap;

  const _DismissButton({
    required this.pulse,
    required this.dismissed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => GestureDetector(
        onTap: dismissed ? null : onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: dismissed
                ? LinearGradient(
                    colors: [Colors.grey.shade800, Colors.grey.shade700])
                : LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade500
                    ],
                  ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: dismissed
                ? []
                : [
                    BoxShadow(
                      color: Colors.orange
                          .withValues(alpha: (pulse.value - 0.9) * 4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                dismissed
                    ? Icons.hourglass_top_rounded
                    : Icons.alarm_off_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                dismissed ? 'در حال بستن...' : 'بستن هشدار',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final maxRadius = size.width * 0.9;

    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3.0) % 1.0;
      final radius = maxRadius * t;
      final opacity = (1 - t) * 0.10;
      final paint = Paint()
        ..color = Colors.orange.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
