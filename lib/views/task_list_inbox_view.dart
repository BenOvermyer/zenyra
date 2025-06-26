import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../logic/task_list_logic.dart';
import '../widgets/task_list_widget.dart';

class TaskListInboxView extends StatelessWidget {
  final String vaultPath;
  final TextTheme textTheme;
  final Function(Task) onMarkDone;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final bool reorderable;
  final Future<void> Function(List<Task>, int, int)? onReorder;

  const TaskListInboxView({
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
    final future = TaskListLogic.loadTasksWithOrder('$vaultPath/inbox');
    return FutureBuilder<List<Task>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return Center(child: Text('No tasks in Inbox.'));
        }
        return TaskListWidget(
          tasks: tasks,
          onMarkDone: onMarkDone,
          onEdit: onEdit,
          onDelete: onDelete,
          reorderable: reorderable,
          onReorder: reorderable && onReorder != null
              ? (oldIndex, newIndex) async {
                  await onReorder!(tasks, oldIndex, newIndex);
                }
              : null,
          showDragHandle: true,
          titleStyle: textTheme.bodySmall,
          subtitleStyle: textTheme.bodySmall,
        );
      },
    );
  }
}
