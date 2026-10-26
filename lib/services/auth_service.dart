import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../core/database/app_database.dart';
import '../models/user.dart';

class AuthService {
  final AppDatabase _database = AppDatabase.instance;

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<User?> login(String username, String pin) async {
    final db = await _database.database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = User.fromMap(rows.first);
    return user.pinHash == _hash(pin) ? user : null;
  }

  /// Verifies the current PIN, validates the new one, then stores it.
  Future<void> changePin(int userId, String currentPin, String newPin) async {
    if (newPin.length < 4 ||
        newPin.length > 12 ||
        int.tryParse(newPin) == null) {
      throw ArgumentError('PIN must be 4-12 digits.');
    }
    final db = await _database.database;
    final rows = await db.query(
      'users',
      columns: ['pin_hash'],
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['pin_hash'] != _hash(currentPin)) {
      throw StateError('Your current PIN is incorrect.');
    }
    await db.update(
      'users',
      {'pin_hash': _hash(newPin)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
