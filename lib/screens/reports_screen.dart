import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({this.refreshKey = 0, super.key});

  final int refreshKey;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repository = EquipmentRepository();
  Map<String, int> _summary = {};
  List<Map<String, Object?>> _activities = [];
  List<Map<String, Object?>> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
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
      final activities = await _repository.getActivities();
      final categories = await _repository.getCategoryBreakdown();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _activities = activities;
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

  IconData _activityIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_rounded;
      case 'updated':
        return Icons.edit_rounded;
      case 'archived':
        return Icons.archive_rounded;
      case 'issued':
        return Icons.outbox_rounded;
      case 'returned':
        return Icons.assignment_return_rounded;
      case 'reported':
        return Icons.report_problem_rounded;
      case 'resolved':
        return Icons.check_circle_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'created':
      case 'resolved':
        return AppColors.green;
      case 'issued':
        return AppColors.sky;
      case 'returned':
        return AppColors.teal;
      case 'reported':
        return AppColors.coral;
      case 'archived':
        return AppColors.muted;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    final total = _summary['total_units'] ?? 0;
    final available = _summary['available_units'] ?? 0;
    final issued = _summary['issued_units'] ?? 0;
    final healthy = total == 0 ? 100 : (available * 100 / total).round();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : available / total,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          backgroundColor: AppColors.line,
                          valueColor: AlwaysStoppedAnimation(
                            availabilityColor(available, total),
                          ),
                        ),
                      ),
                      Text(
                        '$healthy%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventory availability',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$available of $total units are ready to use. $issued currently on loan.',
                        style: const TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Summary'),
          TwoColumn(
            children: [
              StatTile(label: 'Total units', value: total, icon: Icons.inventory_2_rounded, color: AppColors.primary),
              StatTile(label: 'Available', value: available, icon: Icons.check_circle_rounded, color: AppColors.green),
              StatTile(label: 'Issued', value: issued, icon: Icons.outbox_rounded, color: AppColors.sky),
              StatTile(label: 'Maintenance', value: _summary['maintenance_units'] ?? 0, icon: Icons.build_rounded, color: AppColors.amber),
              StatTile(label: 'Damaged', value: _summary['damaged_units'] ?? 0, icon: Icons.report_problem_rounded, color: AppColors.coral),
              StatTile(label: 'Overdue loans', value: _summary['overdue_loans'] ?? 0, icon: Icons.schedule_rounded, color: AppColors.pink),
            ],
          ),
          if (_categories.isNotEmpty) ...[
            const SectionTitle('Categories'),
            AppCard(
              child: Column(
                children: [
                  for (final row in _categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          IconBox(
                            icon: categoryIcon(row['category'] as String),
                            color: categoryColor(row['category'] as String),
                            size: 38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        row['category'] as String,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      '${row['available']} / ${row['total']}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                AvailabilityBar(
                                  value: (row['available'] as num?)?.toInt() ?? 0,
                                  total: (row['total'] as num?)?.toInt() ?? 0,
                                  color: categoryColor(row['category'] as String),
                                  height: 7,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SectionTitle('Recent activity'),
          if (_activities.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                message: 'Actions you take will be logged here.',
              ),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (final row in _activities)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          IconBox(
                            icon: _activityIcon('${row['action']}'),
                            color: _activityColor('${row['action']}'),
                            size: 38,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['message']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  fmtDateTime(row['created_at'] as String?),
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
