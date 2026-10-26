import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/equipment.dart';
import '../repositories/equipment_repository.dart';
import '../widgets/common.dart';

Future<bool> openEquipmentForm(
  BuildContext context, {
  Equipment? equipment,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EquipmentForm(equipment: equipment),
  );
  return saved == true;
}

class EquipmentListScreen extends StatefulWidget {
  const EquipmentListScreen({
    required this.onChanged,
    this.refreshKey = 0,
    super.key,
  });

  final VoidCallback onChanged;
  final int refreshKey;

  @override
  State<EquipmentListScreen> createState() => _EquipmentListScreenState();
}

class _EquipmentListScreenState extends State<EquipmentListScreen> {
  static const _filters = ['All', 'Good', 'Fair', 'Damaged'];
  final _repository = EquipmentRepository();
  final _searchController = TextEditingController();
  List<Equipment> _equipment = [];
  String _condition = 'All';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant EquipmentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load(silent: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _repository.getAll();
      if (!mounted) return;
      setState(() {
        _equipment = rows;
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

  Future<void> _edit({Equipment? equipment}) async {
    if (await openEquipmentForm(context, equipment: equipment)) {
      await _load(silent: true);
      widget.onChanged();
    }
  }

  Future<void> _archive(Equipment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive equipment?'),
        content: Text('Archive ${item.name}? Existing history will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || item.id == null) return;
    try {
      await _repository.archive(item.id!);
      await _load(silent: true);
      widget.onChanged();
      if (mounted) showMessage(context, '${item.name} archived.');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final search = _searchController.text.trim().toLowerCase();
    final filtered = _equipment.where((item) {
      final matchesText =
          search.isEmpty ||
          item.name.toLowerCase().contains(search) ||
          item.equipmentCode.toLowerCase().contains(search) ||
          item.category.toLowerCase().contains(search) ||
          item.room.toLowerCase().contains(search);
      final matchesCondition =
          _condition == 'All' || item.conditionStatus == _condition;
      return matchesText && matchesCondition;
    }).toList();

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search name, code, category, room',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _searchController.clear,
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == 'All' ? 'All conditions' : f),
                        selected: _condition == f,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _condition == f ? Colors.white : AppColors.ink,
                        ),
                        onSelected: (_) => setState(() => _condition = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: filtered.isEmpty
                    ? ListView(
                        children: [
                          EmptyState(
                            icon: Icons.inventory_2_rounded,
                            title: search.isEmpty && _condition == 'All'
                                ? 'No equipment yet'
                                : 'No matches',
                            message: search.isEmpty && _condition == 'All'
                                ? 'Tap "Add equipment" to register your first item.'
                                : 'Try a different search or filter.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _EquipmentCard(
                          item: filtered[index],
                          onEdit: () => _edit(equipment: filtered[index]),
                          onArchive: () => _archive(filtered[index]),
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
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add equipment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.item,
    required this.onEdit,
    required this.onArchive,
  });

  final Equipment item;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBox(
                icon: categoryIcon(item.category),
                color: categoryColor(item.category),
                size: 50,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.equipmentCode} • ${item.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onArchive();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              Text(
                '${item.availableQuantity} of ${item.totalQuantity} available',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: availabilityColor(
                    item.availableQuantity,
                    item.totalQuantity,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AvailabilityBar(
            value: item.availableQuantity,
            total: item.totalQuantity,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(item.status),
              StatusChip(item.conditionStatus),
              if (item.calibrationRequired)
                const StatusChip('Calibration', color: AppColors.violet),
            ],
          ),
        ],
      ),
    );
  }
}

class EquipmentForm extends StatefulWidget {
  const EquipmentForm({this.equipment, super.key});

  final Equipment? equipment;

  @override
  State<EquipmentForm> createState() => _EquipmentFormState();
}

class _EquipmentFormState extends State<EquipmentForm> {
  static const _suggestions = [
    'Measurement',
    'Power',
    'Electronics',
    'Optics',
    'Chemistry',
    'Tools',
  ];
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _room;
  late final TextEditingController _quantity;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  String _condition = 'Good';
  bool _calibration = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.equipment;
    _code = TextEditingController(text: item?.equipmentCode ?? '');
    _name = TextEditingController(text: item?.name ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _room = TextEditingController(text: item?.room ?? '');
    _quantity = TextEditingController(
      text: item?.totalQuantity.toString() ?? '1',
    );
    _brand = TextEditingController(text: item?.brand ?? '');
    _model = TextEditingController(text: item?.model ?? '');
    _serial = TextEditingController(text: item?.serialNumber ?? '');
    final price = item?.unitPrice;
    _price = TextEditingController(
      text: price == null || price == 0 ? '' : price.toString(),
    );
    _notes = TextEditingController(text: item?.notes ?? '');
    _condition = item?.conditionStatus ?? 'Good';
    _calibration = item?.calibrationRequired ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _code, _name, _category, _room, _quantity,
      _brand, _model, _serial, _price, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final old = widget.equipment;
    final quantity = int.parse(_quantity.text.trim());
    final item = Equipment(
      id: old?.id,
      equipmentCode: _code.text.trim(),
      name: _name.text.trim(),
      category: _category.text.trim(),
      brand: blankToNull(_brand.text),
      model: blankToNull(_model.text),
      serialNumber: blankToNull(_serial.text),
      totalQuantity: quantity,
      availableQuantity: old?.availableQuantity ?? quantity,
      room: _room.text.trim(),
      building: old?.building,
      floor: old?.floor,
      shelf: old?.shelf,
      purchaseDate: old?.purchaseDate,
      unitPrice: _price.text.trim().isEmpty
          ? null
          : double.parse(_price.text.trim()),
      conditionStatus: _condition,
      status: old?.status ?? 'Available',
      calibrationRequired: _calibration,
      imagePath: old?.imagePath,
      notes: blankToNull(_notes.text),
      createdAt: old?.createdAt,
    );
    try {
      final repository = EquipmentRepository();
      if (old == null) {
        await repository.insert(item);
      } else {
        await repository.update(item);
      }
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
    final editing = widget.equipment != null;
    return Form(
      key: _formKey,
      child: FormSheet(
        title: editing ? 'Edit equipment' : 'Add equipment',
        icon: editing ? Icons.edit_rounded : Icons.add_box_rounded,
        children: [
          appField(_code, 'Equipment code', required: true, icon: Icons.qr_code_2_rounded),
          appField(_name, 'Name', required: true, icon: Icons.label_outline_rounded),
          appField(_category, 'Category', required: true, icon: Icons.category_outlined),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _category.text = s),
                  backgroundColor: categoryColor(s).withValues(alpha: 0.12),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: categoryColor(s),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          appField(_room, 'Room', required: true, icon: Icons.meeting_room_outlined),
          appField(_quantity, 'Total quantity', required: true, numeric: true, integer: true, min: 1, icon: Icons.numbers_rounded),
          appField(_brand, 'Brand'),
          appField(_model, 'Model'),
          appField(_serial, 'Serial number'),
          appField(_price, 'Unit price', numeric: true, min: 0, icon: Icons.payments_outlined),
          DropdownButtonFormField<String>(
            value: _condition,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: const ['Good', 'Fair', 'Damaged']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _condition = v ?? 'Good'),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text('Calibration required'),
            value: _calibration,
            onChanged: (v) => setState(() => _calibration = v),
          ),
          appField(_notes, 'Notes', maxLines: 2),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving...' : 'Save equipment'),
          ),
        ],
      ),
    );
  }
}
