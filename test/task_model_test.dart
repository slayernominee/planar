import 'package:flutter_test/flutter_test.dart';
import 'package:planar/models/task.dart';

void main() {
  group('Task Model Tests', () {
    test('Task should be created with default values', () {
      final now = DateTime.now();
      final task = Task(title: 'Test Task', date: now);

      expect(task.title, 'Test Task');
      expect(task.date, now);
      expect(task.isDone, false);
      expect(task.recurrence, RecurrenceType.none);
      expect(task.subtasks, isEmpty);
      expect(task.id, isNotEmpty);
      expect(task.reminders, isEmpty);
    });

    test('Task toMap and fromMap should work correctly', () {
      final now = DateTime.now();
      // Ensure we don't have microseconds issues during serialization roundtrip
      final cleanNow = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );
      final startTime = cleanNow.add(const Duration(hours: 1));
      final endTime = cleanNow.add(const Duration(hours: 2));

      final task = Task(
        id: 'test_id',
        title: 'Test Task',
        description: 'Test Description',
        date: cleanNow,
        startTime: startTime,
        endTime: endTime,
        isDone: true,
        recurrence: RecurrenceType.weekly,
        colorValue: 0xFF0000FF,
        seriesId: 'series_1',
        iconCodePoint: 12345,
        reminders: [10, 30],
      );

      final map = task.toMap();

      expect(map['id'], 'test_id');
      expect(map['title'], 'Test Task');
      expect(map['description'], 'Test Description');
      expect(map['date'], cleanNow.toIso8601String());
      expect(map['startTime'], startTime.toIso8601String());
      expect(map['endTime'], endTime.toIso8601String());
      expect(map['isDone'], 1);
      expect(map['recurrence'], RecurrenceType.weekly.index);
      expect(map['colorValue'], 0xFF0000FF);
      expect(map['seriesId'], 'series_1');
      expect(map['iconCodePoint'], 12345);
      expect(map['reminders'], '10,30');

      final taskFromMap = Task.fromMap(map);

      expect(taskFromMap.id, task.id);
      expect(taskFromMap.title, task.title);
      expect(taskFromMap.description, task.description);
      expect(taskFromMap.date, task.date);
      expect(taskFromMap.startTime, task.startTime);
      expect(taskFromMap.endTime, task.endTime);
      expect(taskFromMap.isDone, task.isDone);
      expect(taskFromMap.recurrence, task.recurrence);
      expect(taskFromMap.colorValue, task.colorValue);
      expect(taskFromMap.seriesId, task.seriesId);
      expect(taskFromMap.iconCodePoint, task.iconCodePoint);
      expect(taskFromMap.reminders, [10, 30]);
    });

    test('Task fromMap should handle legacy reminderMinutes', () {
      final map = {
        'id': 'legacy_id',
        'title': 'Legacy Task',
        'date': DateTime.now().toIso8601String(),
        'isDone': 0,
        'recurrence': 0,
        'colorValue': 0xFF000000,
        'reminderMinutes': 15,
        // 'reminders' is missing (simulating old DB row)
      };

      final task = Task.fromMap(map);
      expect(task.reminders, [15]);
    });

    test('Task copyWith should update fields correctly', () {
      final task = Task(
        title: 'Original Title',
        date: DateTime.now(),
        isDone: false,
        reminders: [10],
      );

      final updatedTask = task.copyWith(
        title: 'New Title',
        isDone: true,
        reminders: [20, 60],
      );

      expect(updatedTask.title, 'New Title');
      expect(updatedTask.isDone, true);
      expect(updatedTask.reminders, [20, 60]);
      expect(updatedTask.date, task.date); // Should remain same
      expect(updatedTask.id, task.id); // Should remain same
    });
  });

  group('Subtask Model Tests', () {
    test('Subtask toMap and fromMap works', () {
      final subtask = Subtask(
        id: 'sub_1',
        title: 'Check item',
        isDone: true,
        taskId: 'parent_task',
      );

      final map = subtask.toMap();
      expect(map['id'], 'sub_1');
      expect(map['title'], 'Check item');
      expect(map['isDone'], 1);
      expect(map['taskId'], 'parent_task');

      final fromMap = Subtask.fromMap(map);
      expect(fromMap.id, subtask.id);
      expect(fromMap.title, subtask.title);
      expect(fromMap.isDone, subtask.isDone);
      expect(fromMap.taskId, subtask.taskId);
    });

    test('Subtask copyWith updates fields', () {
      final subtask = Subtask(title: 'Original', taskId: 'task_1');

      final updated = subtask.copyWith(title: 'Updated', isDone: true);
      expect(updated.title, 'Updated');
      expect(updated.isDone, true);
      expect(updated.id, subtask.id);
      expect(updated.taskId, subtask.taskId);
    });
  });
}
