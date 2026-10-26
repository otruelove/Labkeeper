class Equipment {
  const Equipment({
    this.id,
    required this.equipmentCode,
    required this.name,
    required this.category,
    this.brand,
    this.model,
    this.serialNumber,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.room,
    this.building,
    this.floor,
    this.shelf,
    this.purchaseDate,
    this.unitPrice,
    this.conditionStatus = 'Good',
    this.status = 'Available',
    this.calibrationRequired = false,
    this.imagePath,
    this.notes,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String equipmentCode;
  final String name;
  final String category;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final int totalQuantity;
  final int availableQuantity;
  final String room;
  final String? building;
  final String? floor;
  final String? shelf;
  final String? purchaseDate;
  final double? unitPrice;
  final String conditionStatus;
  final String status;
  final bool calibrationRequired;
  final String? imagePath;
  final String? notes;
  final bool isArchived;
  final String? createdAt;
  final String? updatedAt;

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'] as int?,
      equipmentCode: map['equipment_code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '',
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      serialNumber: map['serial_number'] as String?,
      totalQuantity: map['total_quantity'] as int? ?? 0,
      availableQuantity: map['available_quantity'] as int? ?? 0,
      room: map['room'] as String? ?? '',
      building: map['building'] as String?,
      floor: map['floor'] as String?,
      shelf: map['shelf'] as String?,
      purchaseDate: map['purchase_date'] as String?,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      conditionStatus: map['condition_status'] as String? ?? 'Good',
      status: map['status'] as String? ?? 'Available',
      calibrationRequired: (map['calibration_required'] as int? ?? 0) == 1,
      imagePath: map['image_path'] as String?,
      notes: map['notes'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'equipment_code': equipmentCode,
      'name': name,
      'category': category,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'total_quantity': totalQuantity,
      'available_quantity': availableQuantity,
      'room': room,
      'building': building,
      'floor': floor,
      'shelf': shelf,
      'purchase_date': purchaseDate,
      'unit_price': unitPrice,
      'condition_status': conditionStatus,
      'status': status,
      'calibration_required': calibrationRequired ? 1 : 0,
      'image_path': imagePath,
      'notes': notes,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt ?? now,
      'updated_at': now,
    };
  }
}
