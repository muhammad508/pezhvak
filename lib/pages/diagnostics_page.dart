import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pezhvak/services/system_service.dart';
import 'package:pezhvak/utils/history_tools.dart';

/// Service health and the log of process exits, crashes and listener events.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  List<Map<String, dynamic>> _events = [];
  PezhvakServiceStatus? _status;
  DeviceInfo? _device;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final events = await SystemService.getDiagnostics();
    final status = await SystemService.getServiceStatus();
    final device = await SystemService.getDeviceInfo();
    if (!mounted) return;
    setState(() {
      _events = events;
      _status = status;
      _device = device;
      _loading = false;
    });
  }

  Future<void> _rebind() async {
    await SystemService.rebindListener();
    await Future.delayed(const Duration(seconds: 2));
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_status?.listenerConnected == true
          ? 'اتصال برقرار شد'
          : 'هنوز متصل نیست؛ چند ثانیه بعد دوباره بررسی کنید'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _copyReport() async {
    final buf = StringBuffer()
      ..writeln('Pezhvak diagnostics')
      ..writeln('device: ${_device?.label ?? '-'}')
      ..writeln(
          'status: ${_status == null ? '-' : 'enabled=${_status!.serviceEnabled} access=${_status!.notificationAccess} connected=${_status!.listenerConnected} battery=${_status!.ignoringBatteryOptimizations} exact=${_status!.exactAlarms}'}')
      ..writeln();
    for (final e in _events) {
      buf.writeln('[${formatTimestamp(e['ts'])}] ${e['type']}: ${e['title']}');
      final detail = (e['detail'] ?? '').toString();
      if (detail.isNotEmpty) buf.writeln(detail);
      final extra = e['extra'];
      if (extra != null) buf.writeln(json.encode(extra));
      buf.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('گزارش کپی شد'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن گزارش'),
        content: const Text('آیا مطمئن هستید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('پاک کن')),
        ],
      ),
    );
    if (ok == true) {
      await SystemService.clearDiagnostics();
      _load();
    }
  }

  /// Persian explanation for a process exit reason (ApplicationExitInfo).
  String? _exitHint(Map<String, dynamic> e) {
    final extra = e['extra'];
    if (extra is! Map) return null;
    final detail = (e['detail'] ?? '').toString().toLowerCase();
    switch (extra['reasonName']) {
      case 'LOW_MEMORY':
        return 'سیستم برای آزاد کردن حافظه برنامه را بست.';
      case 'CRASH':
      case 'CRASH_NATIVE':
        if (detail.contains('foregroundservice')) {
          return 'سقف زمانی سرویس پیش‌زمینه تمام شد و برنامه کشته شد.';
        }
        return 'برنامه کرش کرد. متن گزارش را کپی کنید و برای پشتیبانی بفرستید.';
      case 'ANR':
        return 'برنامه پاسخ نداد (ANR) و سیستم آن را بست.';
      case 'SIGNALED':
        return 'برنامه توسط سیستم یا مدیریت باتری سازنده‌ی گوشی کشته شد. راهنمای ماندگاری را ببینید.';
      case 'EXCESSIVE_RESOURCE_USAGE':
        return 'سیستم به‌خاطر مصرف زیاد منابع برنامه را بست.';
      case 'USER_REQUESTED':
      case 'USER_STOPPED':
        return 'برنامه به‌صورت دستی (Force Stop یا پاک کردن از برنامه‌های اخیر) بسته شد.';
      case 'PERMISSION_CHANGE':
        return 'با تغییر یک مجوز، سیستم برنامه را ری‌استارت کرد.';
      case 'FREEZER':
        return 'سیستم برنامه را برای صرفه‌جویی منجمد کرد.';
      case 'PACKAGE_UPDATED':
        return 'برنامه آپدیت شد.';
      case 'EXIT_SELF':
        return 'برنامه خودش بسته شد (مثلاً ریستارت).';
      default:
        return null;
    }
  }

  (IconData, Color) _iconFor(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'crash':
        return (Icons.bug_report_rounded, Colors.red);
      case 'fgs_timeout':
        return (Icons.timer_off_rounded, Colors.deepOrange);
      case 'listener':
        return (Icons.hearing_disabled_rounded, Colors.orange);
      case 'watchdog':
        return (Icons.shield_rounded, Colors.blue);
      case 'error':
        return (Icons.error_outline_rounded, Colors.red);
      case 'exit':
        final extra = e['extra'];
        final name = extra is Map ? extra['reasonName'] : null;
        final bad = name == 'CRASH' ||
            name == 'CRASH_NATIVE' ||
            name == 'ANR' ||
            name == 'LOW_MEMORY' ||
            name == 'SIGNALED';
        return (
          Icons.power_settings_new_rounded,
          bad ? Colors.red : Colors.grey
        );
      default:
        return (Icons.info_outline_rounded, Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش پایداری'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'کپی گزارش',
            onPressed: _loading ? null : _copyReport,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'پاک کردن گزارش',
            onPressed: _loading || _events.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    Text('رویدادها',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    if (_events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('هنوز رویدادی ثبت نشده است',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      ..._events.map(_buildEvent),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final s = _status;
    if (s == null) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('وضعیت سرویس در دسترس نیست')));
    }
    Widget row(String label, bool ok, {String? hint}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: ok ? Colors.green : Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13)),
                    if (!ok && hint != null)
                      Text(hint,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_device != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_device!.label,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            row('سرویس پایش فعال است', s.serviceEnabled),
            row('دسترسی خواندن اعلان‌ها', s.notificationAccess,
                hint: 'از تنظیمات سیستم دسترسی را فعال کنید'),
            row('اتصال لیسنر نوتیفیکیشن', s.listenerConnected,
                hint: 'با دکمه‌ی زیر اتصال مجدد را امتحان کنید'),
            row('معافیت از بهینه‌سازی باتری', s.ignoringBatteryOptimizations,
                hint: 'راهنمای ماندگاری در پس‌زمینه را ببینید'),
            row('الارم دقیق مجاز است', s.exactAlarms,
                hint: 'نگهبان با الارم غیردقیق (کمی دیرتر) کار می‌کند'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _rebind,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تلاش برای اتصال مجدد'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvent(Map<String, dynamic> e) {
    final (icon, color) = _iconFor(e);
    final hint = e['type'] == 'exit' ? _exitHint(e) : null;
    final detail = (e['detail'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((e['title'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(formatTimestamp(e['ts']),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (hint != null) ...[
                    const SizedBox(height: 6),
                    Text(hint,
                        style: const TextStyle(fontSize: 12, height: 1.5)),
                  ],
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[600],
                          fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
