import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:pezhvak/core/app_globals.dart';
import 'package:pezhvak/services/services.dart';

/// Lets the user pick which installed apps are monitored.
class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await InstalledApps.getInstalledApps(true, true);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _sortSelectedFirst();
      _filtered = List.of(_apps);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text('برنامه‌های مانیتور')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'جستجو در برنامه‌ها...',
                        hintStyle: const TextStyle(color: Colors.orange),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.orange),
                        filled: true,
                        fillColor: Colors.orange.withValues(alpha: 0.09),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setState(_resort),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${selectedApps.length} برنامه انتخابی از ${_apps.length} برنامه',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: width > 600 ? _buildGrid() : _buildList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) =>
          _AppTile(app: _filtered[i], onChanged: _onToggle),
    );
  }

  Widget _buildGrid() {
    final width = MediaQuery.of(context).size.width;
    final cols = width > 900 ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 3.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) =>
          _AppTile(app: _filtered[i], onChanged: _onToggle),
    );
  }

  void _sortSelectedFirst() {
    _apps.sort((a, b) {
      final aSelected = selectedApps.contains(a.packageName) ? 0 : 1;
      final bSelected = selectedApps.contains(b.packageName) ? 0 : 1;
      return aSelected.compareTo(bSelected);
    });
  }

  void _resort() {
    _sortSelectedFirst();
    final q = _searchCtrl.text.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_apps)
        : _apps.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  void _onToggle(AppInfo app, bool selected) {
    setState(() {
      if (selected) {
        selectedApps.add(app.packageName);
      } else {
        selectedApps.remove(app.packageName);
      }
      _resort();
    });
    AppService.updateSelectedApps(selectedApps);
  }
}

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final void Function(AppInfo, bool) onChanged;
  const _AppTile({required this.app, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = selectedApps.contains(app.packageName);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        secondary: app.icon != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(app.icon!,
                    width: 38, height: 38, fit: BoxFit.cover),
              )
            : const Icon(Icons.apps, color: Colors.orange, size: 38),
        title: Text(
          app.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        value: selected,
        onChanged: (v) => onChanged(app, v ?? false),
      ),
    );
  }
}
