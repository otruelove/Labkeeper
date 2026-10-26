import 'package:flutter/material.dart';

import '../core/theme.dart';

Color statusColor(String status) {
  switch (status) {
    case 'Available':
    case 'Good':
    case 'Returned':
    case 'Completed':
    case 'Resolved':
      return AppColors.green;
    case 'In Use':
    case 'Active':
    case 'In Progress':
    case 'Minor':
      return AppColors.sky;
    case 'Fair':
    case 'Under Maintenance':
    case 'Partially Returned':
    case 'Pending':
    case 'Moderate':
      return AppColors.amber;
    case 'Damaged':
    case 'Overdue':
    case 'Reported':
    case 'Critical':
      return AppColors.coral;
    default:
      return AppColors.muted;
  }
}

const _palette = [
  AppColors.primary,
  AppColors.teal,
  AppColors.sky,
  AppColors.amber,
  AppColors.coral,
  AppColors.green,
  AppColors.pink,
];

Color categoryColor(String category) =>
    _palette[category.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b) %
        _palette.length];

IconData categoryIcon(String category) {
  final s = category.toLowerCase();
  if (s.contains('measure')) return Icons.speed_rounded;
  if (s.contains('power')) return Icons.bolt_rounded;
  if (s.contains('optic') || s.contains('micro')) return Icons.biotech_rounded;
  if (s.contains('chem')) return Icons.science_rounded;
  if (s.contains('elec') || s.contains('comput')) return Icons.memory_rounded;
  if (s.contains('tool')) return Icons.build_rounded;
  return Icons.inventory_2_rounded;
}

Color availabilityColor(int available, int total) {
  if (total == 0) return AppColors.muted;
  final ratio = available / total;
  if (ratio > 0.5) return AppColors.green;
  if (ratio > 0.2) return AppColors.amber;
  return AppColors.coral;
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({
    required this.icon,
    required this.color,
    this.size = 46,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.color, super.key});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class AvailabilityBar extends StatelessWidget {
  const AvailabilityBar({
    required this.value,
    required this.total,
    this.color,
    this.height = 8,
    super.key,
  });

  final int value;
  final int total;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? availabilityColor(value, total);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : (value / total).clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: c.withValues(alpha: 0.16),
        valueColor: AlwaysStoppedAnimation(c),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconBox(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
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

/// Lays children out in two equal columns without fixed heights (no overflow).
class TwoColumn extends StatelessWidget {
  const TwoColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.primary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      child: Column(
        children: [
          IconBox(icon: icon, color: color, size: 84),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconBox(
              icon: Icons.cloud_off_rounded,
              color: AppColors.coral,
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consistent bottom-sheet layout for every form in the app.
class FormSheet extends StatelessWidget {
  const FormSheet({
    required this.title,
    required this.icon,
    required this.children,
    this.color = AppColors.primary,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: child,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextFormField appField(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool numeric = false,
  bool integer = false,
  int maxLines = 1,
  IconData? icon,
  double? min,
  String? Function(String text)? extra,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: numeric
        ? TextInputType.numberWithOptions(decimal: !integer)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
    ),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (required && text.isEmpty) return '$label is required.';
      if (text.isEmpty) return null;
      if (integer && int.tryParse(text) == null) {
        return 'Enter a whole number.';
      }
      if (numeric) {
        final n = double.tryParse(text);
        if (n == null) return 'Enter a valid number.';
        if (min != null && n < min) return 'Must be at least $min.';
      }
      return extra?.call(text);
    },
  );
}
