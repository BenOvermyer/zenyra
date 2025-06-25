import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TaskCreateDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialDue;
  final String? initialContent;
  final String? initialRecurring;
  const TaskCreateDialog({this.initialTitle, this.initialDue, this.initialContent, this.initialRecurring, super.key});

  @override
  State<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<TaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _dueController;
  late TextEditingController _contentController;
  late TextEditingController _recurringController;
  late FocusNode _titleFocusNode;
  bool _tabCompleteActive = false;
  int? _lastAtIdx;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _dueController = TextEditingController(text: widget.initialDue ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _recurringController = TextEditingController(text: widget.initialRecurring ?? '');
    _titleFocusNode = FocusNode(onKeyEvent: (node, event) {
      final text = _titleController.text;
      final selection = _titleController.selection;
      final cursor = selection.baseOffset;
      final patterns = ['@today', '@tomorrow'];
      // Find the last @ before the cursor
      final atIdx = text.lastIndexOf('@', cursor - 1);
      String? matchPattern;
      if (atIdx != -1 && cursor > atIdx) {
        for (final p in patterns) {
          final partial = text.substring(atIdx, cursor);
          if (p.startsWith(partial) && partial.length > 2) {
            matchPattern = p;
            break;
          }
        }
      }
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
        if (matchPattern != null) {
          final newText = text.substring(0, atIdx) + matchPattern + text.substring(cursor);
          _titleController.text = newText;
          _titleController.selection = TextSelection.collapsed(offset: atIdx + matchPattern.length);
          _tabCompleteActive = true;
          _lastAtIdx = atIdx;
          return KeyEventResult.handled;
        }
        if (_tabCompleteActive) {
          // After tab-complete, allow normal tab
          _tabCompleteActive = false;
          _lastAtIdx = null;
          return KeyEventResult.ignored;
        }
      }
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        if (_tabCompleteActive && _lastAtIdx != null) {
          // Remove the @today/@tomorrow string
          final text = _titleController.text;
          final atIdx = _lastAtIdx!;
          final after = text.indexOf(' ', atIdx);
          final end = after == -1 ? text.length : after;
          final newText = text.substring(0, atIdx) + text.substring(end);
          _titleController.text = newText.trimLeft();
          _titleController.selection = TextSelection.collapsed(offset: atIdx);
          _tabCompleteActive = false;
          _lastAtIdx = null;
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    });
  }

  Map<String, String> _buildResult() {
    String title = _titleController.text.trim();
    String due = _dueController.text.trim();
    final now = DateTime.now();
    if (title.contains('@today')) {
      title = title.replaceAll('@today', '').trim();
      due = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } else if (title.contains('@tomorrow')) {
      title = title.replaceAll('@tomorrow', '').trim();
      final tomorrow = now.add(const Duration(days: 1));
      due = '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    }
    return {
      'title': title,
      'due': due,
      'content': _contentController.text.trim(),
      'recurring': _recurringController.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTitle == null ? 'Create Task' : 'Edit Task'),
      content: Form(
        key: _formKey,
        child: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (intent) {
                  if (_formKey.currentState!.validate()) {
                    Navigator.of(context).pop(_buildResult());
                  }
                  return null;
                },
              ),
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Replace the TextFormField for title with a Stack for overlay highlighting and tab-completion
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _titleController,
                        builder: (context, value, child) {
                          final text = value.text;
                          final spans = <TextSpan>[];
                          int i = 0;
                          final patterns = ['@today', '@tomorrow'];
                          while (i < text.length) {
                            final atIdx = text.indexOf('@', i);
                            if (atIdx == -1) {
                              spans.add(TextSpan(text: text.substring(i)));
                              break;
                            }
                            if (atIdx > i) {
                              spans.add(TextSpan(text: text.substring(i, atIdx)));
                            }
                            // Find the longest match for any pattern
                            int maxMatchLen = 0;
                            for (final p in patterns) {
                              for (int len = p.length; len > 2; len--) {
                                if (text.length >= atIdx + len && text.substring(atIdx, atIdx + len) == p.substring(0, len)) {
                                  if (len > maxMatchLen) maxMatchLen = len;
                                }
                              }
                            }
                            if (maxMatchLen > 0) {
                              spans.add(TextSpan(text: text.substring(atIdx, atIdx + maxMatchLen), style: const TextStyle(color: Colors.purple)));
                              i = atIdx + maxMatchLen;
                            } else {
                              spans.add(TextSpan(text: text.substring(atIdx, atIdx + 1)));
                              i = atIdx + 1;
                            }
                          }
                          return IgnorePointer(
                            child: RichText(
                              text: TextSpan(style: Theme.of(context).textTheme.bodyLarge, children: spans),
                            ),
                          );
                        },
                      ),
                      // Remove the outer Focus widget, just use the TextFormField with custom FocusNode
                      TextFormField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                        autofocus: true,
                        style: const TextStyle(color: Colors.transparent, height: 1),
                        cursorColor: Colors.black,
                        enableSuggestions: false,
                        autocorrect: false,
                        onFieldSubmitted: (_) {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop(_buildResult());
                          }
                        },
                      ),
                    ],
                  ),
                  // Due Date field with date picker
                  GestureDetector(
                    onTap: () async {
                      final initialDate = _dueController.text.isNotEmpty
                          ? DateTime.tryParse(_dueController.text) ?? DateTime.now()
                          : DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        setState(() {
                          _dueController.text = formatted;
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dueController,
                        decoration: const InputDecoration(labelText: 'Due Date (YYYY-MM-DD)'),
                        readOnly: true,
                      ),
                    ),
                  ),
                  // Recurrence field
                  TextFormField(
                    controller: _recurringController,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence (e.g. daily, weekly, every other Tuesday)',
                      hintText: 'Leave blank for non-recurring',
                    ),
                  ),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    enableSuggestions: true,
                    autocorrect: true,
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState!.validate()) {
                        Navigator.of(context).pop(_buildResult());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_buildResult());
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
  @override
  void dispose() {
    _titleController.dispose();
    _dueController.dispose();
    _contentController.dispose();
    _recurringController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }
}
