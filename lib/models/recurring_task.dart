import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'task.dart';

class RecurringTask {
  String id;
  String title;
  String description;
  RecurrenceType recurrence;
  DateTime startDate;
  DateTime? startTime;
  DateTime? endTime;
  int colorValue;
  int? iconCodePoint;
  List<int> reminders;
  List<String> subtasks; // List of subtask titles to be applied to generated tasks
  DateTime? lastGeneratedDate;

  RecurringTask({
    String? id,
    required this.title,
    this.description = '',
    required this.recurrence,
    required this.startDate,
    this.startTime,
    this.endTime,
    this.colorValue = 0xFF2196F3,
    this.iconCodePoint,
    this.reminders = const [],
    this.subtasks = const [],
    this.lastGeneratedDate,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'recurrence': recurrence.index,
      'startDate': startDate.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'reminders': reminders.join(','),
      'subtasks': jsonEncode(subtasks),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
    };
  }

  factory RecurringTask.fromMap(Map<String, dynamic> map) {
    List<int> remindersList = [];
    final remindersStr = map['reminders'] as String?;
    if (remindersStr != null && remindersStr.isNotEmpty) {
      remindersList = remindersStr.split(',').map((e) => int.parse(e)).toList();
    }

    List<String> subtasksList = [];
    final subtasksStr = map['subtasks'] as String?;
    if (subtasksStr != null && subtasksStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(subtasksStr);
        if (decoded is List) {
          subtasksList = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // Handle legacy or invalid format if necessary
      }
    }

    return RecurringTask(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      recurrence: RecurrenceType.values[map['recurrence']],
      startDate: DateTime.parse(map['startDate']),
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      colorValue: map['colorValue'],
      iconCodePoint: map['iconCodePoint'],
      reminders: remindersList,
      subtasks: subtasksList,
      lastGeneratedDate: map['lastGeneratedDate'] != null
          ? DateTime.parse(map['lastGeneratedDate'])
          : null,
    );
  }

  RecurringTask copyWith({
    String? id,
    String? title,
    String? description,
    RecurrenceType? recurrence,
    DateTime? startDate,
    DateTime? startTime,
    DateTime? endTime,
    int? colorValue,
    int? iconCodePoint,
    List<int>? reminders,
    List<String>? subtasks,
    DateTime? lastGeneratedDate,
  }) {
    return RecurringTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      recurrence: recurrence ?? this.recurrence,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      reminders: reminders ?? this.reminders,
      subtasks: subtasks ?? this.subtasks,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
    );
  }
}
