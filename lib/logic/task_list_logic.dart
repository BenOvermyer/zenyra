import 'dart:io';
import '../models/upcoming_list_item.dart';
import '../task_model.dart';

/// Provides static methods for loading, parsing, and organizing tasks from the Vault.
class TaskListLogic {
  /// Parses a due date string (YYYY-MM-DD or YYYY/MM/DD) into a DateTime.
  static DateTime? parseDueDate(String due) {
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

  /// Parses a Task from a file, falling back to manual parsing if needed.
  static Future<Task?> parseTaskFromFile(File file) async {
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

  /// Returns true if the task is for today and not done.
  static bool isTaskForToday(Task task) {
    if (task.done || task.dueDate == null || task.dueDate!.isEmpty) return false;
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final match = RegExp(r'^(\d{4})[-/]?(\d{2})[-/]?(\d{2})').firstMatch(task.dueDate!);
    return match != null && match.group(1) == yyyy && match.group(2) == mm && match.group(3) == dd;
  }

  /// Returns true if the task is upcoming (future due date) and not done.
  static bool isTaskUpcoming(Task task) {
    if (task.done || task.dueDate == null || task.dueDate!.isEmpty) return false;
    final dueDate = parseDueDate(task.dueDate!);
    final now = DateTime.now();
    return dueDate != null && dueDate.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// Groups tasks by due date and returns a list of UpcomingListItem for display.
  static List<UpcomingListItem> groupTasksByDueDate(List<Task> tasks) {
    final Map<String, List<Task>> grouped = {};
    for (final task in tasks) {
      final date = parseDueDate(task.dueDate ?? '') ?? DateTime(9999);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(task);
    }
    final List<UpcomingListItem> upcomingItems = [];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    for (final key in sortedKeys) {
      final date = parseDueDate(key)!;
      upcomingItems.add(UpcomingListItem.header(date));
      for (final task in grouped[key]!) {
        upcomingItems.add(UpcomingListItem.task(task));
      }
    }
    return upcomingItems;
  }

  /// Loads inbox tasks from the Vault's inbox directory.
  static Future<List<Task>> loadInboxTasks(String vaultPath) async {
    final inboxDir = Directory('$vaultPath/inbox');
    if (!await inboxDir.exists()) return [];
    final files = await inboxDir.list().where((e) => e is File && e.path.endsWith('.md')).toList();
    final tasks = <Task>[];
    for (final entity in files) {
      final file = entity as File;
      final task = await parseTaskFromFile(file);
      if (task != null && !task.done && task.dueDate != null && isTaskUpcoming(task)) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  /// Loads today's tasks from the Vault's by-date directory.
  static Future<List<Task>> loadTodayTasks(String vaultPath) async {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final todayDir = Directory('$vaultPath/by-date/$yyyy/$mm/$dd');
    if (!await todayDir.exists()) return [];
    final files = await todayDir.list().where((e) => e is File && e.path.endsWith('.md')).toList();
    final tasks = <Task>[];
    for (final entity in files) {
      final file = entity as File;
      final task = await parseTaskFromFile(file);
      if (task != null && !task.done && isTaskForToday(task)) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  /// Loads completed tasks from the Vault's done directory (most recent 20).
  static Future<List<Task>> loadCompletedTasks(String vaultPath) async {
    final doneDir = Directory('$vaultPath/done');
    if (!await doneDir.exists()) return [];
    final files = await doneDir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final tasks = <Task>[];
    for (final file in files.take(20)) {
      final task = await parseTaskFromFile(file);
      if (task != null && task.done) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  /// Loads tasks from a directory, preserving the order in .order if present.
  static Future<List<Task>> loadTasksWithOrder(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final files = await dir.list().where((e) => e is File && e.path.endsWith('.md')).cast<File>().toList();
    final orderFile = File('${dir.path}/.order');
    List<String> order = [];
    if (await orderFile.exists()) {
      order = (await orderFile.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
    }
    final tasks = <Task>[];
    final unordered = <Task>[];
    for (final file in files) {
      final task = await Task.fromFile(file);
      if (task != null) {
        if (order.contains(file.uri.pathSegments.last)) {
          tasks.add(task);
        } else {
          unordered.add(task);
        }
      }
    }
    tasks.sort((a, b) => order.indexOf(a.filePath.split('/').last).compareTo(order.indexOf(b.filePath.split('/').last)));
    tasks.addAll(unordered);
    return tasks;
  }

  /// Saves the order of tasks to a .order file in the directory.
  static Future<void> saveOrder(List<Task> tasks, String dirPath) async {
    final orderFile = File('$dirPath/.order');
    final lines = tasks.map((t) => t.filePath.split('/').last).toList();
    await orderFile.writeAsString(lines.join('\n'));
  }

  /// Loads overdue tasks from the Vault's by-date directory.
  static Future<List<Task>> loadOverdueTasks(String vaultPath) async {
    final now = DateTime.now();
    final byDateDir = Directory('$vaultPath/by-date');
    final overdueTasks = <Task>[];
    if (await byDateDir.exists()) {
      await for (final entity in byDateDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          try {
            final task = await Task.fromFile(entity);
            if (task != null && !task.done && task.dueDate != null && task.dueDate!.isNotEmpty) {
              final due = parseDueDate(task.dueDate!);
              if (due != null && due.isBefore(DateTime(now.year, now.month, now.day))) {
                overdueTasks.add(task);
                continue;
              }
            }
          } catch (_) {}
        }
      }
    }
    overdueTasks.sort((a, b) {
      final aDate = parseDueDate(a.dueDate ?? '') ?? DateTime(9999);
      final bDate = parseDueDate(b.dueDate ?? '') ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return overdueTasks;
  }

  /// Loads recurring tasks from the Vault's by-date and inbox directories.
  static Future<List<Task>> loadRecurringTasks(String vaultPath) async {
    final List<Task> recurringTasks = [];
    final dirs = [
      Directory('$vaultPath/by-date'),
      Directory('$vaultPath/inbox'),
    ];
    for (final dir in dirs) {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.md')) {
            try {
              final task = await Task.fromFile(entity);
              if (task != null && task.recurring != null && task.recurring!.isNotEmpty) {
                recurringTasks.add(task);
              }
            } catch (_) {}
          }
        }
      }
    }
    recurringTasks.sort((a, b) {
      final aDate = parseDueDate(a.dueDate ?? '') ?? DateTime(9999);
      final bDate = parseDueDate(b.dueDate ?? '') ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return recurringTasks;
  }

  /// Loads upcoming items (wrapper for UI)
  static Future<List<UpcomingListItem>> loadUpcomingItems(String vaultPath) async {
    final byDateDir = Directory('$vaultPath/by-date');
    if (!await byDateDir.exists()) return [];
    final now = DateTime.now();
    final tasks = <Task>[];
    await for (final entity in byDateDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        try {
          final task = await Task.fromFile(entity);
          if (task != null && !task.done && task.dueDate != null && task.dueDate!.isNotEmpty) {
            final due = parseDueDate(task.dueDate!);
            if (due != null && due.isAfter(DateTime(now.year, now.month, now.day))) {
              tasks.add(task);
              continue;
            }
          }
          if (task == null) {
            final text = await entity.readAsString();
            final dueMatch = RegExp(r'''due:\s*["']?(\d{4}[-/]?\d{2}[-/]?\d{2})["']?''', caseSensitive: false).firstMatch(text);
            final titleMatch = RegExp(r'''title:\s*["']?([^\n\r"']+)["']?''', caseSensitive: false).firstMatch(text);
            final recurringMatch = RegExp(r'''recurring:\s*["']?([^\n\r"']+)["']?''', caseSensitive: false).firstMatch(text);
            final doneMatch = RegExp(r'''done:\s*(true|false)''', caseSensitive: false).firstMatch(text);
            final due = dueMatch?.group(1);
            final title = titleMatch != null ? titleMatch.group(1)!.trim() : entity.uri.pathSegments.last;
            final recurring = recurringMatch?.group(1);
            final done = doneMatch != null ? doneMatch.group(1) == 'true' : false;
            if (!done && due != null && due.isNotEmpty) {
              final dueDate = parseDueDate(due);
              if (dueDate != null && dueDate.isAfter(DateTime(now.year, now.month, now.day))) {
                tasks.add(Task(
                  title: title,
                  dueDate: due,
                  done: done,
                  filePath: entity.path,
                  content: text,
                  recurring: recurring,
                ));
              }
            }
          }
        } catch (_) {}
      }
    }
    // Sort by due date ascending
    tasks.sort((a, b) {
      final aDate = parseDueDate(a.dueDate ?? '') ?? DateTime(9999);
      final bDate = parseDueDate(b.dueDate ?? '') ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return groupTasksByDueDate(tasks);
  }
}
