import 'package:uuid/uuid.dart';

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
}

class Subtask {
  String id;
  String title;
  bool isDone;
  String taskId;

  Subtask({
    String? id,
    required this.title,
    this.isDone = false,
    required this.taskId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone ? 1 : 0,
      'taskId': taskId,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      title: map['title'],
      isDone: map['isDone'] == 1,
      taskId: map['taskId'],
    );
  }

  Subtask copyWith({
    String? id,
    String? title,
    bool? isDone,
    String? taskId,
  }) {
    return Subtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      taskId: taskId ?? this.taskId,
    );
  }
}

class Task {
  String id;
  String title;
  String description;
  DateTime date;
  DateTime? startTime;
  DateTime? endTime;
  bool isDone;
  RecurrenceType recurrence;
  List<Subtask> subtasks;
  int colorValue;
  String? seriesId;
  int? iconCodePoint;
  List<int> reminders;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.date,
    this.startTime,
    this.endTime,
    this.isDone = false,
    this.recurrence = RecurrenceType.none,
    this.subtasks = const [],
    this.colorValue = 0xFF2196F3,
    this.seriesId,
    this.iconCodePoint,
    this.reminders = const [],
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isDone': isDone ? 1 : 0,
      'recurrence': recurrence.index,
      'colorValue': colorValue,
      'seriesId': seriesId,
      'iconCodePoint': iconCodePoint,
      'reminders': reminders.join(','),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<int> remindersList = [];
    final remindersStr = map['reminders'] as String?;
    if (remindersStr != null && remindersStr.isNotEmpty) {
      remindersList = remindersStr.split(',').map((e) => int.parse(e)).toList();
    } else if (map['reminderMinutes'] != null) {
      // Migration from single reminderMinutes field
      remindersList = [map['reminderMinutes'] as int];
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      date: DateTime.parse(map['date']),
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      isDone: map['isDone'] == 1,
      recurrence: RecurrenceType.values[map['recurrence']],
      colorValue: map['colorValue'],
      seriesId: map['seriesId'],
      iconCodePoint: map['iconCodePoint'],
      reminders: remindersList,
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    bool? isDone,
    RecurrenceType? recurrence,
    List<Subtask>? subtasks,
    int? colorValue,
    String? seriesId,
    int? iconCodePoint,
    List<int>? reminders,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isDone: isDone ?? this.isDone,
      recurrence: recurrence ?? this.recurrence,
      subtasks: subtasks ?? this.subtasks,
      colorValue: colorValue ?? this.colorValue,
      seriesId: seriesId ?? this.seriesId,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      reminders: reminders ?? this.reminders,
    );
  }
}
