import 'package:flutter/material.dart';

/// Chrome shared by the admin workspaces.
class AdminPanel extends StatelessWidget {
  final Widget child;

  const AdminPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE3EA)),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class AdminSectionLabel extends StatelessWidget {
  final String label;

  const AdminSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF6A4B59),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class AdminNotice extends StatelessWidget {
  final String message;
  final bool isError;

  const AdminNotice({super.key, required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC6284A) : const Color(0xFF257550);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
