import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../db/database_helper.dart';
import '../services/notification_service.dart';

class TaskProvider with ChangeNotifier {
  Map<String, List<Task>> _tasksCache = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  List<Task> get tasks => _tasksCache[_getDateKey(_selectedDate)] ?? [];
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  List<Task> getTasksFor(DateTime date) {
    return _tasksCache[_getDateKey(date)] ?? [];
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadTasksForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> loadTasksForDate(DateTime date) async {
    final key = _getDateKey(date);
    if (_tasksCache.containsKey(key)) return;

    _isLoading = true;
    notifyListeners();

    try {
      final fetchedTasks = await DatabaseHelper.instance.readTasksByDate(date);
      _tasksCache[key] = fetchedTasks;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading tasks: $e');
      }
      _tasksCache[key] = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(Task task) async {
    Task taskToSave = task;
    if (task.recurrence != RecurrenceType.none && task.seriesId == null) {
      taskToSave = task.copyWith(seriesId: task.id);
    }

    await DatabaseHelper.instance.createTask(taskToSave);
    await NotificationService.instance.scheduleTaskNotification(taskToSave);

    final key = _getDateKey(taskToSave.date);

    if (_tasksCache.containsKey(key)) {
      _tasksCache[key]!.add(taskToSave);
      _sortTasks(key);
      notifyListeners();
    }

    if (taskToSave.recurrence != RecurrenceType.none) {
      await _generateRecurringTasks(taskToSave);
    }
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    Task taskToUpdate = task;
    if (task.recurrence != RecurrenceType.none && task.seriesId == null) {
      taskToUpdate = task.copyWith(seriesId: task.id);
    }

    await DatabaseHelper.instance.updateTask(taskToUpdate);
    await NotificationService.instance.scheduleTaskNotification(taskToUpdate);

    _removeFromCache(taskToUpdate.id);

    final newKey = _getDateKey(taskToUpdate.date);
    if (_tasksCache.containsKey(newKey)) {
      _tasksCache[newKey]!.add(taskToUpdate);
      _sortTasks(newKey);
    }

    // Only regenerate the series if recurrence is newly enabled on this task (seriesId was null).
    // Updating a single instance or toggling isDone should not trigger series regeneration.
    if (taskToUpdate.recurrence != RecurrenceType.none &&
        task.seriesId == null) {
      await _generateRecurringTasks(taskToUpdate);
    }

    notifyListeners();
  }

  Future<void> _generateRecurringTasks(Task task) async {
    final seriesId = task.seriesId ?? task.id;

    // Optimization: filter tasks first to avoid unnecessary work in the loop.
    final allTasks = await DatabaseHelper.instance.readAllTasks();
    final tasksToDelete = allTasks
        .where((t) => t.seriesId == seriesId && t.date.isAfter(task.date))
        .toList();

    for (final t in tasksToDelete) {
      await DatabaseHelper.instance.deleteTask(t.id);
      _removeFromCache(t.id);
    }

    DateTime nextDate = task.date;
    int iterations = 0;
    if (task.recurrence == RecurrenceType.daily) iterations = 30;
    if (task.recurrence == RecurrenceType.weekly) iterations = 12;
    if (task.recurrence == RecurrenceType.monthly) iterations = 6;

    for (int i = 0; i < iterations; i++) {
      switch (task.recurrence) {
        case RecurrenceType.daily:
          nextDate = nextDate.add(const Duration(days: 1));
          break;
        case RecurrenceType.weekly:
          nextDate = nextDate.add(const Duration(days: 7));
          break;
        case RecurrenceType.monthly:
          int nextMonth = nextDate.month + 1;
          int nextYear = nextDate.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          nextDate = DateTime(nextYear, nextMonth, nextDate.day);
          break;
        default:
          break;
      }

      final newStartTime = task.startTime != null
          ? DateTime(
              nextDate.year,
              nextDate.month,
              nextDate.day,
              task.startTime!.hour,
              task.startTime!.minute,
            )
          : null;
      final newEndTime = task.endTime != null
          ? DateTime(
              nextDate.year,
              nextDate.month,
              nextDate.day,
              task.endTime!.hour,
              task.endTime!.minute,
            )
          : null;

      final newTask = Task(
        title: task.title,
        description: task.description,
        date: nextDate,
        startTime: newStartTime,
        endTime: newEndTime,
        isDone: false,
        recurrence: RecurrenceType.none,
        colorValue: task.colorValue,
        subtasks: [],
        seriesId: seriesId,
        iconCodePoint: task.iconCodePoint,
        reminders: task.reminders,
      );

      newTask.subtasks = task.subtasks
          .map(
            (s) => Subtask(title: s.title, isDone: false, taskId: newTask.id),
          )
          .toList();

      await DatabaseHelper.instance.createTask(newTask);
      await NotificationService.instance.scheduleTaskNotification(newTask);

      final newKey = _getDateKey(nextDate);
      if (_tasksCache.containsKey(newKey)) {
        _tasksCache[newKey]!.add(newTask);
        _sortTasks(newKey);
      }
    }
  }

  Future<void> deleteTask(String id) async {
    // Attempt to cancel notification if task exists in cache or needs to be fetched
    // For simplicity, we create a dummy task with the same ID for cancellation
    await NotificationService.instance.cancelTaskNotification(
      Task(id: id, title: '', date: DateTime.now()),
    );

    await DatabaseHelper.instance.deleteTask(id);
    _removeFromCache(id);
    notifyListeners();
  }

  Future<void> deleteSeries(
    String seriesId, {
    bool all = true,
    DateTime? futureFrom,
  }) async {
    final allTasks = await DatabaseHelper.instance.readAllTasks();
    final tasksToDelete = allTasks.where((t) {
      if (t.seriesId != seriesId) return false;
      if (all) return true;
      if (futureFrom != null) {
        return t.date.isAtSameMomentAs(futureFrom) ||
            t.date.isAfter(futureFrom);
      }
      return false;
    });

    for (final task in tasksToDelete) {
      await deleteTask(task.id);
    }
  }

  Future<void> updateSeries(
    Task updatedTask, {
    bool all = true,
    DateTime? futureFrom,
  }) async {
    final seriesId = updatedTask.seriesId!;
    final allTasks = await DatabaseHelper.instance.readAllTasks();
    final tasksToUpdate = allTasks.where((t) {
      if (t.seriesId != seriesId) return false;
      if (all) return true;
      if (futureFrom != null) {
        return t.date.isAtSameMomentAs(futureFrom) ||
            t.date.isAfter(futureFrom);
      }
      return false;
    }).toList();

    for (final task in tasksToUpdate) {
      DateTime? newStartTime;
      DateTime? newEndTime;

      if (updatedTask.startTime != null) {
        newStartTime = DateTime(
          task.date.year,
          task.date.month,
          task.date.day,
          updatedTask.startTime!.hour,
          updatedTask.startTime!.minute,
        );
      }

      if (updatedTask.endTime != null) {
        newEndTime = DateTime(
          task.date.year,
          task.date.month,
          task.date.day,
          updatedTask.endTime!.hour,
          updatedTask.endTime!.minute,
        );
      }

      final newTask = task.copyWith(
        title: updatedTask.title,
        description: updatedTask.description,
        colorValue: updatedTask.colorValue,
        iconCodePoint: updatedTask.iconCodePoint,
        // If updating "This & Future", the updated instance might carry the recurrence change
        recurrence: (task.id == updatedTask.id)
            ? updatedTask.recurrence
            : RecurrenceType.none,
        startTime: newStartTime,
        endTime: newEndTime,
        reminders: updatedTask.reminders,
        subtasks: updatedTask.subtasks
            .map((s) => Subtask(title: s.title, taskId: task.id))
            .toList(),
      );

      await DatabaseHelper.instance.updateTask(newTask);
      await NotificationService.instance.scheduleTaskNotification(newTask);

      _removeFromCache(newTask.id);

      final newKey = _getDateKey(newTask.date);
      if (_tasksCache.containsKey(newKey)) {
        _tasksCache[newKey]!.add(newTask);
        _sortTasks(newKey);
      }
    }

    // If the recurrence type was changed on the pivot task, trigger regeneration
    if (updatedTask.recurrence != RecurrenceType.none) {
      await _generateRecurringTasks(updatedTask);
    }

    notifyListeners();
  }

  void clearCache() {
    _tasksCache.clear();
    notifyListeners();
  }

  Future<void> toggleSubtask(Task task, Subtask subtask) async {
    final updatedSubtask = subtask.copyWith(isDone: !subtask.isDone);
    await DatabaseHelper.instance.updateSubtask(updatedSubtask);

    final key = _getDateKey(task.date);
    if (_tasksCache.containsKey(key)) {
      final taskList = _tasksCache[key]!;
      final taskIndex = taskList.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        final subtaskIndex = taskList[taskIndex].subtasks.indexWhere(
          (s) => s.id == subtask.id,
        );
        if (subtaskIndex != -1) {
          taskList[taskIndex].subtasks[subtaskIndex] = updatedSubtask;
          notifyListeners();
        }
      }
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _sortTasks(String key) {
    if (_tasksCache.containsKey(key)) {
      _tasksCache[key]!.sort((a, b) {
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return a.startTime!.compareTo(b.startTime!);
      });
    }
  }

  void _removeFromCache(String taskId) {
    _tasksCache.forEach((key, list) {
      list.removeWhere((t) => t.id == taskId);
    });
  }
}
