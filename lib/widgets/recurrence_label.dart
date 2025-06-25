import 'package:flutter/material.dart';

class RecurrenceLabel extends StatelessWidget {
  final String? recurring;
  const RecurrenceLabel(this.recurring, {super.key});

  @override
  Widget build(BuildContext context) {
    if (recurring == null || recurring!.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.repeat, color: Colors.blue, size: 18),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            recurring!,
            style: const TextStyle(color: Colors.blue, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
