import 'package:flutter/material.dart';

import '../models/palette.dart';

class MaterialUsageList extends StatelessWidget {
  final Map<String, int> usage;
  final List<PaletteEntry> entries;
  final void Function(PaletteEntry entry)? onTap;
  final void Function(PaletteEntry entry)? onLongPress;

  const MaterialUsageList({
    super.key,
    required this.usage,
    required this.entries,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final sortedUsage = usage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in sortedUsage)
          _UsageChip(
            entry: _findEntry(item.key),
            ref: item.key,
            count: item.value,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
      ],
    );
  }

  PaletteEntry? _findEntry(String ref) {
    for (final entry in entries) {
      if (entry.ref == ref) return entry;
    }
    return null;
  }
}

class _UsageChip extends StatelessWidget {
  final PaletteEntry? entry;
  final String ref;
  final int count;
  final void Function(PaletteEntry entry)? onTap;
  final void Function(PaletteEntry entry)? onLongPress;

  const _UsageChip({
    required this.entry,
    required this.ref,
    required this.count,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry == null
        ? Colors.grey
        : Color.fromARGB(
            255,
            entry!.color.rInt,
            entry!.color.gInt,
            entry!.color.bInt,
          );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: entry == null || onTap == null ? null : () => onTap!(entry!),
      onLongPress: entry == null || onLongPress == null
          ? null
          : () => onLongPress!(entry!),
      child: Container(
        constraints: const BoxConstraints(minWidth: 98),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ref,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text('$count', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
