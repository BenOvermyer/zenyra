import 'package:flutter/material.dart';
import '../models/task_model.dart';
import 'recurrence_label.dart';

class TaskListWidget extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onMarkDone;
  final void Function(Task) onEdit;
  final void Function(Task) onDelete;
  final bool reorderable;
  final void Function(int, int)? onReorder;
  final bool showDragHandle;
  final bool showRecurringIcon;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Widget Function(BuildContext context, Task task, int? idx)? leadingBuilder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const TaskListWidget({
    super.key,
    required this.tasks,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    this.reorderable = false,
    this.onReorder,
    this.showDragHandle = false,
    this.showRecurringIcon = false,
    this.titleStyle,
    this.subtitleStyle,
    this.leadingBuilder,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildTile(Task task, {Key? key, int? idx}) {
      final tile = ListTile(
        leading: leadingBuilder != null
            ? leadingBuilder!(context, task, idx)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDragHandle && idx != null)
                    ReorderableDragStartListener(
                      index: idx,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  if (showRecurringIcon)
                    const Icon(Icons.repeat, color: Colors.blue),
                  IconButton(
                    icon: const Icon(Icons.radio_button_unchecked, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Mark done',
                    onPressed: () => onMarkDone(task),
                  ),
                ],
              ),
        title: Row(
          children: [
            Flexible(child: Text(task.title, style: titleStyle)),
            if (task.recurring != null && task.recurring!.isNotEmpty) ...[
              const SizedBox(width: 6),
              RecurrenceLabel(task.recurring),
            ],
          ],
        ),
        subtitle: task.content.isNotEmpty
            ? Text(task.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle)
            : null,
        onTap: () => onEdit(task),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
          tooltip: 'Delete task',
          onPressed: () => onDelete(task),
        ),
      );
      return Column(
        key: key,
        children: [
          tile,
          const Divider(height: 1, thickness: 1, indent: 20, color: Colors.grey),
        ],
      );
    }

    if (reorderable && onReorder != null) {
      return ReorderableListView.builder(
        itemCount: tasks.length,
        onReorder: onReorder!,
        itemBuilder: (context, idx) => buildTile(tasks[idx], key: ValueKey(tasks[idx].filePath), idx: idx),
      );
    } else {
      return ListView.builder(
        itemCount: tasks.length,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemBuilder: (context, idx) => buildTile(tasks[idx]),
      );
    }
  }
}
