import 'package:flutter/material.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/services/tutorial_service.dart';
import 'package:pezhvak/utils/history_tools.dart';
import 'package:pezhvak/widgets/history_widgets.dart';

/// History of fired alarms (premium).
class AlarmHistoryPage extends StatefulWidget {
  const AlarmHistoryPage({super.key});

  @override
  State<AlarmHistoryPage> createState() => _AlarmHistoryPageState();
}

class _AlarmHistoryPageState extends State<AlarmHistoryPage> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool get _isPremium => PremiumService.status.value;
  bool _searchActive = false;
  DateTimeRange? _range;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    PremiumService.status.addListener(_onPremiumChanged);
    if (_isPremium) {
      _load();
      TutorialService.showIfNew(
        context,
        key: 'alarm_history',
        icon: Icons.alarm,
        title: 'تاریخچه آلارم‌ها',
        color: Colors.red,
        steps: [
          'اینجا لیست تمام آلارم‌هایی که پژواک فعال کرده نمایش داده می‌شود.',
          'روی هر آلارم بزنید تا متن کامل را بخوانید.',
          'از آیکون جستجو بالا می‌توانید در عنوان و متن جستجو کنید.',
          'برای پاک کردن تاریخچه از آیکون سطل آشغال استفاده کنید.',
        ],
      );
    }
  }

  @override
  void dispose() {
    PremiumService.status.removeListener(_onPremiumChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    if (_isPremium) {
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await AlarmHistoryService.getHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _applySearch(_searchCtrl.text);
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final r = await pickHistoryRange(context, _range);
    if (r != null && mounted) {
      setState(() {
        _range = r;
        _applySearch(_searchCtrl.text);
      });
    }
  }

  void _applySearch(String q) {
    final query = q.trim().toLowerCase();
    final source = _range == null
        ? _history
        : _history.where((e) => inRange(e, _range)).toList();
    if (query.isEmpty) {
      _filtered = List.from(source);
    } else {
      _filtered = source.where((item) => matchesQuery(item, query)).toList();
    }
  }

  void _showDetail(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFFEBEE),
            child: Icon(Icons.alarm, color: Colors.red, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item['app_name'] ?? '',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((item['title'] ?? '').isNotEmpty) ...[
                Text(item['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
              ],
              if ((item['text'] ?? '').isNotEmpty)
                Text(item['text'] ?? '',
                    style: TextStyle(
                        color: Colors.grey[700], fontSize: 13, height: 1.6)),
              const SizedBox(height: 12),
              if (matchedRuleLabel(item) != null) ...[
                RuleBadge(label: matchedRuleLabel(item)!),
                const SizedBox(height: 6),
              ],
              Text(formatTimestamp(item['timestamp']),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('بستن')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                onChanged: (q) => setState(() => _applySearch(q)),
              )
            : const Text('تاریخچه آلارم‌ها'),
        actions: [
          if (_isPremium) ...[
            IconButton(
              icon: Icon(Icons.date_range_rounded,
                  color: _range != null ? Colors.black : null),
              tooltip: 'فیلتر تاریخ',
              onPressed: _pickRange,
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'خروجی CSV',
              onPressed: () =>
                  exportHistoryCsv(context, _filtered, 'pezhvak_alarms'),
            ),
            IconButton(
              icon: Icon(_searchActive ? Icons.close : Icons.search),
              tooltip: _searchActive ? 'بستن جستجو' : 'جستجو',
              onPressed: () {
                setState(() {
                  _searchActive = !_searchActive;
                  if (!_searchActive) {
                    _searchCtrl.clear();
                    _applySearch('');
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
                    title: const Text('پاک کردن تاریخچه آلارم'),
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
                  await AlarmHistoryService.clearHistory();
                  _load();
                }
              },
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isPremium ? _buildContent() : _buildPremiumGate(),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.lock_rounded, size: 40, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text('ویژگی پریمیوم',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'تاریخچه کامل آلارم‌ها فقط برای کاربران پریمیوم در دسترس است.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.6),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => openPremiumPage(context),
              icon: const Icon(Icons.star_rounded),
              label: const Text('ارتقا به پریمیوم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
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

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (_range != null)
          RangeChipBar(
            range: _range!,
            onClear: () => setState(() {
              _range = null;
              _applySearch(_searchCtrl.text);
            }),
          ),
        if (_searchCtrl.text.isNotEmpty || _searchActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_filtered.length} نتیجه از ${_history.length} آلارم',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _searchCtrl.text.isNotEmpty
                          ? Icons.search_off
                          : Icons.alarm_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchCtrl.text.isNotEmpty
                          ? 'نتیجه‌ای یافت نشد'
                          : 'هنوز هیچ آلارمی ثبت نشده',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => AlarmCard(
                    item: _filtered[i],
                    query: _searchCtrl.text.trim(),
                    onTap: () => _showDetail(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
