import 'dart:io';
import 'package:flutter/material.dart';
import 'models/upcoming_list_item.dart';
import 'widgets/recurrence_label.dart';
import 'task_model.dart';
import 'task_create_dialog.dart';
import 'logic/task_list_logic.dart';
import 'widgets/task_list_widget.dart';

class TaskListView extends StatefulWidget {
  final String vaultPath;
  final String view;
  const TaskListView({super.key, required this.vaultPath, required this.view});

  @override
  TaskListViewState createState() => TaskListViewState();
}

class TaskListViewState extends State<TaskListView> {
  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (widget.view == 'Upcoming') {
      final future = TaskListLogic.loadUpcomingItems(widget.vaultPath);
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
            return Center(child: Text('No tasks in \\${widget.view}.', style: textTheme.bodySmall));
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
                  onMarkDone: _markTaskDone,
                  onEdit: _editTask,
                  onDelete: _confirmDeleteTask,
                  titleStyle: textTheme.bodySmall,
                  subtitleStyle: textTheme.bodySmall,
                  reorderable: false,
                  // Prevent nested scrollables
                  leadingBuilder: null,
                  // Use shrinkWrap and disable scrolling for inner lists
                  key: ValueKey(currentHeader),
                  // Custom build: pass shrinkWrap/physics via a builder
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
              onMarkDone: _markTaskDone,
              onEdit: _editTask,
              onDelete: _confirmDeleteTask,
              titleStyle: textTheme.bodySmall,
              subtitleStyle: textTheme.bodySmall,
              reorderable: false,
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
    if (widget.view == 'Today') {
      final now = DateTime.now();
      final yyyy = now.year.toString().padLeft(4, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final todayDirPath = '${widget.vaultPath}/by-date/$yyyy/$mm/$dd';
      final overdueFuture = TaskListLogic.loadOverdueTasks(widget.vaultPath);
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
                    onMarkDone: _markTaskDone,
                    onEdit: _editTask,
                    onDelete: _confirmDeleteTask,
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
                    onMarkDone: _markTaskDone,
                    onEdit: _editTask,
                    onDelete: _confirmDeleteTask,
                    reorderable: true,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = today.removeAt(oldIndex);
                        today.insert(newIndex, item);
                      });
                      await TaskListLogic.saveOrder(today, todayDirPath);
                    },
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
                    onMarkDone: _markTaskDone,
                    onEdit: _editTask,
                    onDelete: _confirmDeleteTask,
                    titleStyle: textTheme.bodySmall,
                    subtitleStyle: textTheme.bodySmall,
                  ),
                ),
              ],
            );
          } else {
            // today.isNotEmpty
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TaskListWidget(
                    tasks: today,
                    onMarkDone: _markTaskDone,
                    onEdit: _editTask,
                    onDelete: _confirmDeleteTask,
                    reorderable: true,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = today.removeAt(oldIndex);
                        today.insert(newIndex, item);
                      });
                      await TaskListLogic.saveOrder(today, todayDirPath);
                    },
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
    if (widget.view == 'Inbox') {
      final future = TaskListLogic.loadTasksWithOrder('${widget.vaultPath}/inbox');
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
            onMarkDone: _markTaskDone,
            onEdit: _editTask,
            onDelete: _confirmDeleteTask,
            reorderable: true,
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = tasks.removeAt(oldIndex);
                tasks.insert(newIndex, item);
              });
              await TaskListLogic.saveOrder(tasks, '${widget.vaultPath}/inbox');
            },
            showDragHandle: true,
            titleStyle: textTheme.bodySmall,
            subtitleStyle: textTheme.bodySmall,
          );
        },
      );
    }
    if (widget.view == 'Recurring') {
      final future = TaskListLogic.loadRecurringTasks(widget.vaultPath);
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
          // --- Begin: Auto-create missing recurring instances logic ---
          Future.microtask(() async {
            bool created = false;
            for (final task in tasks) {
              // Only create a new instance if this task is NOT itself a recurring template (i.e., only if it is a dated instance)
              // Recurring templates should not have a dueDate in the future or present, only in the past (or null)
              // So, only create a new instance if the dueDate is in the past (before today)
              if (task.recurring != null && task.recurring!.isNotEmpty && task.dueDate != null && task.dueDate!.isNotEmpty) {
                final dueDate = _parseDueDate(task.dueDate!);
                final now = DateTime.now();
                if (dueDate != null && dueDate.isBefore(DateTime(now.year, now.month, now.day))) {
                  final nextDue = _nextRecurrenceDate(task.dueDate!, task.recurring!, isFirstInstance: false);
                  if (nextDue != null) {
                    final yyyy = nextDue.year.toString().padLeft(4, '0');
                    final mm = nextDue.month.toString().padLeft(2, '0');
                    final dd = nextDue.day.toString().padLeft(2, '0');
                    final folder = Directory('${widget.vaultPath}/by-date/$yyyy/$mm/$dd');
                    if (!await folder.exists()) await folder.create(recursive: true);
                    final safeTitle = task.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
                    // Check if an instance for this title and due date already exists
                    final files = await folder.list().where((e) => e is File && e.path.endsWith('.md')).cast<File>().toList();
                    bool instanceExists = false;
                    for (final file in files) {
                      final text = await file.readAsString();
                      final titleMatch = RegExp(r'title:\s*"?([^\"]+)"?').firstMatch(text);
                      final dueMatch = RegExp(r'due:\s*"?(\d{4}-\d{2}-\d{2})"?').firstMatch(text);
                      if (titleMatch != null && dueMatch != null &&
                          titleMatch.group(1)?.trim() == task.title.trim() &&
                          dueMatch.group(1) == '$yyyy-$mm-$dd') {
                        instanceExists = true;
                        break;
                      }
                    }
                    if (!instanceExists) {
                      final nextFile = File('${folder.path}/$safeTitle-${nextDue.millisecondsSinceEpoch}.md');
                      final nextFrontmatter = StringBuffer('---\n');
                      nextFrontmatter.writeln('title: "${task.title}"');
                      nextFrontmatter.writeln('due: "$yyyy-$mm-$dd"');
                      nextFrontmatter.writeln('recurring: "${task.recurring}"');
                      nextFrontmatter.writeln('done: false');
                      nextFrontmatter.writeln('---\n');
                      await nextFile.writeAsString(nextFrontmatter.toString() + task.content.trim());
                      created = true;
                    }
                  }
                }
              }
            }
            if (created && mounted) setState(() {});
          });
          // --- End: Auto-create missing recurring instances logic ---
          return TaskListWidget(
            tasks: tasks,
            onMarkDone: _markTaskDone,
            onEdit: _editTask,
            onDelete: _confirmDeleteTask,
            // Recurring tasks always have recurrence, so RecurrenceLabel will be shown in TaskListWidget
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
                    onPressed: () => _markTaskDone(task),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    final future = _loadTasks();
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
          return Center(child: Text('No tasks in \\${widget.view}.'));
        }
        if (widget.view == 'Completed') {
          return TaskListWidget(
            tasks: tasks,
            onMarkDone: _markTaskDone,
            onEdit: _editTask,
            onDelete: _confirmDeleteTask,
            reorderable: false,
            titleStyle: textTheme.bodySmall,
            subtitleStyle: textTheme.bodySmall,
            leadingBuilder: (context, task, idx) => const Icon(Icons.check_box, color: Colors.green),
          );
        }
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, idx) {
            final task = tasks[idx];
            return ListTile(
              leading: widget.view != 'Completed'
                  ? IconButton(
                      icon: const Icon(Icons.check_box_outline_blank),
                      tooltip: 'Mark done',
                      onPressed: () => _markTaskDone(task),
                    )
                  : const Icon(Icons.check_box, color: Colors.green),
              title: Row(
                children: [
                  Text(task.title),
                  if (task.recurring != null && task.recurring!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    RecurrenceLabel(task.recurring),
                  ],
                ],
              ),
              subtitle: task.content.isNotEmpty ? Text(task.content, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
              onTap: () => _editTask(task),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete task',
                onPressed: () => _confirmDeleteTask(task),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to build friendly weekday/month names
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

  // The following methods (_editTask, _markTaskDone, _confirmDeleteTask, _loadUpcomingItems, _loadTasks) should be refactored to use TaskListLogic as well.
  Future<void> _editTask(Task task) async {
    final result = await showDialog<Map<String, String?>> (
      context: context,
      builder: (context) => TaskCreateDialog(
        initialTitle: task.title,
        initialDue: task.dueDate,
        initialContent: task.content,
        initialRecurring: task.recurring, // Pass current recurrence
      ),
    );
    if (result != null) {
      await _updateTaskFile(
        task,
        result['title']!,
        result['due'],
        result['content'] ?? '',
        newRecurring: result['recurring'],
      );
      setState(() {
        // No need to update futures here
      });
    }
  }

  Future<void> _updateTaskFile(Task oldTask, String newTitle, String? newDue, String newContent, {String? newRecurring}) async {
    // Detect if recurrence is being added to a non-recurring task
    final hadRecurrence = oldTask.recurring != null && oldTask.recurring!.trim().isNotEmpty;
    final hasRecurrence = newRecurring != null && newRecurring.trim().isNotEmpty;
    String? effectiveDue = newDue;
    if (!hadRecurrence && hasRecurrence) {
      // Always set due to today for new recurring tasks except 'weekly on <weekday>'
      final rec = newRecurring.trim().toLowerCase();
      final weeklyOnMatch = RegExp(r'^weekly on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)').firstMatch(rec);
      final now = DateTime.now();
      if (weeklyOnMatch != null) {
        final weekdayStr = weeklyOnMatch.group(1)!;
        final weekdayMap = {
          'monday': 1,
          'tuesday': 2,
          'wednesday': 3,
          'thursday': 4,
          'friday': 5,
          'saturday': 6,
          'sunday': 7,
        };
        final targetWeekday = weekdayMap[weekdayStr];
        if (targetWeekday != null && now.weekday != targetWeekday) {
          final daysToAdd = (targetWeekday - now.weekday + 7) % 7;
          final nextDate = now.add(Duration(days: daysToAdd == 0 ? 7 : daysToAdd));
          effectiveDue = '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';
        } else {
          effectiveDue = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        }
      } else {
        effectiveDue = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      }
    }
    // Write or move the updated task file (with recurrence if present)
    String folder;
    String? normalizedDue;
    if (effectiveDue != null && effectiveDue.isNotEmpty) {
      final match = RegExp(r'^(\d{4})[-/]?(\d{2})[-/]?(\d{2})').firstMatch(effectiveDue);
      if (match != null) {
        final yyyy = match.group(1)!;
        final mm = match.group(2)!;
        final dd = match.group(3)!;
        folder = '${widget.vaultPath}/by-date/$yyyy/$mm/$dd';
        normalizedDue = '$yyyy-$mm-$dd';
      } else {
        folder = '${widget.vaultPath}/inbox';
      }
    } else {
      folder = '${widget.vaultPath}/inbox';
    }
    final dir = Directory(folder);
    if (!await dir.exists()) await dir.create(recursive: true);
    final safeTitle = newTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = '$safeTitle-${DateTime.now().millisecondsSinceEpoch}.md';
    final newFilePath = '${dir.path}/$filename';
    final frontmatter = StringBuffer('---\n');
    frontmatter.writeln('title: "$newTitle"');
    if (normalizedDue != null) frontmatter.writeln('due: "$normalizedDue"');
    if (hasRecurrence) frontmatter.writeln('recurring: "$newRecurring"');
    frontmatter.writeln('done: ${oldTask.done}');
    frontmatter.writeln('---\n');
    final newContentFull = frontmatter.toString() + newContent.trim();
    // If the file is already in the correct place and name, just overwrite
    if (oldTask.filePath == newFilePath) {
      await File(oldTask.filePath).writeAsString(newContentFull);
    } else {
      // Move (rename) the file if possible, otherwise create new and delete old
      try {
        await File(oldTask.filePath).rename(newFilePath);
        await File(newFilePath).writeAsString(newContentFull);
      } catch (_) {
        await File(newFilePath).writeAsString(newContentFull);
        try { await File(oldTask.filePath).delete(); } catch (_) {}
      }
    }
  }

  Future<void> _markTaskDone(Task task) async {
    final doneDir = Directory('${widget.vaultPath}/done');
    if (!await doneDir.exists()) await doneDir.create(recursive: true);
    final safeTitle = task.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = '$safeTitle-${DateTime.now().millisecondsSinceEpoch}.md';
    final file = File('${doneDir.path}/$filename');
    final frontmatter = StringBuffer('---\n');
    frontmatter.writeln('title: "${task.title}"');
    if (task.dueDate != null && task.dueDate!.isNotEmpty) frontmatter.writeln('due: "${task.dueDate}"');
    if (task.recurring != null && task.recurring!.isNotEmpty) frontmatter.writeln('recurring: "${task.recurring}"');
    frontmatter.writeln('done: true');
    frontmatter.writeln('---\n');
    await file.writeAsString(frontmatter.toString() + task.content.trim());
    try { await File(task.filePath).delete(); } catch (_) {}
    final files = await doneDir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();
    if (files.length > 20) {
      files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      final oldest = files.first;
      final archiveDir = Directory('${widget.vaultPath}/archive');
      if (!await archiveDir.exists()) await archiveDir.create(recursive: true);
      final archiveFile = File('${archiveDir.path}/${oldest.uri.pathSegments.last}');
      await oldest.rename(archiveFile.path);
    }
    if (task.recurring != null && task.recurring!.isNotEmpty && task.dueDate != null && task.dueDate!.isNotEmpty) {
      // When creating the first instance, pass isFirstInstance: true
      final nextDue = _nextRecurrenceDate(task.dueDate!, task.recurring!, isFirstInstance: false);
      if (nextDue != null) {
        final yyyy = nextDue.year.toString().padLeft(4, '0');
        final mm = nextDue.month.toString().padLeft(2, '0');
        final dd = nextDue.day.toString().padLeft(2, '0');
        final folder = Directory('${widget.vaultPath}/by-date/$yyyy/$mm/$dd');
        if (!await folder.exists()) await folder.create(recursive: true);
        final nextFile = File('${folder.path}/$safeTitle-${nextDue.millisecondsSinceEpoch}.md');
        final nextFrontmatter = StringBuffer('---\n');
        nextFrontmatter.writeln('title: "${task.title}"');
        nextFrontmatter.writeln('due: "$yyyy-$mm-$dd"');
        nextFrontmatter.writeln('recurring: "${task.recurring}"');
        nextFrontmatter.writeln('done: false');
        nextFrontmatter.writeln('---\n');
        await nextFile.writeAsString(nextFrontmatter.toString() + task.content.trim());
      }
    }
    setState(() {});
  }

  DateTime? _nextRecurrenceDate(String due, String recurring, {bool isFirstInstance = false}) {
    final base = _parseDueDate(due);
    if (base == null) return null;
    final rec = recurring.trim().toLowerCase();
    if (isFirstInstance) {
      // For first instance, only skip today if recurrence is 'weekly on <weekday>' and today is not that weekday
      final weeklyOnMatch = RegExp(r'^weekly on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)",?').firstMatch(rec);
      if (weeklyOnMatch != null) {
        final weekdayStr = weeklyOnMatch.group(1)!;
        final weekdayMap = {
          'monday': 1,
          'tuesday': 2,
          'wednesday': 3,
          'thursday': 4,
          'friday': 5,
          'saturday': 6,
          'sunday': 7,
        };
        final targetWeekday = weekdayMap[weekdayStr];
        if (targetWeekday != null && base.weekday != targetWeekday) {
          // Not today, so next occurrence is the next target weekday
          final daysToAdd = (targetWeekday - base.weekday + 7) % 7;
          return base.add(Duration(days: daysToAdd == 0 ? 7 : daysToAdd));
        }
        // If today is the target weekday, first instance is today
        return base;
      }
      // For all other recurrence types, first instance is today
      return base;
    }
    switch (rec) {
      case 'daily':
        return base.add(const Duration(days: 1));
      case 'weekly':
        return base.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(base.year, base.month + 1, base.day);
      case 'yearly':
        return DateTime(base.year + 1, base.month, base.day);
      default:
        // Support for 'weekly on <weekday>'
        final weeklyOnMatch = RegExp(r'^weekly on (monday|tuesday|wednesday|thursday|friday|saturday|sunday)",?').firstMatch(rec);
        if (weeklyOnMatch != null) {
          final weekdayStr = weeklyOnMatch.group(1)!;
          final weekdayMap = {
            'monday': 1,
            'tuesday': 2,
            'wednesday': 3,
            'thursday': 4,
            'friday': 5,
            'saturday': 6,
            'sunday': 7,
          };
          final targetWeekday = weekdayMap[weekdayStr];
          if (targetWeekday != null) {
            final daysToAdd = (targetWeekday - base.weekday + 7) % 7;
            return base.add(Duration(days: daysToAdd == 0 ? 7 : daysToAdd));
          }
        }
        return null;
    }
  }

  // Helper to parse a Task from a file, fallback to manual parsing if needed
  Future<Task?> _parseTaskFromFile(File file) async {
    try {
      final task = await Task.fromFile(file);
      if (task != null) return task;
      final text = await file.readAsString();
      final dueMatch = RegExp(r'''due:\s*["']?(\d{4}[-/]?\d{2}[-/]?\d{2})["']?''', caseSensitive: false).firstMatch(text);
      final titleMatch = RegExp(r'''title:\s*["']?([^\n\r"']+)["']?''', caseSensitive: false).firstMatch(text);
      final recurringMatch = RegExp(r'''recurring:\s*["']?([^\n\r"']+)["']?''', caseSensitive: false).firstMatch(text);
      final doneMatch = RegExp(r'''done:\s*(true|false)''', caseSensitive: false).firstMatch(text);
      final due = dueMatch?.group(1);
      final title = titleMatch != null ? titleMatch.group(1)!.trim() : file.uri.pathSegments.last;
      final recurring = recurringMatch?.group(1);
      final done = doneMatch != null ? doneMatch.group(1) == 'true' : false;
      return Task(
        title: title,
        dueDate: due,
        done: done,
        filePath: file.path,
        content: text,
        recurring: recurring,
      );
    } catch (_) {
      return null;
    }
  }

  // Helper to check if a task is for today
  bool _isTaskForToday(Task task) {
    if (task.done || task.dueDate == null || task.dueDate!.isEmpty) return false;
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final match = RegExp(r'^(\d{4})[-/]?(\d{2})[-/]?(\d{2})').firstMatch(task.dueDate!);
    return match != null && match.group(1) == yyyy && match.group(2) == mm && match.group(3) == dd;
  }

  // Helper to check if a task is upcoming (future due date)
  bool _isTaskUpcoming(Task task) {
    if (task.done || task.dueDate == null || task.dueDate!.isEmpty) return false;
    final dueDate = _parseDueDate(task.dueDate!);
    final now = DateTime.now();
    return dueDate != null && dueDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  // Load Inbox tasks
  Future<List<Task>> _loadInboxTasks() async {
    final inboxDir = Directory('${widget.vaultPath}/inbox');
    if (!await inboxDir.exists()) return [];
    final files = await inboxDir.list().where((e) => e is File && e.path.endsWith('.md')).toList();
    final tasks = <Task>[];
    for (final entity in files) {
      final file = entity as File;
      final task = await _parseTaskFromFile(file);
      if (task != null && !task.done && task.dueDate != null && _isTaskUpcoming(task)) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  // Load Today tasks
  Future<List<Task>> _loadTodayTasks() async {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final todayDir = Directory('${widget.vaultPath}/by-date/$yyyy/$mm/$dd');
    if (!await todayDir.exists()) return [];
    final files = await todayDir.list().where((e) => e is File && e.path.endsWith('.md')).toList();
    final tasks = <Task>[];
    for (final entity in files) {
      final file = entity as File;
      final task = await _parseTaskFromFile(file);
      if (task != null && !task.done && _isTaskForToday(task)) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  // Load Completed tasks
  Future<List<Task>> _loadCompletedTasks() async {
    final doneDir = Directory('${widget.vaultPath}/done');
    if (!await doneDir.exists()) return [];
    final files = await doneDir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final tasks = <Task>[];
    for (final file in files.take(20)) {
      final task = await _parseTaskFromFile(file);
      if (task != null && task.done) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  // Main loader
  Future<List<Task>> _loadTasks() async {
    if (widget.view == 'Inbox') {
      return _loadInboxTasks();
    } else if (widget.view == 'Today') {
      return _loadTodayTasks();
    } else if (widget.view == 'Upcoming') {
      return [];
    } else if (widget.view == 'Completed') {
      return _loadCompletedTasks();
    }
    return [];
  }

  // Helper to parse a due date string into a DateTime
  DateTime? _parseDueDate(String due) {
    final match = RegExp(r'^(\d{4})[-/]?(\d{2})[-/]?(\d{2})').firstMatch(due);
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  Future<void> _confirmDeleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await File(task.filePath).delete();
      } catch (_) {}
      setState(() {});
    }
  }
}