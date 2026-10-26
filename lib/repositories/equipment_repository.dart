import 'package:sqflite/sqflite.dart';

import '../core/database/app_database.dart';
import '../models/equipment.dart';

class EquipmentRepository {
  final AppDatabase _database = AppDatabase.instance;

  Future<List<Equipment>> getAll() async {
    final db = await _database.database;
    final maps = await db.query(
      'equipment',
      where: 'is_archived = ?',
      whereArgs: [0],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return maps.map(Equipment.fromMap).toList();
  }

  Future<Equipment?> getByCode(String equipmentCode) async {
    final db = await _database.database;
    final maps = await db.query(
      'equipment',
      where: 'equipment_code = ? AND is_archived = ?',
      whereArgs: [equipmentCode.trim(), 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Equipment.fromMap(maps.first);
  }

  Future<int> insert(Equipment equipment) async {
    _validateEquipment(equipment);
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final values = equipment.toMap()
        ..['available_quantity'] = equipment.totalQuantity
        ..['created_at'] = now
        ..['updated_at'] = now;
      final id = await txn.insert('equipment', values);
      await _log(txn, 'equipment', id, 'created', 'Added ${equipment.name}');
      return id;
    });
  }

  Future<int> update(Equipment equipment) async {
    _validateEquipment(equipment);
    if (equipment.id == null) {
      throw ArgumentError('Equipment ID is required to update a record.');
    }

    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'equipment',
        columns: ['total_quantity', 'available_quantity'],
        where: 'id = ? AND is_archived = 0',
        whereArgs: [equipment.id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Equipment was not found.');
      final outstanding =
          (rows.first['total_quantity'] as int) -
          (rows.first['available_quantity'] as int);
      if (equipment.totalQuantity < outstanding) {
        throw StateError(
          'Total quantity cannot be less than the $outstanding units currently issued.',
        );
      }

      final now = DateTime.now().toIso8601String();
      final values = equipment.toMap()
        ..['available_quantity'] = equipment.totalQuantity - outstanding
        ..['updated_at'] = now
        ..remove('status')
        ..remove('created_at');
      final changed = await txn.update(
        'equipment',
        values,
        where: 'id = ? AND is_archived = 0',
        whereArgs: [equipment.id],
      );
      if (changed == 0) throw StateError('Equipment could not be updated.');
      await _log(
        txn,
        'equipment',
        equipment.id,
        'updated',
        'Updated ${equipment.name}',
      );
      return changed;
    });
  }

  Future<int> archive(int id) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'equipment',
        columns: ['total_quantity', 'available_quantity', 'name'],
        where: 'id = ? AND is_archived = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Equipment was not found.');
      if (rows.first['total_quantity'] != rows.first['available_quantity']) {
        throw StateError(
          'Return all issued units before archiving this equipment.',
        );
      }
      final changed = await txn.update(
        'equipment',
        {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _log(
        txn,
        'equipment',
        id,
        'archived',
        'Archived ${rows.first['name']}',
      );
      return changed;
    });
  }

  Future<Map<String, int>> getDashboardSummary() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_quantity), 0) AS total_units,
        COALESCE(SUM(available_quantity), 0) AS available_units,
        COALESCE(SUM(total_quantity - available_quantity), 0) AS issued_units,
        COALESCE(SUM(CASE WHEN condition_status = 'Damaged' THEN total_quantity ELSE 0 END), 0) AS damaged_units,
        COALESCE(SUM(CASE WHEN status = 'Under Maintenance' THEN total_quantity ELSE 0 END), 0) AS maintenance_units
      FROM equipment
      WHERE is_archived = 0
    ''');
    final row = rows.first;
    final overdue = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM issue_records '
      'WHERE quantity_returned < quantity_issued '
      'AND expected_return_date IS NOT NULL AND expected_return_date < ?',
      [_startOfToday()],
    );
    int number(String key) => (row[key] as num?)?.toInt() ?? 0;
    return {
      'total_units': number('total_units'),
      'available_units': number('available_units'),
      'issued_units': number('issued_units'),
      'damaged_units': number('damaged_units'),
      'maintenance_units': number('maintenance_units'),
      'overdue_loans': (overdue.first['c'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Map<String, Object?>>> getCategoryBreakdown() async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT category, SUM(total_quantity) AS total, SUM(available_quantity) AS available
      FROM equipment WHERE is_archived = 0
      GROUP BY category ORDER BY total DESC
    ''');
  }

  String _startOfToday() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).toIso8601String();
  }

  Future<List<Map<String, Object?>>> getTransactions({
    bool activeOnly = false,
  }) async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT r.*, e.equipment_code, e.name AS equipment_name,
        (r.quantity_issued - r.quantity_returned) AS quantity_outstanding,
        CASE WHEN r.quantity_returned < r.quantity_issued
          AND r.expected_return_date IS NOT NULL
          AND r.expected_return_date < ? THEN 1 ELSE 0 END AS is_overdue
      FROM issue_records r
      JOIN equipment e ON e.id = r.equipment_id
      ${activeOnly ? "WHERE r.quantity_returned < r.quantity_issued" : ""}
      ORDER BY r.issue_date DESC, r.id DESC
    ''', [_startOfToday()]);
  }

  Future<List<Map<String, Object?>>> getReturnHistory(int issueId) async {
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT * FROM return_records WHERE issue_id = ? ORDER BY return_date DESC, id DESC
      ''',
      [issueId],
    );
  }

  Future<int> issueEquipment({
    required Equipment equipment,
    required String borrowerName,
    required String borrowerId,
    required String borrowerType,
    required int quantity,
    required DateTime expectedReturn,
    required String purpose,
  }) async {
    if (quantity < 1) {
      throw ArgumentError('Issue quantity must be at least one.');
    }
    if (borrowerName.trim().isEmpty || borrowerId.trim().isEmpty) {
      throw ArgumentError('Borrower name and ID are required.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final currentRows = await txn.query(
        'equipment',
        columns: [
          'available_quantity',
          'status',
          'condition_status',
          'is_archived',
        ],
        where: 'id = ?',
        whereArgs: [equipment.id],
        limit: 1,
      );
      if (currentRows.isEmpty || currentRows.first['is_archived'] == 1) {
        throw StateError('This equipment is no longer available.');
      }
      final current = currentRows.first;
      if (current['status'] == 'Under Maintenance' ||
          current['condition_status'] == 'Damaged') {
        throw StateError('Damaged or maintained equipment cannot be issued.');
      }
      final available = current['available_quantity'] as int;
      if (quantity > available) {
        throw StateError('Only $available units are currently available.');
      }

      final now = DateTime.now();
      final txCode = 'TX-${now.microsecondsSinceEpoch}';
      final issueId = await txn.insert('issue_records', {
        'transaction_code': txCode,
        'equipment_id': equipment.id,
        'borrower_name': borrowerName.trim(),
        'borrower_id': borrowerId.trim(),
        'borrower_type': borrowerType,
        'quantity_issued': quantity,
        'quantity_returned': 0,
        'issue_date': now.toIso8601String(),
        'expected_return_date': expectedReturn.toIso8601String(),
        'status': 'Active',
        'purpose': purpose.trim(),
      });
      final newAvailable = available - quantity;
      await txn.update(
        'equipment',
        {
          'available_quantity': newAvailable,
          'status': newAvailable == 0 ? 'In Use' : 'Available',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [equipment.id],
      );
      await _log(
        txn,
        'transaction',
        issueId,
        'issued',
        '$quantity × ${equipment.name} issued to ${borrowerName.trim()}',
      );
      return issueId;
    });
  }

  Future<void> returnEquipment({
    required int issueId,
    required int quantity,
    required String condition,
    required String notes,
  }) async {
    if (quantity < 1) {
      throw ArgumentError('Return quantity must be at least one.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery(
        '''
        SELECT r.*, e.available_quantity, e.total_quantity, e.condition_status,
          e.status AS equipment_status, e.id AS linked_equipment_id
        FROM issue_records r
        JOIN equipment e ON e.id = r.equipment_id
        WHERE r.id = ? AND r.quantity_returned < r.quantity_issued
      ''',
        [issueId],
      );
      if (rows.isEmpty) {
        throw StateError('This transaction has no units to return.');
      }
      final row = rows.first;
      final outstanding =
          (row['quantity_issued'] as int) - (row['quantity_returned'] as int);
      if (quantity > outstanding) {
        throw StateError('Only $outstanding units remain outstanding.');
      }

      final newReturned = (row['quantity_returned'] as int) + quantity;
      final newAvailable = (row['available_quantity'] as int) + quantity;
      final fullyReturned = newReturned == row['quantity_issued'];
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'issue_records',
        {
          'quantity_returned': newReturned,
          'status': fullyReturned ? 'Returned' : 'Partially Returned',
        },
        where: 'id = ?',
        whereArgs: [issueId],
      );
      final equipmentId = row['linked_equipment_id'] as int;
      await txn.insert('return_records', {
        'issue_id': issueId,
        'quantity_returned': quantity,
        'return_date': now,
        'condition_on_return': condition,
        'notes': notes.trim(),
      });
      final equipmentStatus = row['equipment_status'] as String;
      await txn.update(
        'equipment',
        {
          'available_quantity': newAvailable,
          'status': (equipmentStatus == 'Under Maintenance' ||
                  condition == 'Damaged')
              ? 'Under Maintenance'
              : newAvailable == (row['total_quantity'] as int)
              ? 'Available'
              : 'In Use',
          if (condition == 'Damaged') 'condition_status': 'Damaged',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [equipmentId],
      );
      if (condition == 'Damaged') {
        final code = 'DM-${DateTime.now().microsecondsSinceEpoch}';
        await txn.insert('damage_reports', {
          'equipment_id': equipmentId,
          'report_id': code,
          'reported_by': 'Return inspection',
          'damage_date': now,
          'report_date': now,
          'severity': 'Moderate',
          'description': 'Returned equipment was marked damaged.',
          'repair_required': 1,
          'status': 'Reported',
          'resolution_notes': notes.trim(),
        });
        await _ensureRepairTicket(
          txn,
          equipmentId,
          'Returned damaged. Inspection and repair needed.',
          now,
        );
      }
      await _log(
        txn,
        'transaction',
        issueId,
        'returned',
        'Returned $quantity unit(s); condition: $condition',
      );
    });
  }

  Future<List<Map<String, Object?>>> getMaintenance() async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT m.*, e.equipment_code, e.name AS equipment_name
      FROM maintenance_records m
      JOIN equipment e ON e.id = m.equipment_id
      ORDER BY CASE m.status WHEN 'In Progress' THEN 0 WHEN 'Pending' THEN 1 ELSE 2 END,
        COALESCE(m.scheduled_date, m.created_at) DESC
    ''');
  }

  Future<int> saveMaintenance({
    required Equipment equipment,
    required String type,
    required String description,
    required DateTime scheduledDate,
  }) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('maintenance_records', {
        'equipment_id': equipment.id,
        'maintenance_type': type,
        'problem_description': description.trim(),
        'scheduled_date': scheduledDate.toIso8601String(),
        'status': 'Pending',
        'created_at': now,
        'updated_at': now,
      });
      if (type == 'Repair') {
        await txn.update(
          'equipment',
          {'status': 'Under Maintenance', 'updated_at': now},
          where: 'id = ?',
          whereArgs: [equipment.id],
        );
      }
      await _log(
        txn,
        'maintenance',
        id,
        'created',
        'Scheduled $type for ${equipment.name}',
      );
      return id;
    });
  }

  Future<void> updateMaintenanceStatus(int id, String status) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'maintenance_records',
        columns: ['equipment_id', 'maintenance_type', 'status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Maintenance record was not found.');
      final current = rows.first['status'] as String;
      final allowed = {
        'Pending': ['In Progress', 'Completed', 'Cancelled'],
        'In Progress': ['Completed', 'Cancelled'],
      }[current];
      if (allowed == null || !allowed.contains(status)) {
        throw StateError('A $current record cannot be changed to $status.');
      }
      final equipmentId = rows.first['equipment_id'] as int;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'maintenance_records',
        {
          'status': status,
          'updated_at': now,
          if (status == 'In Progress') 'started_at': now,
          if (status == 'Completed') 'completed_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.first['maintenance_type'] == 'Repair') {
        final open = await txn.rawQuery(
          "SELECT COUNT(*) AS count FROM maintenance_records WHERE equipment_id = ? AND maintenance_type = 'Repair' AND status IN ('Pending', 'In Progress')",
          [equipmentId],
        );
        if ((open.first['count'] as int) == 0) {
          final equipment = await txn.query(
            'equipment',
            columns: ['total_quantity', 'available_quantity', 'condition_status'],
            where: 'id = ?',
            whereArgs: [equipmentId],
            limit: 1,
          );
          if (equipment.isNotEmpty) {
            final item = equipment.first;
            final repaired = status == 'Completed';
            final stillDamaged =
                !repaired && item['condition_status'] == 'Damaged';
            if (!stillDamaged) {
              final isIssued =
                  item['available_quantity'] != item['total_quantity'];
              await txn.update(
                'equipment',
                {
                  'status': isIssued ? 'In Use' : 'Available',
                  if (repaired) 'condition_status': 'Good',
                  'updated_at': now,
                },
                where: 'id = ?',
                whereArgs: [equipmentId],
              );
            }
          }
        }
      }
      await _log(
        txn,
        'maintenance',
        id,
        'status_changed',
        'Maintenance status changed to $status',
      );
    });
  }

  Future<void> _ensureRepairTicket(
    Transaction txn,
    int equipmentId,
    String description,
    String now,
  ) async {
    final open = await txn.rawQuery(
      "SELECT COUNT(*) AS count FROM maintenance_records WHERE equipment_id = ? AND maintenance_type = 'Repair' AND status IN ('Pending', 'In Progress')",
      [equipmentId],
    );
    if ((open.first['count'] as int) > 0) return;
    await txn.insert('maintenance_records', {
      'equipment_id': equipmentId,
      'maintenance_type': 'Repair',
      'problem_description': description,
      'scheduled_date': now,
      'status': 'Pending',
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> createDamageReport({
    required Equipment equipment,
    required String severity,
    required String description,
    required String reportedBy,
    required bool repairRequired,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Please describe the damage.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('damage_reports', {
        'equipment_id': equipment.id,
        'report_id': 'DM-${DateTime.now().microsecondsSinceEpoch}',
        'reported_by': reportedBy.trim(),
        'damage_date': now,
        'report_date': now,
        'severity': severity,
        'description': description.trim(),
        'repair_required': repairRequired ? 1 : 0,
        'status': 'Reported',
      });
      if (severity == 'Critical' || repairRequired) {
        await txn.update(
          'equipment',
          {
            'condition_status': 'Damaged',
            'status': 'Under Maintenance',
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [equipment.id],
        );
        await _ensureRepairTicket(
          txn,
          equipment.id!,
          description.trim(),
          now,
        );
      }
      await _log(
        txn,
        'damage',
        id,
        'reported',
        'Damage reported for ${equipment.name} ($severity)',
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> getDamageReports() async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT d.*, e.equipment_code, e.name AS equipment_name
      FROM damage_reports d
      JOIN equipment e ON e.id = d.equipment_id
      ORDER BY d.report_date DESC, d.id DESC
    ''');
  }

  Future<List<Map<String, Object?>>> getActivities() async {
    final db = await _database.database;
    return db.query('activity_logs', orderBy: 'created_at DESC', limit: 30);
  }

  Future<void> resolveDamageReport(int id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final changed = await txn.update(
        'damage_reports',
        {'status': 'Resolved'},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (changed == 0) throw StateError('Damage report was not found.');
      await _log(txn, 'damage', id, 'resolved', 'Damage report resolved');
    });
  }

  Future<void> _log(
    Transaction txn,
    String type,
    int? id,
    String action,
    String message,
  ) async {
    await txn.insert('activity_logs', {
      'entity_type': type,
      'entity_id': id,
      'action': action,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void _validateEquipment(Equipment equipment) {
    if (equipment.equipmentCode.trim().isEmpty ||
        equipment.name.trim().isEmpty ||
        equipment.category.trim().isEmpty ||
        equipment.room.trim().isEmpty) {
      throw ArgumentError('Code, name, category, and room are required.');
    }
    if (equipment.totalQuantity < 1) {
      throw ArgumentError('Total quantity must be at least one.');
    }
    if (equipment.unitPrice != null && equipment.unitPrice! < 0) {
      throw ArgumentError('Unit price cannot be negative.');
    }
  }
}
