import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/recurrence_label.dart';
import '../models/task_model.dart';
import '../task_create_dialog.dart';
import '../logic/task_list_logic.dart';
import '../widgets/task_list_widget.dart';
import 'task_list_upcoming_view.dart';
import 'task_list_today_view.dart';
import 'task_list_inbox_view.dart';
import 'task_list_recurring_view.dart';

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
      return TaskListUpcomingView(
        vaultPath: widget.vaultPath,
        textTheme: textTheme,
        onMarkDone: _markTaskDone,
        onEdit: _editTask,
        onDelete: _confirmDeleteTask,
        reorderable: false,
      );
    }
    if (widget.view == 'Today') {
      final now = DateTime.now();
      final yyyy = now.year.toString().padLeft(4, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final todayDirPath = '${widget.vaultPath}/by-date/$yyyy/$mm/$dd';
      return TaskListTodayView(
        vaultPath: widget.vaultPath,
        textTheme: textTheme,
        onMarkDone: _markTaskDone,
        onEdit: _editTask,
        onDelete: _confirmDeleteTask,
        reorderable: true,
        onReorder: (tasks, oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = tasks.removeAt(oldIndex);
            tasks.insert(newIndex, item);
          });
          await TaskListLogic.saveOrder(tasks, todayDirPath);
        },
      );
    }
    if (widget.view == 'Inbox') {
      return TaskListInboxView(
        vaultPath: widget.vaultPath,
        textTheme: textTheme,
        onMarkDone: _markTaskDone,
        onEdit: _editTask,
        onDelete: _confirmDeleteTask,
        reorderable: true,
        onReorder: (tasks, oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = tasks.removeAt(oldIndex);
            tasks.insert(newIndex, item);
          });
          await TaskListLogic.saveOrder(tasks, '${widget.vaultPath}/inbox');
        },
      );
    }
    if (widget.view == 'Recurring') {
      return TaskListRecurringView(
        vaultPath: widget.vaultPath,
        textTheme: textTheme,
        onMarkDone: _markTaskDone,
        onEdit: _editTask,
        onDelete: _confirmDeleteTask,
        onAutoCreateInstances: (tasks) async {
          // Move the recurring instance creation logic here
          bool created = false;
          for (final task in tasks) {
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