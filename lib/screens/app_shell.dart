import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/equipment.dart';
import '../models/user.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common.dart';
import '../core/utils.dart';
import 'equipment_screens.dart';
import 'login_screen.dart';
import 'maintenance_screens.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transactions_screens.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.user, super.key});

  final User user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _titles = ['Dashboard', 'Equipment', 'Transactions', 'Reports'];
  int _selectedIndex = 0;

  /// Bumped whenever data changes so every tab reloads (tabs stay alive in an
  /// IndexedStack, so they would otherwise show stale numbers).
  int _version = 0;

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  void _refresh() {
    if (!mounted) return;
    setState(() => _version++);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your PIN to sign back in.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openMore(String value) async {
    switch (value) {
      case 'maintenance':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MaintenanceScreen(onChanged: _refresh)),
        );
      case 'damage':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DamageReportsScreen(onChanged: _refresh)),
        );
      case 'settings':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user)),
        );
      case 'logout':
        await _logout();
        return;
    }
    _refresh();
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label,
      {Color color = AppColors.ink}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onSelected: _openMore,
            itemBuilder: (_) => [
              _menuItem('maintenance', Icons.build_circle_outlined, 'Maintenance'),
              _menuItem('damage', Icons.report_gmailerrorred_rounded, 'Damage reports'),
              _menuItem('settings', Icons.settings_outlined, 'Settings'),
              const PopupMenuDivider(),
              _menuItem('logout', Icons.logout_rounded, 'Sign out',
                  color: AppColors.coral),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardPage(
            user: widget.user,
            refreshKey: _version,
            onChanged: _refresh,
            onOpenTab: _selectPage,
            onOpenMaintenance: () => _openMore('maintenance'),
            onOpenDamage: () => _openMore('damage'),
          ),
          EquipmentListScreen(refreshKey: _version, onChanged: _refresh),
          TransactionsScreen(refreshKey: _version, onChanged: _refresh),
          ReportsScreen(refreshKey: _version),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Equipment',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            selectedIcon: Icon(Icons.swap_horizontal_circle_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    required this.user,
    required this.refreshKey,
    required this.onChanged,
    required this.onOpenTab,
    required this.onOpenMaintenance,
    required this.onOpenDamage,
  });

  final User user;
  final int refreshKey;
  final VoidCallback onChanged;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenMaintenance;
  final VoidCallback onOpenDamage;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  final _repository = EquipmentRepository();
  Map<String, int> _summary = {};
  List<Equipment> _equipment = [];
  List<Map<String, Object?>> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await _repository.getDashboardSummary();
      final equipment = await _repository.getAll();
      final categories = await _repository.getCategoryBreakdown();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _equipment = equipment;
        _categories = categories;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (await action()) {
      await _load(silent: true);
      widget.onChanged();
    }
  }

  int _n(String key) => _summary[key] ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final total = _n('total_units');
    final available = _n('available_units');
    final overdue = _n('overdue_loans');
    final firstName = widget.user.name.split(' ').first;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMMEEEEd().format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'of $total units available',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : available / total,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                if (overdue > 0) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => widget.onOpenTab(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$overdue overdue ${overdue == 1 ? 'loan needs' : 'loans need'} attention',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TwoColumn(
            children: [
              StatTile(label: 'Total units', value: total, icon: Icons.inventory_2_rounded, color: AppColors.primary),
              StatTile(label: 'Available', value: available, icon: Icons.check_circle_rounded, color: AppColors.green),
              StatTile(label: 'Issued', value: _n('issued_units'), icon: Icons.outbox_rounded, color: AppColors.sky),
              StatTile(label: 'Maintenance', value: _n('maintenance_units'), icon: Icons.build_rounded, color: AppColors.amber),
              StatTile(label: 'Damaged', value: _n('damaged_units'), icon: Icons.report_problem_rounded, color: AppColors.coral),
              StatTile(label: 'Overdue loans', value: overdue, icon: Icons.schedule_rounded, color: AppColors.pink),
            ],
          ),
          const SectionTitle('Quick actions'),
          Row(
            children: [
              _QuickAction(
                icon: Icons.add_box_rounded,
                label: 'Add\nequipment',
                color: AppColors.primary,
                onTap: () => _run(() => openEquipmentForm(context)),
              ),
              const SizedBox(width: 10),
              _QuickAction(
                icon: Icons.outbox_rounded,
                label: 'Issue\nitem',
                color: AppColors.sky,
                onTap: () => _run(() => openIssueForm(context)),
              ),
              const SizedBox(width: 10),
              _QuickAction(
                icon: Icons.build_circle_rounded,
                label: 'Maintenance',
                color: AppColors.amber,
                onTap: widget.onOpenMaintenance,
              ),
              const SizedBox(width: 10),
              _QuickAction(
                icon: Icons.report_rounded,
                label: 'Report\ndamage',
                color: AppColors.coral,
                onTap: widget.onOpenDamage,
              ),
            ],
          ),
          if (_categories.isNotEmpty) ...[
            const SectionTitle('By category'),
            AppCard(
              child: Column(
                children: [
                  for (final row in _categories)
                    _CategoryRow(
                      name: row['category'] as String,
                      available: (row['available'] as num?)?.toInt() ?? 0,
                      total: (row['total'] as num?)?.toInt() ?? 0,
                    ),
                ],
              ),
            ),
          ],
          SectionTitle(
            'Equipment',
            trailing: TextButton(
              onPressed: () => widget.onOpenTab(1),
              child: const Text('View all'),
            ),
          ),
          if (_equipment.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.inventory_2_rounded,
                title: 'No equipment yet',
                message: 'Add your first item to start tracking your lab.',
              ),
            )
          else
            for (final item in _equipment.take(5))
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => widget.onOpenTab(1),
                child: Row(
                  children: [
                    IconBox(
                      icon: categoryIcon(item.category),
                      color: categoryColor(item.category),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${item.equipmentCode} • ${item.room}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          AvailabilityBar(
                            value: item.availableQuantity,
                            total: item.totalQuantity,
                            height: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${item.availableQuantity}/${item.totalQuantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: availabilityColor(item.availableQuantity, item.totalQuantity),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              AppConstants.appName,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          children: [
            IconBox(icon: icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.available,
    required this.total,
  });

  final String name;
  final int available;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconBox(icon: categoryIcon(name), color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '$available / $total',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AvailabilityBar(value: available, total: total, color: color, height: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
