import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.user, super.key});

  final User user;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService().changePin(widget.user.id, _current.text.trim(), _newPin.text.trim());
      if (!mounted) return;
      _current.clear();
      _newPin.clear();
      _confirmPin.clear();
      setState(() => _saving = false);
      showMessage(context, 'PIN changed successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, error);
    }
  }

  TextFormField _pinField(TextEditingController c, String label, {String? Function(String)? extra}) {
    return TextFormField(
      controller: c,
      obscureText: true,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      ),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return '$label is required.';
        return extra?.call(t);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@${user.username} • ${user.role}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Change PIN'),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pinField(_current, 'Current PIN'),
                  const SizedBox(height: 14),
                  _pinField(
                    _newPin,
                    'New PIN (4-12 digits)',
                    extra: (t) => (t.length < 4 || t.length > 12 || int.tryParse(t) == null)
                        ? 'Use 4-12 digits.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _pinField(
                    _confirmPin,
                    'Confirm new PIN',
                    extra: (t) => t != _newPin.text.trim() ? 'PINs do not match.' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _changePin,
                    icon: const Icon(Icons.key_rounded),
                    label: Text(_saving ? 'Saving...' : 'Update PIN'),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('About'),
          const AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBox(icon: Icons.offline_bolt_rounded, color: AppColors.teal),
                  title: Text('Offline storage', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Equipment and activity are stored on this device.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBox(icon: Icons.biotech_rounded, color: AppColors.primary),
                  title: Text(AppConstants.appName, style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Laboratory Equipment Management'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
