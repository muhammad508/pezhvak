import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pezhvak/pages/alerts_page.dart' show AlertsPage;
import 'package:pezhvak/pages/apps_page.dart';
import 'package:pezhvak/pages/home_page.dart';
import 'package:pezhvak/services/tutorial_service.dart';

/// Bottom-navigation shell hosting the home, apps and rules tabs.
class MainShell extends StatefulWidget {
  final bool showNotificationDetails;
  final bool showSourceApp;
  final Future<void> Function() onToggleDetails;
  final Future<void> Function() onToggleSourceApp;

  const MainShell({
    super.key,
    required this.showNotificationDetails,
    required this.showSourceApp,
    required this.onToggleDetails,
    required this.onToggleSourceApp,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final Set<int> _visitedTabs = {0};

  void _onTabTap(int i) {
    final isNew = !_visitedTabs.contains(i);
    setState(() {
      _tab = i;
      _visitedTabs.add(i);
    });
    if (isNew) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _triggerTabTutorial(i));
    }
  }

  void _triggerTabTutorial(int i) {
    if (!mounted) return;
    if (i == 1) {
      TutorialService.showIfNew(
        context,
        key: 'apps',
        icon: Icons.apps,
        title: 'انتخاب برنامه‌ها',
        color: Colors.blue,
        steps: [
          'برنامه‌هایی که می‌خواهید پژواک زیر نظر داشته باشد را تیک بزنید.',
          'می‌توانید چندین برنامه همزمان انتخاب کنید.',
          'از باکس جستجو برای پیدا کردن سریع برنامه استفاده کنید.',
          'بعد از انتخاب، برنامه‌ها بلافاصله ذخیره می‌شوند.',
        ],
      );
    } else if (i == 2) {
      TutorialService.showIfNew(
        context,
        key: 'alerts',
        icon: Icons.notifications_active,
        title: 'کلمات و عناوین',
        color: Colors.deepOrange,
        steps: [
          'هر نوتیفیکیشنی که دریافت می‌شود بررسی می‌شود — حتی از برنامه‌هایی که انتخاب نکرده‌اید.',
          'کلمات کلیدی: اگر کلمه در متن (ساب‌تایتل) نوتیفیکیشن پیدا شود → آلارم فعال می‌شود.',
          'عناوین: اگر عبارت در تایتل نوتیفیکیشن پیدا شود → آلارم فعال می‌شود.',
          'جستجو جزئی است — کافیست بخشی از کلمه یا عنوان مطابقت داشته باشد.',
          'مثال: «واریز» هر پیامی که «واریز وجه» یا «واریز شد» داشته باشد را هشدار می‌دهد.',
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = HomePage(
      showNotificationDetails: widget.showNotificationDetails,
      showSourceApp: widget.showSourceApp,
      onToggleDetails: widget.onToggleDetails,
      onToggleSourceApp: widget.onToggleSourceApp,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: _tab != 0, child: home),
          if (_visitedTabs.contains(1))
            Offstage(offstage: _tab != 1, child: const AppsPage()),
          if (_visitedTabs.contains(2))
            Offstage(offstage: _tab != 2, child: const AlertsPage()),
        ],
      ),
      bottomNavigationBar: _CustomBottomNav(
        selectedIndex: _tab,
        onTap: _onTabTap,
      ),
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({required this.selectedIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_rounded, label: 'خانه'),
    (icon: Icons.apps_rounded, label: 'برنامه‌ها'),
    (icon: Icons.notifications_active_rounded, label: 'کلمات و عناوین'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final shadow = isDark ? Colors.black : Colors.black.withValues(alpha: 0.12);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: shadow, blurRadius: 24, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.all(6),
                    padding: EdgeInsets.symmetric(
                        horizontal: selected ? 14 : 0, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.orange.shade400
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          size: 22,
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
