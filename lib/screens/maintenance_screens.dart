import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/equipment.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common.dart';

Future<bool> openMaintenanceForm(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const MaintenanceForm(),
  );
  return saved == true;
}

Future<bool> openDamageForm(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const DamageReportForm(),
  );
  return saved == true;
}

IconData _maintenanceIcon(String type) {
  switch (type) {
    case 'Repair':
      return Icons.build_rounded;
    case 'Inspection':
      return Icons.fact_check_rounded;
    case 'Calibration':
      return Icons.tune_rounded;
    default:
      return Icons.event_repeat_rounded;
  }
}

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({required this.onChanged, super.key});

  final VoidCallback onChanged;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _repository = EquipmentRepository();
  List<Map<String, Object?>> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final records = await _repository.getMaintenance();
      if (!mounted) return;
      setState(() {
        _records = records;
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

  Future<void> _add() async {
    if (await openMaintenanceForm(context)) {
      await _load(silent: true);
      widget.onChanged();
    }
  }

  Future<void> _setStatus(int id, String status) async {
    try {
      await _repository.updateMaintenanceStatus(id, status);
      await _load(silent: true);
      widget.onChanged();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: _records.isEmpty
          ? ListView(
              children: const [
                EmptyState(
                  icon: Icons.build_circle_rounded,
                  color: AppColors.amber,
                  title: 'No maintenance scheduled',
                  message: 'Schedule routine checks, repairs and calibrations here.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final row = _records[index];
                final status = row['status'] as String;
                final type = row['maintenance_type'] as String;
                final id = row['id'] as int;
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBox(icon: _maintenanceIcon(type), color: statusColor(status)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['equipment_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${row['equipment_code']} • $type',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(status),
                        ],
                      ),
                      if (((row['problem_description'] as String?) ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('${row['problem_description']}'),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.event_rounded, size: 16, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            'Scheduled ${fmtDate(row['scheduled_date'] as String?)}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                      if (status == 'Pending' || status == 'In Progress') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _setStatus(id, 'Cancelled'),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AppColors.coral),
                              ),
                            ),
                            const Spacer(),
                            if (status == 'Pending')
                              OutlinedButton(
                                onPressed: () => _setStatus(id, 'In Progress'),
                                child: const Text('Start'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(96, 44),
                                backgroundColor: AppColors.green,
                              ),
                              onPressed: () => _setStatus(id, 'Completed'),
                              child: const Text('Complete'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _body(),
    );
  }
}

class MaintenanceForm extends StatefulWidget {
  const MaintenanceForm({super.key});

  @override
  State<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<MaintenanceForm> {
  final _repository = EquipmentRepository();
  final _description = TextEditingController();
  List<Equipment> _equipment = [];
  Equipment? _selected;
  String _type = 'Routine';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.getAll();
      if (mounted) {
        setState(() {
          _equipment = items;
          _selected = items.isEmpty ? null : items.first;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) {
      showMessage(context, 'Add equipment before scheduling maintenance.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.saveMaintenance(
        equipment: _selected!,
        type: _type,
        description: _description.text,
        scheduledDate: _date,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Schedule maintenance',
      icon: Icons.build_circle_rounded,
      color: AppColors.amber,
      children: [
        if (_equipment.isEmpty)
          const Text('Add equipment first.')
        else
          DropdownButtonFormField<Equipment>(
            value: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: _equipment
                .map((i) => DropdownMenuItem(
                      value: i,
                      child: Text(i.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
        DropdownButtonFormField<String>(
          value: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const ['Routine', 'Repair', 'Inspection', 'Calibration']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _type = v ?? 'Routine'),
        ),
        if (_type == 'Repair')
          const Text(
            'Equipment will be marked "Under Maintenance" and cannot be issued until the repair is completed.',
            style: TextStyle(color: AppColors.amber, fontSize: 12.5),
          ),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Problem / work description'),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (picked != null) setState(() => _date = picked);
          },
          child: Row(
            children: [
              const IconBox(icon: Icons.event_rounded, color: AppColors.amber, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat.yMMMEd().format(_date),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.edit_calendar_rounded, color: AppColors.muted),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving...' : 'Save schedule'),
        ),
      ],
    );
  }
}

class DamageReportsScreen extends StatefulWidget {
  const DamageReportsScreen({required this.onChanged, super.key});

  final VoidCallback onChanged;

  @override
  State<DamageReportsScreen> createState() => _DamageReportsScreenState();
}

class _DamageReportsScreenState extends State<DamageReportsScreen> {
  final _repository = EquipmentRepository();
  List<Map<String, Object?>> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final records = await _repository.getDamageReports();
      if (!mounted) return;
      setState(() {
        _records = records;
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

  Future<void> _add() async {
    if (await openDamageForm(context)) {
      await _load(silent: true);
      widget.onChanged();
    }
  }

  Future<void> _resolve(int id) async {
    try {
      await _repository.resolveDamageReport(id);
      await _load(silent: true);
      widget.onChanged();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: _records.isEmpty
          ? ListView(
              children: const [
                EmptyState(
                  icon: Icons.verified_rounded,
                  color: AppColors.green,
                  title: 'No damage reports',
                  message: 'Everything looks healthy. Reports will appear here.',
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final row = _records[index];
                final severity = '${row['severity']}';
                final status = '${row['status']}';
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBox(
                            icon: Icons.report_problem_rounded,
                            color: statusColor(severity),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['equipment_name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${row['report_id']}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(severity),
                        ],
                      ),
                      if (((row['description'] as String?) ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('${row['description']}'),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          StatusChip(status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fmtDate(row['report_date'] as String?),
                              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                            ),
                          ),
                          if (status != 'Resolved')
                            TextButton.icon(
                              onPressed: () => _resolve(row['id'] as int),
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: const Text('Mark resolved'),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Damage reports')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.coral,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Report damage', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _body(),
    );
  }
}

class DamageReportForm extends StatefulWidget {
  const DamageReportForm({super.key});

  @override
  State<DamageReportForm> createState() => _DamageReportFormState();
}

class _DamageReportFormState extends State<DamageReportForm> {
  final _repository = EquipmentRepository();
  final _description = TextEditingController();
  final _reportedBy = TextEditingController();
  List<Equipment> _equipment = [];
  Equipment? _selected;
  String _severity = 'Minor';
  bool _repairRequired = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repository.getAll();
      if (mounted) {
        setState(() {
          _equipment = rows;
          _selected = rows.isEmpty ? null : rows.first;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _reportedBy.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null || _description.text.trim().isEmpty) {
      showMessage(context, 'Choose equipment and describe the damage.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.createDamageReport(
        equipment: _selected!,
        severity: _severity,
        description: _description.text,
        reportedBy: _reportedBy.text,
        repairRequired: _repairRequired,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Report damage',
      icon: Icons.report_problem_rounded,
      color: AppColors.coral,
      children: [
        if (_equipment.isEmpty)
          const Text('Add equipment first.')
        else
          DropdownButtonFormField<Equipment>(
            value: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: _equipment
                .map((i) => DropdownMenuItem(
                      value: i,
                      child: Text(i.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'Minor', label: Text('Minor')),
            ButtonSegment(value: 'Moderate', label: Text('Moderate')),
            ButtonSegment(value: 'Critical', label: Text('Critical')),
          ],
          selected: {_severity},
          onSelectionChanged: (v) => setState(() => _severity = v.first),
        ),
        TextField(
          controller: _reportedBy,
          decoration: const InputDecoration(
            labelText: 'Reported by',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Damage description'),
        ),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: const Text('Repair required'),
          subtitle: const Text('Blocks issuing and opens a repair ticket.'),
          value: _repairRequired || _severity == 'Critical',
          onChanged: _severity == 'Critical'
              ? null
              : (v) => setState(() => _repairRequired = v),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving...' : 'Save report'),
        ),
      ],
    );
  }
}
