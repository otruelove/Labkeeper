import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../constants.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(appDocDir.path, 'labkeeper.db');

    return openDatabase(
      dbPath,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        pin_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'Admin',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE equipment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        brand TEXT,
        model TEXT,
        serial_number TEXT,
        total_quantity INTEGER NOT NULL CHECK(total_quantity >= 0),
        available_quantity INTEGER NOT NULL DEFAULT 0 CHECK(available_quantity >= 0),
        room TEXT NOT NULL,
        building TEXT,
        floor TEXT,
        shelf TEXT,
        purchase_date TEXT,
        unit_price REAL,
        condition_status TEXT NOT NULL DEFAULT 'Good',
        status TEXT NOT NULL DEFAULT 'Available',
        calibration_required INTEGER NOT NULL DEFAULT 0,
        image_path TEXT,
        notes TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE issue_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_code TEXT NOT NULL UNIQUE,
        equipment_id INTEGER NOT NULL,
        borrower_name TEXT NOT NULL,
        borrower_id TEXT NOT NULL,
        borrower_type TEXT NOT NULL,
        department TEXT,
        quantity_issued INTEGER NOT NULL CHECK(quantity_issued > 0),
        quantity_returned INTEGER NOT NULL DEFAULT 0,
        issue_date TEXT NOT NULL,
        expected_return_date TEXT,
        status TEXT NOT NULL DEFAULT 'Active',
        purpose TEXT,
        issued_by INTEGER,
        received_by INTEGER,
        notes TEXT,
        FOREIGN KEY (equipment_id) REFERENCES equipment(id),
        FOREIGN KEY (issued_by) REFERENCES users(id),
        FOREIGN KEY (received_by) REFERENCES users(id)
      )
    ''');

    await _createReturnRecords(db);

    await db.execute('''
      CREATE TABLE maintenance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id INTEGER NOT NULL,
        maintenance_type TEXT NOT NULL,
        problem_description TEXT,
        scheduled_date TEXT,
        started_at TEXT,
        completed_at TEXT,
        technician_name TEXT,
        status TEXT NOT NULL DEFAULT 'Pending',
        work_performed TEXT,
        parts_replaced TEXT,
        next_maintenance_date TEXT,
        maintenance_cost REAL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (equipment_id) REFERENCES equipment(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE damage_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id INTEGER NOT NULL,
        report_id TEXT NOT NULL UNIQUE,
        reported_by TEXT,
        damage_date TEXT,
        report_date TEXT,
        severity TEXT NOT NULL,
        description TEXT,
        suspected_cause TEXT,
        immediate_action TEXT,
        repair_required INTEGER NOT NULL DEFAULT 0,
        resolution_notes TEXT,
        status TEXT NOT NULL DEFAULT 'Reported',
        image_path TEXT,
        FOREIGN KEY (equipment_id) REFERENCES equipment(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE calibration_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        equipment_id INTEGER NOT NULL,
        calibration_required INTEGER NOT NULL DEFAULT 0,
        last_calibration_date TEXT,
        calibration_provider TEXT,
        certificate_number TEXT,
        next_due_date TEXT,
        result TEXT,
        notes TEXT,
        FOREIGN KEY (equipment_id) REFERENCES equipment(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        action TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await _seedDefaultAdmin(db);
    await _seedSampleEquipment(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createReturnRecords(db);
    }
    if (oldVersion < 3) {
      // Sample data used to ship with units "issued" but no matching issue
      // record, so they could never be returned. Rebuild availability from
      // the real issue records.
      await db.execute('''
        UPDATE equipment SET available_quantity = MAX(0, MIN(total_quantity,
          total_quantity - COALESCE((SELECT SUM(r.quantity_issued - r.quantity_returned)
            FROM issue_records r WHERE r.equipment_id = equipment.id), 0)))
      ''');
      await db.execute(
        "UPDATE equipment SET status = 'Available' "
        "WHERE status = 'In Use' AND available_quantity = total_quantity",
      );
    }
  }

  Future<void> _createReturnRecords(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS return_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        issue_id INTEGER NOT NULL,
        quantity_returned INTEGER NOT NULL CHECK(quantity_returned > 0),
        return_date TEXT NOT NULL,
        condition_on_return TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (issue_id) REFERENCES issue_records(id)
      )
    ''');
  }

  Future<void> _seedDefaultAdmin(Database db) async {
    final createdAt = DateTime.now().toIso8601String();
    final pinHash = _hashPin(AppConstants.defaultPin);
    final existing = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [AppConstants.defaultUsername],
    );

    if (existing.isEmpty) {
      await db.insert('users', {
        'name': 'Administrator',
        'username': AppConstants.defaultUsername,
        'pin_hash': pinHash,
        'role': 'Admin',
        'is_active': 1,
        'created_at': createdAt,
      });
    }
  }

  Future<void> _seedSampleEquipment(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM equipment'),
        ) ??
        0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    final rows = [
      {
        'equipment_code': 'EQ-0001',
        'name': 'Digital Multimeter',
        'category': 'Measurement',
        'brand': 'Fluke',
        'model': '117',
        'serial_number': 'FLU-117-01',
        'total_quantity': 8,
        'available_quantity': 6,
        'room': 'Lab 201',
        'building': 'Engineering Block',
        'floor': '2',
        'shelf': 'A1',
        'purchase_date': '2024-01-12',
        'unit_price': 145.0,
        'condition_status': 'Good',
        'status': 'Available',
        'calibration_required': 1,
        'image_path': '',
        'notes': 'Daily lab usage',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
      {
        'equipment_code': 'EQ-0002',
        'name': 'Oscilloscope',
        'category': 'Measurement',
        'brand': 'Rigol',
        'model': 'DS1102Z',
        'serial_number': 'RIG-DS-21',
        'total_quantity': 4,
        'available_quantity': 4,
        'room': 'Lab 204',
        'building': 'Engineering Block',
        'floor': '2',
        'shelf': 'B2',
        'purchase_date': '2023-08-18',
        'unit_price': 640.0,
        'condition_status': 'Fair',
        'status': 'Available',
        'calibration_required': 1,
        'image_path': '',
        'notes': 'Used for signal analysis lab',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
      {
        'equipment_code': 'EQ-0003',
        'name': 'Bench Power Supply',
        'category': 'Power',
        'brand': 'Mastech',
        'model': 'HY3020E',
        'serial_number': 'MAS-HY-32',
        'total_quantity': 6,
        'available_quantity': 5,
        'room': 'Lab 103',
        'building': 'Science Block',
        'floor': '1',
        'shelf': 'C3',
        'purchase_date': '2022-05-20',
        'unit_price': 265.0,
        'condition_status': 'Good',
        'status': 'Available',
        'calibration_required': 0,
        'image_path': '',
        'notes': 'Power lab equipment',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final row in rows) {
      await db.insert('equipment', row);
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes).toString();
    return digest;
  }
}
