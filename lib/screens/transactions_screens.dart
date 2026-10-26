import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/equipment.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common.dart';

Future<bool> openIssueForm(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const IssueForm(),
  );
  return saved == true;
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    required this.onChanged,
    this.refreshKey = 0,
    super.key,
  });

  final VoidCallback onChanged;
  final int refreshKey;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repository = EquipmentRepository();
  List<Map<String, Object?>> _records = [];
  bool _activeOnly = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
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
      final result = await _repository.getTransactions(activeOnly: _activeOnly);
      if (!mounted) return;
      setState(() {
        _records = result;
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

  Future<void> _issue() async {
    if (await openIssueForm(context)) {
      await _load(silent: true);
      widget.onChanged();
    }
  }

  Future<void> _return(Map<String, Object?> row) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReturnSheet(row: row),
    );
    if (result == true) {
      await _load(silent: true);
      widget.onChanged();
      if (mounted) showMessage(context, 'Return saved.');
    }
  }

  Future<void> _showHistory(Map<String, Object?> row) async {
    try {
      final history = await _repository.getReturnHistory(row['id'] as int);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (context) => FormSheet(
          title: 'Return history',
          icon: Icons.history_rounded,
          color: AppColors.teal,
          children: [
            Text(
              '${row['transaction_code']}',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (history.isEmpty)
              const Text('No units have been returned yet.')
            else
              for (final e in history)
                AppCard(
                  child: Row(
                    children: [
                      IconBox(
                        icon: Icons.assignment_return_rounded,
                        color: statusColor('${e['condition_on_return']}'),
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e['quantity_returned']} unit(s) • ${e['condition_on_return']}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              fmtDateTime(e['return_date'] as String?),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                            if (((e['notes'] as String?) ?? '').isNotEmpty)
                              Text('${e['notes']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _records.where((r) => (r['is_overdue'] as int? ?? 0) == 1).length;
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Active loans')),
                    ButtonSegment(value: false, label: Text('All history')),
                  ],
                  selected: {_activeOnly},
                  onSelectionChanged: (value) {
                    setState(() => _activeOnly = value.first);
                    _load();
                  },
                ),
              ),
            ),
            if (overdueCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppColors.coral),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$overdueCount overdue ${overdueCount == 1 ? 'loan' : 'loans'}. Please follow up.',
                          style: const TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _records.isEmpty
                          ? ListView(
                              children: [
                                EmptyState(
                                  icon: Icons.swap_horiz_rounded,
                                  color: AppColors.sky,
                                  title: _activeOnly
                                      ? 'Nothing is on loan'
                                      : 'No transactions yet',
                                  message: 'Issue equipment to a student or teacher to see it here.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                              itemCount: _records.length,
                              itemBuilder: (context, index) => _TransactionCard(
                                row: _records[index],
                                onReturn: () => _return(_records[index]),
                                onHistory: () => _showHistory(_records[index]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _issue,
            icon: const Icon(Icons.outbox_rounded),
            label: const Text(
              'Issue equipment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.row,
    required this.onReturn,
    required this.onHistory,
  });

  final Map<String, Object?> row;
  final VoidCallback onReturn;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final outstanding = row['quantity_outstanding'] as int;
    final issued = row['quantity_issued'] as int;
    final returned = row['quantity_returned'] as int;
    final overdue = (row['is_overdue'] as int? ?? 0) == 1;
    final status = overdue ? 'Overdue' : '${row['status']}';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: Icons.swap_horiz_rounded,
                color: statusColor(status),
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
                      '${row['transaction_code']}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${row['borrower_name']} • ${row['borrower_id']} • ${row['borrower_type']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 16,
                color: overdue ? AppColors.coral : AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                'Due ${fmtDate(row['expected_return_date'] as String?)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: overdue ? FontWeight.w800 : FontWeight.w500,
                  color: overdue ? AppColors.coral : AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AvailabilityBar(value: returned, total: issued, color: AppColors.teal),
          const SizedBox(height: 4),
          Text(
            'Returned $returned of $issued',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('History'),
              ),
              const Spacer(),
              if (outstanding > 0)
                FilledButton.tonalIcon(
                  onPressed: onReturn,
                  icon: const Icon(Icons.assignment_return_rounded, size: 18),
                  label: const Text('Return'),
                  style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReturnSheet extends StatefulWidget {
  const ReturnSheet({required this.row, super.key});

  final Map<String, Object?> row;

  @override
  State<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<ReturnSheet> {
  final _formKey = GlobalKey<FormState>();
  final _repository = EquipmentRepository();
  late final TextEditingController _quantity;
  final _notes = TextEditingController();
  String _condition = 'Good';
  bool _saving = false;

  int get _outstanding => widget.row['quantity_outstanding'] as int;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: '$_outstanding');
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repository.returnEquipment(
        issueId: widget.row['id'] as int,
        quantity: int.parse(_quantity.text.trim()),
        condition: _condition,
        notes: _notes.text,
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
    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'Record return',
        icon: Icons.assignment_return_rounded,
        color: AppColors.teal,
        children: [
          Text(
            '${widget.row['equipment_name']} • $_outstanding unit(s) outstanding',
            style: const TextStyle(color: AppColors.muted),
          ),
          appField(
            _quantity,
            'Quantity returned',
            required: true,
            numeric: true,
            integer: true,
            min: 1,
            icon: Icons.numbers_rounded,
            extra: (t) => int.parse(t) > _outstanding
                ? 'Only $_outstanding unit(s) are outstanding.'
                : null,
          ),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'Good', label: Text('Good')),
              ButtonSegment(value: 'Fair', label: Text('Fair')),
              ButtonSegment(value: 'Damaged', label: Text('Damaged')),
            ],
            selected: {_condition},
            onSelectionChanged: (v) => setState(() => _condition = v.first),
          ),
          if (_condition == 'Damaged')
            Text(
              'A damage report and repair ticket will be created automatically.',
              style: TextStyle(color: AppColors.coral.withValues(alpha: 0.9), fontSize: 12.5),
            ),
          appField(_notes, 'Notes (optional)', maxLines: 2),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving...' : 'Save return'),
          ),
        ],
      ),
    );
  }
}

class IssueForm extends StatefulWidget {
  const IssueForm({super.key});

  @override
  State<IssueForm> createState() => _IssueFormState();
}

class _IssueFormState extends State<IssueForm> {
  final _formKey = GlobalKey<FormState>();
  final _repository = EquipmentRepository();
  final _name = TextEditingController();
  final _borrowerId = TextEditingController();
  final _purpose = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  List<Equipment> _equipment = [];
  Equipment? _selected;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String _borrowerType = 'Student';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      final items = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _equipment = items
            .where((i) =>
                i.availableQuantity > 0 &&
                i.conditionStatus != 'Damaged' &&
                i.status != 'Under Maintenance')
            .toList();
        _selected = _equipment.isEmpty ? null : _equipment.first;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showError(context, error);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _borrowerId.dispose();
    _purpose.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final equipment = _selected;
    if (equipment == null) {
      showMessage(context, 'There is no available equipment to issue.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.issueEquipment(
        equipment: equipment,
        borrowerName: _name.text,
        borrowerId: _borrowerId.text,
        borrowerType: _borrowerType,
        quantity: int.parse(_quantity.text.trim()),
        expectedReturn: _dueDate,
        purpose: _purpose.text,
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
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_equipment.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: EmptyState(
          icon: Icons.inventory_2_rounded,
          color: AppColors.amber,
          title: 'Nothing to issue',
          message: 'All equipment is either on loan, damaged, or under maintenance.',
        ),
      );
    }
    return Form(
      key: _formKey,
      child: FormSheet(
        title: 'Issue equipment',
        icon: Icons.outbox_rounded,
        color: AppColors.sky,
        children: [
          DropdownButtonFormField<Equipment>(
            value: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: _equipment
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.name} (${item.availableQuantity} available)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
          appField(_name, 'Borrower name', required: true, icon: Icons.person_outline_rounded),
          appField(_borrowerId, 'Borrower ID', required: true, icon: Icons.badge_outlined),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'Student', label: Text('Student')),
              ButtonSegment(value: 'Teacher', label: Text('Teacher')),
              ButtonSegment(value: 'Staff', label: Text('Staff')),
            ],
            selected: {_borrowerType},
            onSelectionChanged: (v) => setState(() => _borrowerType = v.first),
          ),
          appField(
            _quantity,
            'Quantity',
            required: true,
            numeric: true,
            integer: true,
            min: 1,
            icon: Icons.numbers_rounded,
            extra: (t) {
              final available = _selected?.availableQuantity ?? 0;
              return int.parse(t) > available
                  ? 'Only $available available.'
                  : null;
            },
          ),
          appField(_purpose, 'Purpose / lab session', icon: Icons.assignment_outlined),
          AppCard(
            onTap: _pickDueDate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const IconBox(icon: Icons.event_rounded, color: AppColors.primary, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expected return',
                        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      Text(
                        DateFormat.yMMMEd().format(_dueDate),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_rounded, color: AppColors.muted),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving...' : 'Confirm issue'),
          ),
        ],
      ),
    );
  }
}
