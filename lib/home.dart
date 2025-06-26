import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'views/task_list_view.dart';
import 'settings_view.dart';
import 'task_create_dialog.dart';

class TodoHome extends StatefulWidget {
  final String vaultPath;
  const TodoHome({super.key, required this.vaultPath});

  @override
  State<TodoHome> createState() => _TodoHomeState();
}

class _TodoHomeState extends State<TodoHome> {
  String _selectedView = 'Inbox';
  final List<String> _views = ['Inbox', 'Today', 'Upcoming', 'Recurring', 'Completed', 'Settings'];
  final GlobalKey<TaskListViewState> _taskListViewKey = GlobalKey<TaskListViewState>();
  final FocusNode _focusNode = FocusNode();
  bool _dialogOpen = false;

  void _showCreateTaskDialog({String? due}) async {
    setState(() { _dialogOpen = true; });
    final result = await showDialog<Map<String, String?>> (
      context: context,
      builder: (context) => TaskCreateDialog(
        initialDue: due,
      ),
    );
    setState(() { _dialogOpen = false; });
    if (result != null) {
      await _createTask(
        result['title']!,
        result['due'],
        result['content'] ?? '',
        recurring: result['recurring'],
      );
      _taskListViewKey.currentState?.refresh();
    }
  }

  Future<void> _createTask(String title, String? due, String content, {String? recurring}) async {
    // If recurring is set, create a template if not exists, then generate the next occurrence
    if (recurring != null && recurring.trim().isNotEmpty) {
      final templateDir = Directory('${widget.vaultPath}/recurring');
      if (!await templateDir.exists()) await templateDir.create(recursive: true);
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final templateFile = File('${templateDir.path}/$safeTitle.md');
      if (!await templateFile.exists()) {
        final frontmatter = StringBuffer('---\n');
        frontmatter.writeln('title: "$title"');
        frontmatter.writeln('recurring: "$recurring"');
        frontmatter.writeln('---\n');
        await templateFile.writeAsString(frontmatter.toString() + content.trim());
      }
      // Generate the next occurrence as a normal task
      final nextDue = _nextRecurrenceDate(DateTime.now(), recurring);
      if (nextDue != null) {
        final yyyy = nextDue.year.toString().padLeft(4, '0');
        final mm = nextDue.month.toString().padLeft(2, '0');
        final dd = nextDue.day.toString().padLeft(2, '0');
        final folder = '${widget.vaultPath}/by-date/$yyyy/$mm/$dd';
        final dir = Directory(folder);
        if (!await dir.exists()) await dir.create(recursive: true);
        final filename = '$safeTitle-${DateTime.now().millisecondsSinceEpoch}.md';
        final file = File('${dir.path}/$filename');
        final frontmatter = StringBuffer('---\n');
        frontmatter.writeln('title: "$title"');
        frontmatter.writeln('due: "$yyyy-$mm-$dd"');
        frontmatter.writeln('recurring: "$recurring"');
        frontmatter.writeln('done: false');
        frontmatter.writeln('---\n');
        await file.writeAsString(frontmatter.toString() + content.trim());
      }
      return;
    }
    // ...existing code for non-recurring...
    String folder;
    String? normalizedDue;
    if (due != null && due.isNotEmpty) {
      final match = RegExp(r'^(\d{4})[-/]?(\d{2})[-/]?(\d{2})').firstMatch(due);
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
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = '$safeTitle-${DateTime.now().millisecondsSinceEpoch}.md';
    final file = File('${dir.path}/$filename');
    final frontmatter = StringBuffer('---\n');
    frontmatter.writeln('title: "$title"');
    if (normalizedDue != null) frontmatter.writeln('due: "$normalizedDue"');
    frontmatter.writeln('done: false');
    frontmatter.writeln('---\n');
    await file.writeAsString(frontmatter.toString() + content.trim());
  }

  DateTime? _nextRecurrenceDate(DateTime from, String recurring) {
    final lower = recurring.trim().toLowerCase();
    if (lower == 'daily') return from.add(const Duration(days: 1));
    if (lower == 'weekly') return from.add(const Duration(days: 7));
    if (lower == 'monthly') return DateTime(from.year, from.month + 1, from.day);
    if (lower == 'yearly') return DateTime(from.year + 1, from.month, from.day);
    // Example: every other tuesday
    final match = RegExp(r'every other (monday|tuesday|wednesday|thursday|friday|saturday|sunday)').firstMatch(lower);
    if (match != null) {
      final weekday = [
        'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
      ].indexOf(match.group(1)!);
      var next = from.add(const Duration(days: 1));
      while (next.weekday != weekday + 1) {
        next = next.add(const Duration(days: 1));
      }
      return next.add(const Duration(days: 7));
    }
    return null;
  }

  Future<void> _chooseNewVault() async {
    String? selected = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select or Create Vault Folder');
    if (selected != null) {
      await _ensureVaultStructure(selected);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vaultPath', selected);
      setState(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => TodoHome(vaultPath: selected)),
        );
      });
    }
  }

  Future<void> _ensureVaultStructure(String path) async {
    final folders = ['archive', 'done', 'inbox', 'recurring', 'by-date'];
    for (final folder in folders) {
      final dir = Directory('$path/$folder');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent && !_dialogOpen && event.logicalKey.keyLabel.toLowerCase() == 'q') {
          if (_selectedView == 'Today') {
            final now = DateTime.now();
            final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            _showCreateTaskDialog(due: today);
          } else {
            _showCreateTaskDialog();
          }
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _views.indexOf(_selectedView),
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedView = _views[index];
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                ..._views.take(_views.length - 1).map((view) {
                  IconData icon;
                  switch (view) {
                    case 'Inbox': icon = Icons.inbox; break;
                    case 'Today': icon = Icons.today; break;
                    case 'Upcoming': icon = Icons.calendar_today; break;
                    case 'Recurring': icon = Icons.repeat; break;
                    case 'Completed': icon = Icons.check_circle; break;
                    default: icon = Icons.circle;
                  }
                  return NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(view),
                  );
                }),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _selectedView == 'Settings'
                  ? SettingsView(onChooseVault: _chooseNewVault, currentVault: widget.vaultPath)
                  : TaskListView(
                      key: _taskListViewKey,
                      vaultPath: widget.vaultPath,
                      view: _selectedView,
                    ),
            ),
          ],
        ),
        floatingActionButton: _selectedView != 'Completed' && _selectedView != 'Settings'
            ? FloatingActionButton(
                onPressed: _showCreateTaskDialog,
                tooltip: 'Create Task',
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}
