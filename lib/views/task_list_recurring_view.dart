import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../logic/task_list_logic.dart';
import '../widgets/task_list_widget.dart';

class TaskListRecurringView extends StatelessWidget {
  final String vaultPath;
  final TextTheme textTheme;
  final Function(Task) onMarkDone;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final Future<void> Function(List<Task>) onAutoCreateInstances;

  const TaskListRecurringView({
    super.key,
    required this.vaultPath,
    required this.textTheme,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    required this.onAutoCreateInstances,
  });

  @override
  Widget build(BuildContext context) {
    final future = TaskListLogic.loadRecurringTasks(vaultPath);
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
          return Center(child: Text('No recurring tasks.'));
        }
        // Auto-create missing recurring instances
        onAutoCreateInstances(tasks);
        return TaskListWidget(
          tasks: tasks,
          onMarkDone: onMarkDone,
          onEdit: onEdit,
          onDelete: onDelete,
          titleStyle: textTheme.bodySmall,
          subtitleStyle: textTheme.bodySmall,
          leadingBuilder: (context, task, idx) => SizedBox(
            width: 56,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.repeat, color: Colors.blue, size: 20),
                IconButton(
                  icon: const Icon(Icons.radio_button_unchecked, size: 16),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Mark done',
                  onPressed: () => onMarkDone(task),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
