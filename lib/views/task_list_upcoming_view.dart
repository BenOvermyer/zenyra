import 'package:flutter/material.dart';
import '../models/upcoming_list_item.dart';
import '../widgets/task_list_widget.dart';
import '../models/task_model.dart';
import '../logic/task_list_logic.dart';

class TaskListUpcomingView extends StatelessWidget {
  final String vaultPath;
  final TextTheme textTheme;
  final Function(Task) onMarkDone;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final bool reorderable;
  final Future<void> Function(List<Task>, int, int)? onReorder;

  const TaskListUpcomingView({
    super.key,
    required this.vaultPath,
    required this.textTheme,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    this.reorderable = false,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final future = TaskListLogic.loadUpcomingItems(vaultPath);
    return FutureBuilder<List<UpcomingListItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}', style: textTheme.bodySmall));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(child: Text('No tasks in Upcoming.', style: textTheme.bodySmall));
        }
        // Group items by header and tasks for display
        final List<Widget> children = [];
        List<Task> currentGroup = [];
        String? currentHeader;
        for (final item in items) {
          if (item.isHeader) {
            if (currentGroup.isNotEmpty && currentHeader != null) {
              children.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Text(currentHeader, style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              ));
              children.add(TaskListWidget(
                tasks: List<Task>.from(currentGroup),
                onMarkDone: onMarkDone,
                onEdit: onEdit,
                onDelete: onDelete,
                titleStyle: textTheme.bodySmall,
                subtitleStyle: textTheme.bodySmall,
                reorderable: reorderable,
                onReorder: reorderable && onReorder != null
                    ? (oldIndex, newIndex) async {
                        await onReorder!(currentGroup, oldIndex, newIndex);
                      }
                    : null,
                leadingBuilder: null,
                key: ValueKey(currentHeader),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
              ));
              currentGroup = [];
            }
            final date = item.date!;
            currentHeader = '${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}, ${date.year}';
          } else {
            currentGroup.add(item.task!);
          }
        }
        if (currentGroup.isNotEmpty && currentHeader != null) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(currentHeader, style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ));
          children.add(TaskListWidget(
            tasks: List<Task>.from(currentGroup),
            onMarkDone: onMarkDone,
            onEdit: onEdit,
            onDelete: onDelete,
            titleStyle: textTheme.bodySmall,
            subtitleStyle: textTheme.bodySmall,
            reorderable: reorderable,
            onReorder: reorderable && onReorder != null
                ? (oldIndex, newIndex) async {
                    await onReorder!(currentGroup, oldIndex, newIndex);
                  }
                : null,
            leadingBuilder: null,
            key: ValueKey(currentHeader),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ));
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 15),
          children: children,
        );
      },
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }
}
