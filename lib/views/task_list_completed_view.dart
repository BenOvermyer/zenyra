import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../logic/task_list_logic.dart';
import '../widgets/task_list_widget.dart';

class TaskListCompletedView extends StatelessWidget {
  final String vaultPath;
  final TextTheme textTheme;
  final Function(Task) onMarkDone;
  final Function(Task) onEdit;
  final Function(Task) onDelete;

  const TaskListCompletedView({
    super.key,
    required this.vaultPath,
    required this.textTheme,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final future = TaskListLogic.loadCompletedTasks(vaultPath);
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
          return Center(child: Text('No completed tasks.'));
        }
        return TaskListWidget(
          tasks: tasks,
          onMarkDone: onMarkDone,
          onEdit: onEdit,
          onDelete: onDelete,
          reorderable: false,
          titleStyle: textTheme.bodySmall,
          subtitleStyle: textTheme.bodySmall,
          leadingBuilder: (context, task, idx) => const Icon(Icons.check_circle, color: Colors.green),
        );
      },
    );
  }
}
