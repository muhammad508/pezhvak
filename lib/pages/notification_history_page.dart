import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/services/tutorial_service.dart';
import 'package:pezhvak/utils/history_tools.dart';
import 'package:pezhvak/widgets/history_widgets.dart';

/// History of every notification the listener saw (10 free, 10,000 premium).
class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filtered = [];
  String? _selectedApp;
  List<String> _apps = [];
  bool _loading = true;
  bool get _isPremium => PremiumService.status.value;
  bool _searchActive = false;
  DateTimeRange? _range;
  final _searchCtrl = TextEditingController();

  static const int _freeLimit = HistoryLimits.free;
  static const int _premiumLimit = HistoryLimits.premium;

  @override
  void initState() {
    super.initState();
    PremiumService.status.addListener(_onPremiumChanged);
    _load();
    TutorialService.showIfNew(
      context,
      key: 'notif_history',
      icon: Icons.history,
      title: 'تاریخچه نوتیفیکیشن‌ها',
      color: Colors.indigo,
      steps: [
        'تمام نوتیفیکیشن‌هایی که پژواک دریافت کرده اینجا ثبت می‌شوند.',
        'روی هر نوتیفیکیشن بزنید تا متن کامل آن را بخوانید.',
        'از آیکون جستجو در عنوان و متن نوتیفیکیشن‌ها جستجو کنید.',
        'فیلتر بر اساس اپ (پریمیوم) و جستجو می‌توانند همزمان استفاده شوند.',
        'نسخه رایگان ۱۰ مورد | نسخه پریمیوم ۱۰ هزار مورد نگه می‌دارد.',
      ],
    );
  }

  @override
  void dispose() {
    PremiumService.status.removeListener(_onPremiumChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// A new subscription changes the record limit, so the list is reloaded.
  void _onPremiumChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final limit = _isPremium ? _premiumLimit : _freeLimit;
    final limited = await NotificationHistoryService.getHistory(limit: limit);
    if (!mounted) return;
    final apps = limited
        .map((e) => e['app_name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    setState(() {
      _allHistory = limited;
      _apps = apps;
      if (!_isPremium) _selectedApp = null;
      _applyFilter();
      _loading = false;
    });
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    List<Map<String, dynamic>> base = _selectedApp == null
        ? List.from(_allHistory)
        : _allHistory.where((e) => e['app_name'] == _selectedApp).toList();
    if (_range != null) base = base.where((e) => inRange(e, _range)).toList();

    if (query.isEmpty) {
      _filtered = base;
    } else {
      _filtered = base.where((item) => matchesQuery(item, query)).toList();
    }
  }

  // Date-range filter and CSV export: premium feature
  Future<void> _pickRange() async {
    if (!_isPremium) return openPremiumPage(context);
    final r = await pickHistoryRange(context, _range);
    if (r != null && mounted) {
      setState(() {
        _range = r;
        _applyFilter();
      });
    }
  }

  Future<void> _export() async {
    if (!_isPremium) return openPremiumPage(context);
    await exportHistoryCsv(context, _filtered, 'pezhvak_notifications');
  }

  void _showDetail(Map<String, dynamic> item) {
    final triggered = item['triggered_alarm'] == true;
    final query = _searchCtrl.text.trim();
    final appName = item['app_name']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final text = item['text']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: triggered
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        triggered
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_rounded,
                        color: triggered ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(formatTimestamp(item['timestamp']),
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                        ],
                      ),
                    ),
                    if (triggered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.alarm_rounded,
                                color: Colors.red, size: 13),
                            SizedBox(width: 4),
                            Text('آلارم داشت',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),

              // Content (scrollable)
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    if (_isPremium && matchedRuleLabel(item) != null) ...[
                      RuleBadge(label: matchedRuleLabel(item)!),
                      const SizedBox(height: 10),
                    ],
                    if (title.isNotEmpty) ...[
                      HighlightText(
                        text: title,
                        query: query,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.5),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (text.isNotEmpty)
                      HighlightText(
                        text: text,
                        query: query,
                        style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.75),
                      ),
                  ],
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.12))),
                ),
                child: Column(
                  children: [
                    // Copy text
                    ActionButton(
                      icon: Icons.copy_rounded,
                      label: 'کپی متن',
                      color: Colors.indigo,
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: [title, text]
                                .where((s) => s.isNotEmpty)
                                .join('\n')));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('متن کپی شد'),
                            backgroundColor: Colors.indigo,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Filter by title
                        Expanded(
                          child: ActionButton(
                            icon: Icons.title_rounded,
                            label: 'نوتیف‌های مشابه\n(عنوان)',
                            color: Colors.teal,
                            onTap: title.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _searchActive = true;
                                      _searchCtrl.text = title;
                                      _applyFilter();
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Filter by app
                        Expanded(
                          child: ActionButton(
                            icon: Icons.apps_rounded,
                            label: 'نوتیف‌های این\nبرنامه',
                            color: Colors.orange,
                            onTap: appName.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    if (_isPremium && _apps.contains(appName)) {
                                      setState(() {
                                        _selectedApp = appName;
                                        _applyFilter();
                                      });
                                    } else {
                                      setState(() {
                                        _searchActive = true;
                                        _searchCtrl.text = appName;
                                        _applyFilter();
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Close
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('بستن'),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 900 ? width * 0.08 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'جستجو در عنوان و متن...',
                  border: InputBorder.none,
                ),
                onChanged: (q) => setState(_applyFilter),
              )
            : const Text('تاریخچه نوتیفیکیشن‌ها'),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range_rounded,
                color: _range != null ? Colors.black : null),
            tooltip: 'فیلتر تاریخ (پریمیوم)',
            onPressed: _pickRange,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'خروجی CSV (پریمیوم)',
            onPressed: _export,
          ),
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            tooltip: _searchActive ? 'بستن جستجو' : 'جستجو',
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchCtrl.clear();
                  _applyFilter();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'پاک کردن تاریخچه',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('پاک کردن تاریخچه'),
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
                await NotificationHistoryService.clearHistory();
                _load();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  children: [
                    // Premium banner
                    if (!_isPremium)
                      GestureDetector(
                        onTap: () => openPremiumPage(context),
                        child: Container(
                          color: Colors.orange.shade50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'نسخه رایگان: ${_allHistory.length} از $_freeLimit — برای ۱۰ هزار مورد ارتقا دهید',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.orange),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Colors.orange),
                            ],
                          ),
                        ),
                      ),
                    if (_range != null)
                      RangeChipBar(
                        range: _range!,
                        onClear: () => setState(() {
                          _range = null;
                          _applyFilter();
                        }),
                      ),
                    // App filter (premium) and result count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: _isPremium
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.filter_list,
                                      color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<String?>(
                                      value: _selectedApp,
                                      isExpanded: true,
                                      underline: const SizedBox.shrink(),
                                      hint: const Text('همه برنامه‌ها'),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('همه برنامه‌ها')),
                                        ..._apps.map(
                                            (app) => DropdownMenuItem<String?>(
                                                  value: app,
                                                  child: Text(app,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                )),
                                      ],
                                      onChanged: (val) => setState(() {
                                        _selectedApp = val;
                                        _applyFilter();
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GestureDetector(
                              onTap: () => openPremiumPage(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.grey.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        color: Colors.grey[400], size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'فیلتر بر اساس اپ — ویژگی پریمیوم',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 13),
                                      ),
                                    ),
                                    Icon(Icons.star,
                                        color: Colors.amber[600], size: 16),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _searchCtrl.text.isNotEmpty
                              ? '${_filtered.length} نتیجه از ${_allHistory.length} نوتیفیکیشن'
                              : '${_filtered.length} نوتیفیکیشن',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Icon(
                                    _searchCtrl.text.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.notifications_none,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchCtrl.text.isNotEmpty
                                        ? 'نتیجه‌ای یافت نشد'
                                        : 'تاریخچه‌ای وجود ندارد',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ]))
                          : LayoutBuilder(
                              builder: (ctx, constraints) {
                                final cols = constraints.maxWidth > 900
                                    ? 3
                                    : constraints.maxWidth > 600
                                        ? 2
                                        : 1;
                                if (cols == 1) {
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    itemCount: _filtered.length,
                                    itemBuilder: (_, i) => NotificationCard(
                                      item: _filtered[i],
                                      showRule: _isPremium,
                                      query: _searchCtrl.text.trim(),
                                      onTap: () => _showDetail(_filtered[i]),
                                    ),
                                  );
                                }
                                return GridView.builder(
                                  padding: const EdgeInsets.all(12),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    childAspectRatio: 2.3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (_, i) => NotificationCard(
                                    item: _filtered[i],
                                    showRule: _isPremium,
                                    query: _searchCtrl.text.trim(),
                                    onTap: () => _showDetail(_filtered[i]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
