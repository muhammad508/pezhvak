import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pezhvak/core/channels.dart';
import 'package:pezhvak/pages/premium_page.dart';
import 'package:pezhvak/services/rule_options.dart';
import 'package:pezhvak/services/services.dart';
import 'package:pezhvak/widgets/rule_options_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keyword and title rules, with per-rule advanced options for premium users.
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('هشدارها'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.orange.shade700,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'کلمات کلیدی'),
                    Tab(text: 'عناوین'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _AlertEditor(type: _AlertType.keyword),
              _AlertEditor(type: _AlertType.title),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AlertType { keyword, title }

class _AlertEditor extends StatefulWidget {
  final _AlertType type;
  const _AlertEditor({required this.type});

  @override
  State<_AlertEditor> createState() => _AlertEditorState();
}

class _AlertEditorState extends State<_AlertEditor> {
  List<String> _items = [];
  Map<String, RuleOptions> _options = {};
  final _controller = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _searchActive = false;

  bool get _isKeyword => widget.type == _AlertType.keyword;

  String get _filename => _isKeyword ? 'keywords.json' : 'titles.json';
  String get _prefsKey => _isKeyword ? 'keywords' : 'titles';

  Color get _color => _isKeyword ? Colors.green.shade700 : Colors.blue.shade700;
  Color get _bgColor => _isKeyword ? Colors.green.shade50 : Colors.blue.shade50;
  IconData get _icon =>
      _isKeyword ? Icons.text_fields_rounded : Icons.title_rounded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<String> loaded = [];
    try {
      const ch = MethodChannel(AppChannels.files);
      final str = await ch
          .invokeMethod<String>('readJsonList', {'filename': _filename});
      if (str != null && str.isNotEmpty) {
        final d = jsonDecode(str);
        if (d is List) loaded = d.map((e) => e.toString()).toList();
      }
    } catch (_) {
      loaded =
          (await SharedPreferences.getInstance()).getStringList(_prefsKey) ??
              [];
    }
    final options = await RuleOptionsService.load();
    if (mounted) {
      setState(() {
        _items = loaded;
        _options = options;
      });
    }
  }

  RuleOptions? _optionsFor(String item) =>
      _options[RuleOptionsService.key(_isKeyword, item)];

  /// Advanced options of each rule (premium)
  Future<void> _openOptions(String item) async {
    final premium = PremiumService.status.value;
    if (!mounted) return;
    if (!premium) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.star_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('ویژگی پریمیوم', style: TextStyle(fontSize: 17)),
          ]),
          content: const Text(
            'برای هر کلمه یا عنوان می‌توانید اولویت، صدا، لرزش، تکرار تا تأیید، '
            'کلمات منفی و زمان‌بندی جداگانه تعیین کنید.\n\nاین امکانات با اشتراک پریمیوم فعال می‌شود.',
            style: TextStyle(height: 1.8, fontSize: 13),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('بعداً')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('مشاهده اشتراک')),
          ],
        ),
      );
      if (go == true && mounted) {
        await openPremiumPage(context);
      }
      return;
    }
    final changed =
        await showRuleOptionsSheet(context, isKeyword: _isKeyword, text: item);
    if (changed) {
      final options = await RuleOptionsService.load();
      if (mounted) setState(() => _options = options);
    }
  }

  Future<void> _save() async {
    try {
      const ch = MethodChannel(AppChannels.files);
      await ch.invokeMethod(
          'writeJsonList', {'filename': _filename, 'list': _items});
    } catch (_) {
      await (await SharedPreferences.getInstance())
          .setStringList(_prefsKey, _items);
    }
  }

  Future<void> _add() async {
    final v = _controller.text.trim();
    if (v.isEmpty || _items.contains(v)) {
      _controller.clear();
      return;
    }
    setState(() => _items.add(v));
    _controller.clear();
    await _save();
  }

  Future<void> _remove(int i) async {
    final removed = _items[i];
    setState(() => _items.removeAt(i));
    await _save();
    // Also delete this rule's advanced options (and its custom sound file).
    final key = RuleOptionsService.key(_isKeyword, removed);
    final old = _options[key];
    if (old != null) {
      await SoundStorage.delete(old.sound);
      await RuleOptionsService.remove(key);
      if (mounted) setState(() => _options.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBg = isDark ? _color.withValues(alpha: 0.15) : _bgColor;

    final q = _searchQuery.trim().toLowerCase();
    final displayed = q.isEmpty
        ? _items
        : _items.where((s) => s.toLowerCase().contains(q)).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _searchActive
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: GestureDetector(
              onTap: () => setState(() => _searchActive = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: _color.withValues(alpha: 0.6), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'جستجو در ${_isKeyword ? "کلمات کلیدی" : "عناوین"}...',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            secondChild: TextField(
              controller: _searchCtrl,
              autofocus: true,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'جستجو...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _color, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _searchActive = false;
                    _searchQuery = '';
                    _searchCtrl.clear();
                  }),
                ),
                filled: true,
                fillColor: effectiveBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _color.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _color.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _color, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),

        // Description
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: _color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isKeyword
                          ? 'جستجو در متن نوتیفیکیشن'
                          : 'جستجو در عنوان نوتیفیکیشن',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isKeyword
                          ? 'اگر بخشی از این کلمه در ساب‌تایتل نوتیفیکیشن پیدا شد، آلارم فعال می‌شود — صرف نظر از اینکه برنامه در لیست باشد یا نه.'
                          : 'اگر بخشی از این عبارت در تایتل نوتیفیکیشن پیدا شد، آلارم فعال می‌شود — صرف نظر از اینکه برنامه در لیست باشد یا نه.',
                      style: TextStyle(
                          fontSize: 11,
                          color: _color.withValues(alpha: 0.8),
                          height: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⭐ پریمیوم: روی هر مورد بزنید تا اولویت، صدا، لرزش، تکرار، کلمات منفی و زمان‌بندی اختصاصی تعیین کنید.',
                      style: TextStyle(
                          fontSize: 11,
                          color: _color.withValues(alpha: 0.8),
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Add-item input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _isKeyword
                        ? 'مثال: واریز، فوری، پرداخت شد'
                        : 'مثال: بانک ملی، علی رضایی',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Icon(_icon, color: _color, size: 20),
                    filled: true,
                    fillColor: effectiveBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: _color.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: _color.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _color, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('افزودن',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                q.isNotEmpty
                    ? '${displayed.length} نتیجه از ${_items.length} ${_isKeyword ? "کلمه" : "عنوان"}'
                    : '${_items.length} ${_isKeyword ? "کلمه" : "عنوان"} ذخیره شده',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ),
          ),

        Expanded(
          child: displayed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: effectiveBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          q.isNotEmpty ? Icons.search_off_rounded : _icon,
                          size: 40,
                          color: _color.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        q.isNotEmpty
                            ? 'نتیجه‌ای یافت نشد'
                            : 'هنوز ${_isKeyword ? "کلمه‌ای" : "عنوانی"} اضافه نشده',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      if (q.isEmpty)
                        Text(
                          _isKeyword
                              ? 'با افزودن کلمه، آلارم برای آن فعال می‌شود'
                              : 'با افزودن عنوان، آلارم برای تایتل‌های مشابه فعال می‌شود',
                          style:
                              TextStyle(color: Colors.grey[350], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: displayed
                        .map((item) => _AlertChip(
                              text: item,
                              color: _color,
                              bgColor: effectiveBg,
                              options: _optionsFor(item),
                              onTap: () => _openOptions(item),
                              onDelete: () => _remove(_items.indexOf(item)),
                            ))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;
  final RuleOptions? options;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AlertChip({
    required this.text,
    required this.color,
    required this.bgColor,
    required this.options,
    required this.onTap,
    required this.onDelete,
  });

  /// Small badges showing which advanced options are set
  List<Widget> _badges() {
    final o = options;
    if (o == null) return const [];
    Widget b(IconData icon, Color c) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(icon, size: 14, color: c),
        );
    return [
      if (o.priority == 'urgent') b(Icons.bolt_rounded, Colors.red),
      if (o.priority == 'silent')
        b(Icons.notifications_off_rounded, Colors.grey),
      if (o.sound.isNotEmpty)
        b(Icons.audiotrack_rounded, Colors.amber.shade700),
      if (o.vibration != 'off') b(Icons.vibration_rounded, Colors.purple),
      if (o.repeat) b(Icons.repeat_rounded, Colors.teal),
      if (o.excludes.isNotEmpty) b(Icons.block_rounded, Colors.deepOrange),
      if (o.scheduleEnabled || o.ignoreGlobalSchedule)
        b(Icons.schedule_rounded, Colors.blue),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      shape:
          StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.35))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 6),
              ..._badges(),
              Icon(Icons.tune_rounded,
                  size: 14, color: color.withValues(alpha: 0.55)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 14, color: color.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
