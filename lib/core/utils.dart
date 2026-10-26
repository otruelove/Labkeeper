import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

String fmtDate(String? value) {
  if (value == null || value.isEmpty) return 'Not set';
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat.yMMMd().format(parsed);
}

String fmtDateTime(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : DateFormat('MMM d, h:mm a').format(parsed);
}

String? blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Turns database / framework exceptions into messages a person can act on.
String friendlyError(Object error) {
  final raw = error.toString();
  if (raw.contains('UNIQUE constraint failed: equipment.equipment_code')) {
    return 'That equipment code is already in use. Choose a different code.';
  }
  if (raw.contains('FormatException')) return 'Please enter a valid number.';
  if (raw.contains('DatabaseException')) {
    return 'Could not save your changes. Please try again.';
  }
  return raw
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Exception: ', '');
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.coral : AppColors.ink,
      ),
    );
}

void showError(BuildContext context, Object error) =>
    showMessage(context, friendlyError(error), error: true);
