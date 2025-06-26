import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../logic/task_list_logic.dart';
import '../widgets/task_list_widget.dart';

class TaskListTodayView extends StatelessWidget {
  final String vaultPath;
  final TextTheme textTheme;
  final Function(Task) onMarkDone;
  final Function(Task) onEdit;
  final Function(Task) onDelete;
  final bool reorderable;
  final Future<void> Function(List<Task>, int, int)? onReorder;

  const TaskListTodayView({
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
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final todayDirPath = '$vaultPath/by-date/$yyyy/$mm/$dd';
    final overdueFuture = TaskListLogic.loadOverdueTasks(vaultPath);
    final todayFuture = TaskListLogic.loadTasksWithOrder(todayDirPath);
    return FutureBuilder<List<List<Task>>>(
      future: Future.wait([overdueFuture, todayFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }
        final overdue = snapshot.data?[0] ?? [];
        final today = snapshot.data?[1] ?? [];
        if (overdue.isEmpty && today.isEmpty) {
          return Center(child: Text('No tasks in Today.'));
        }
        if (overdue.isNotEmpty && today.isNotEmpty) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text('Overdue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              Expanded(
                child: TaskListWidget(
                  tasks: overdue,
                  onMarkDone: onMarkDone,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  titleStyle: textTheme.bodySmall,
                  subtitleStyle: textTheme.bodySmall,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: TaskListWidget(
                  tasks: today,
                  onMarkDone: onMarkDone,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  reorderable: reorderable,
                  onReorder: reorderable && onReorder != null
                      ? (oldIndex, newIndex) async {
                          await onReorder!(today, oldIndex, newIndex);
                        }
                      : null,
                  showDragHandle: true,
                  titleStyle: textTheme.bodySmall,
                  subtitleStyle: textTheme.bodySmall,
                ),
              ),
            ],
          );
        } else if (overdue.isNotEmpty) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text('Overdue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              Expanded(
                child: TaskListWidget(
                  tasks: overdue,
                  onMarkDone: onMarkDone,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  titleStyle: textTheme.bodySmall,
                  subtitleStyle: textTheme.bodySmall,
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: TaskListWidget(
                  tasks: today,
                  onMarkDone: onMarkDone,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  reorderable: reorderable,
                  onReorder: reorderable && onReorder != null
                      ? (oldIndex, newIndex) async {
                          await onReorder!(today, oldIndex, newIndex);
                        }
                      : null,
                  showDragHandle: true,
                  titleStyle: textTheme.bodySmall,
                  subtitleStyle: textTheme.bodySmall,
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
