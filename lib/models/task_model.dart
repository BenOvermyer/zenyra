import 'dart:io';
import 'package:yaml/yaml.dart';

class Task {
  final String title;
  final String? dueDate;
  final bool done;
  final String filePath;
  final String content;
  final String? recurring;

  Task({
    required this.title,
    this.dueDate,
    required this.done,
    required this.filePath,
    required this.content,
    this.recurring,
  });

  static Future<Task?> fromFile(File file) async {
    try {
      final text = await file.readAsString();
      final frontmatterMatch = RegExp(r'^---\s*([\s\S]*?)---\s*').firstMatch(text);
      if (frontmatterMatch == null) return null;
      final yamlStr = frontmatterMatch.group(1)!;
      final yamlMap = loadYaml(yamlStr);
      final title = yamlMap['title']?.toString() ?? file.uri.pathSegments.last;
      final dueDate = yamlMap['due']?.toString();
      final done = yamlMap['done'] == true || yamlMap['done'] == 'true';
      final recurring = yamlMap['recurring']?.toString();
      final content = text.substring(frontmatterMatch.end).trim();
      return Task(
        title: title,
        dueDate: dueDate,
        done: done,
        filePath: file.path,
        content: content,
        recurring: recurring,
      );
    } catch (e) {
      return null;
    }
  }
}
