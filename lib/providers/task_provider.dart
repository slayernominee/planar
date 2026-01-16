import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/recurring_task.dart';
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

  Future<void> loadTasksForDate(DateTime date, {bool force = false}) async {
    // Normalize date to midnight to ensure consistent querying and caching
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final key = _getDateKey(normalizedDate);

    // We clear cache for the date to force reload because recurring rules might have changed
    // or we can just proceed. For now, we trust the cache key logic, but
    // since we have dynamic generation, checking cache existence is safer.
    if (!force && _tasksCache.containsKey(key)) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch concrete tasks (regular + exceptions) for this specific date
      final concreteTasks = await DatabaseHelper.instance.readTasksByDate(normalizedDate);
      if (kDebugMode) {
        print('TaskProvider: Loaded ${concreteTasks.length} concrete tasks for $normalizedDate');
        for (var t in concreteTasks) {
          print('  - Concrete: ${t.title} (ID: ${t.id}, RecID: ${t.recurringTaskId}, Del: ${t.isDeleted})');
        }
      }

      // 2. Fetch all recurring rules
      final recurringRules = await DatabaseHelper.instance.readAllRecurringTasks();

      final List<Task> displayedTasks = [];
      final Set<String> processedRecurringIds = {};

      // Map concrete tasks
      for (var task in concreteTasks) {
        if (task.recurringTaskId != null) {
          // This is a concrete instance of a recurring task
          // We must check if it's marked as deleted (though readTasksByDate usually returns all,
          // we filter logically if we had a flag, but our isDeleted is a field now)
          if (!task.isDeleted) {
            displayedTasks.add(task);
          }
          // Mark this recurring series as handled for this day (exception exists)
          processedRecurringIds.add(task.recurringTaskId!);
        } else {
          // Regular task
          displayedTasks.add(task);
        }
      }

      // 3. Generate dynamic instances
      if (kDebugMode) print('TaskProvider: Generating dynamic instances from ${recurringRules.length} rules');
      for (var rule in recurringRules) {
        // If we already have a concrete instance (exception) for this rule, skip generation
        if (processedRecurringIds.contains(rule.id)) {
           if (kDebugMode) print('  - Rule ${rule.id} (${rule.title}): Skipped (exception exists)');
           continue;
        }

        if (_isOccurrence(rule, normalizedDate)) {
          if (kDebugMode) print('  - Rule ${rule.id} (${rule.title}): Occurrence generated');
          final generatedTask = _generateTaskInstance(rule, normalizedDate);
          displayedTasks.add(generatedTask);
        } else {
          // if (kDebugMode) print('  - Rule ${rule.id} (${rule.title}): Not an occurrence on $normalizedDate');
        }
      }

      // 4. Sort
      displayedTasks.sort((a, b) {
        if (a.startTime == null) return -1;
        if (b.startTime == null) return 1;
        return a.startTime!.compareTo(b.startTime!);
      });

      _tasksCache[key] = displayedTasks;
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

  bool _isOccurrence(RecurringTask rule, DateTime date) {
    // Normalize dates to midnight
    final startOfDate = DateTime(date.year, date.month, date.day);
    final startOfRule = DateTime(rule.startDate.year, rule.startDate.month, rule.startDate.day);

    if (startOfDate.isBefore(startOfRule)) return false;

    switch (rule.recurrence) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        // Check day of week (e.g., both are Monday)
        return startOfDate.weekday == startOfRule.weekday;
      case RecurrenceType.monthly:
        // Check day of month
        // Handle edge cases like 31st not existing in some months?
        // Basic implementation: exact day match.
        // If rule starts on 31st, it won't show on months with 30 days.
        return startOfDate.day == startOfRule.day;
      default:
        return false;
    }
  }

  Task _generateTaskInstance(RecurringTask rule, DateTime date) {
     // Normalize date to midnight just in case
     final normalizedDate = DateTime(date.year, date.month, date.day);

     // Create a deterministic ID: recurringId_YYYY-MM-DD
     final dateKey = _getDateKey(normalizedDate);
     final instanceId = "${rule.id}_$dateKey";

     // Construct DateTime for start/end on the specific date
     DateTime? startTime;
     DateTime? endTime;

     if (rule.startTime != null) {
       startTime = DateTime(normalizedDate.year, normalizedDate.month, normalizedDate.day, rule.startTime!.hour, rule.startTime!.minute);
     }
     if (rule.endTime != null) {
       endTime = DateTime(normalizedDate.year, normalizedDate.month, normalizedDate.day, rule.endTime!.hour, rule.endTime!.minute);
     }

     return Task(
       id: instanceId,
       title: rule.title,
       description: rule.description,
       date: normalizedDate,
       startTime: startTime,
       endTime: endTime,
       recurrence: rule.recurrence,
       colorValue: rule.colorValue,
       iconCodePoint: rule.iconCodePoint,
       reminders: rule.reminders,
       recurringTaskId: rule.id,
       seriesId: rule.id, // Keep seriesId for compatibility if needed
       subtasks: rule.subtasks.map((title) => Subtask(title: title, taskId: instanceId)).toList(),
       isDone: false,
       isDeleted: false,
     );
  }

  Future<void> addTask(Task task) async {
    print('DEBUG: TaskProvider.addTask called for ${task.id}');
    // Normalize date to midnight
    final normalizedDate = DateTime(task.date.year, task.date.month, task.date.day);
    // Create copy with normalized date
    final taskToSave = task.copyWith(date: normalizedDate);

    if (taskToSave.recurrence != RecurrenceType.none) {
      print('DEBUG: Adding new RecurringTask series');
      // Create RecurringTask
      final recurringTask = RecurringTask(
        id: const Uuid().v4(), // New ID for the series
        title: taskToSave.title,
        description: taskToSave.description,
        recurrence: taskToSave.recurrence,
        startDate: taskToSave.date,
        startTime: taskToSave.startTime,
        endTime: taskToSave.endTime,
        colorValue: taskToSave.colorValue,
        iconCodePoint: taskToSave.iconCodePoint,
        reminders: taskToSave.reminders,
        subtasks: taskToSave.subtasks.map((s) => s.title).toList(),
      );

      await DatabaseHelper.instance.createRecurringTask(recurringTask);

      // We do NOT explicitly create a concrete task for the first instance
      // unless we want to persist initial state. The dynamic loader will handle it.
      // However, to ensure immediate scheduling of notification for today:
      if (_isOccurrence(recurringTask, normalizedDate)) {
         final instance = _generateTaskInstance(recurringTask, normalizedDate);
         await NotificationService.instance.scheduleTaskNotification(instance);
      }
      _tasksCache.clear();
    } else {
      print('DEBUG: Adding regular task or exception');
      // Regular task or Exception (concrete instance)
      // We handle potential "Upsert" here because AddTaskScreen might call addTask
      // for a task that already exists (e.g. editing a generated exception twice).
      if (kDebugMode) {
        print('TaskProvider: Adding/Updating task ${taskToSave.id} (RecID: ${taskToSave.recurringTaskId})');
      }
      try {
        await DatabaseHelper.instance.createTask(taskToSave);
        if (kDebugMode) print('TaskProvider: Created task successfully');
      } catch (e) {
        // If creation fails (likely PK exists), try updating
        if (kDebugMode) print('TaskProvider: Creation failed ($e), trying update');
        await DatabaseHelper.instance.updateTask(taskToSave);
      }

      await NotificationService.instance.scheduleTaskNotification(taskToSave);
      _tasksCache.remove(_getDateKey(normalizedDate));
    }

    await loadTasksForDate(normalizedDate);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    print('DEBUG: TaskProvider.updateTask called for ${task.id}');
    final normalizedDate = DateTime(task.date.year, task.date.month, task.date.day);
    final taskToUpdate = task.copyWith(date: normalizedDate);

    // This method updates a single instance (Exception).

    // Safety check: verify existence to avoid FK crashes in DatabaseHelper.updateTask
    // if the task doesn't exist yet (generated).
    bool exists = false;
    try {
      await DatabaseHelper.instance.readTask(taskToUpdate.id);
      exists = true;
    } catch (_) {}

    print('DEBUG: Task exists in DB: $exists');

    if (exists) {
      if (kDebugMode) print('TaskProvider: Updating existing task ${taskToUpdate.id}');
      await DatabaseHelper.instance.updateTask(taskToUpdate);
    } else {
       // Task didn't exist (it was generated), so we must create it now (materialize exception)
       if (kDebugMode) print('TaskProvider: Materializing generated task ${taskToUpdate.id}');
       await DatabaseHelper.instance.createTask(taskToUpdate);
    }

    await NotificationService.instance.scheduleTaskNotification(taskToUpdate);

    _tasksCache.remove(_getDateKey(normalizedDate));
    await loadTasksForDate(normalizedDate);
    notifyListeners();
  }



  // Revised deleteTask that handles the logic properly by accepting the Task object?
  // Or we find it in cache.
  Future<void> deleteTaskObject(Task task) async {
    await NotificationService.instance.cancelTaskNotification(task);

    if (task.recurringTaskId != null) {
      // It's part of a series (either generated or concrete exception).
      // We must persist a "Deleted" status (Tombstone).
      final tombstone = task.copyWith(isDeleted: true);

      // If it was generated (not in DB), updateTask/createTask handles it.
      // If it was concrete (in DB), updateTask handles it.
      // So essentially:
      int count = await DatabaseHelper.instance.updateTask(tombstone);
      if (count == 0) {
        await DatabaseHelper.instance.createTask(tombstone);
      }
    } else {
      // Regular task, just delete
      await DatabaseHelper.instance.deleteTask(task.id);
    }

    _tasksCache.remove(_getDateKey(task.date));
    await loadTasksForDate(DateTime(task.date.year, task.date.month, task.date.day));
    notifyListeners();
  }

  // Override the string-based deleteTask to lookup in cache
  Future<void> deleteTask(String id) async {
    // Find task in current cache if possible
    Task? targetTask;
    _tasksCache.forEach((key, list) {
      final idx = list.indexWhere((t) => t.id == id);
      if (idx != -1) targetTask = list[idx];
    });

    if (targetTask != null) {
      await deleteTaskObject(targetTask!);
    } else {
      // Fallback for non-cached (shouldn't happen often in UI)
      // Just try DB delete
      await DatabaseHelper.instance.deleteTask(id);
      notifyListeners();
    }
  }

  Future<void> deleteSeries(
    String seriesId, {
    bool all = true,
    DateTime? futureFrom,
  }) async {
    if (all) {
      // Delete rule
      final rule = await DatabaseHelper.instance.readRecurringTask(seriesId);
      if (rule != null) {
        // Cancel the main series notification
        final initialInstance = _generateTaskInstance(rule, rule.startDate);
        await NotificationService.instance.cancelTaskNotification(initialInstance);
      }
      await DatabaseHelper.instance.deleteRecurringTask(seriesId);

      // Delete all concrete instances/tombstones
      final allTasks = await DatabaseHelper.instance.readAllTasks();
      for (var t in allTasks) {
        if (t.recurringTaskId == seriesId) {
          await NotificationService.instance.cancelTaskNotification(t);
          await DatabaseHelper.instance.deleteTask(t.id);
        }
      }
    } else if (futureFrom != null) {
      // "Future" deletion -> End the current recurrence
      // Current model lacks recurrenceEndDate.
      // We can simulate by deleting future instances? No, dynamic generation will bring them back.
      // We MUST split the series or have an end date.
      // Since we don't have end date in model, we can't properly support "stop repeating".
      // Workaround: Create tombstones for a reasonable range? No, infinite.

      // For now, if user selects "Future", we might have to convert the rule to "None" or delete it if they want to stop.
      // Assuming "Delete Series" means "Stop happening".
      // If we lack "EndDate", we can't stop it at a specific date without changing the start date of a new "deleted" period?
      // Let's implement strict "Delete All" for simplicity as per prompt "repeat forever".
      // If user wants to stop, they typically delete the series.

      // If "This & Future" is requested for deletion, we can try to find the rule.
      final rule = await DatabaseHelper.instance.readRecurringTask(seriesId);
      if (rule != null) {
        // Technically we can't shorten it. We'll just delete all for now or alert user?
        // Let's fallback to deleting all to be safe.

        // Cancel the main series notification
        final initialInstance = _generateTaskInstance(rule, rule.startDate);
        await NotificationService.instance.cancelTaskNotification(initialInstance);

        await DatabaseHelper.instance.deleteRecurringTask(seriesId);
        // Clean up exceptions
         final allTasks = await DatabaseHelper.instance.readAllTasks();
         for (var t in allTasks) {
            if (t.recurringTaskId == seriesId) {
              await NotificationService.instance.cancelTaskNotification(t);
              await DatabaseHelper.instance.deleteTask(t.id);
            }
         }
      }
    }

    await clearCache();
    notifyListeners();
  }

  Future<void> updateSeries(
    Task updatedTask, {
    bool all = true,
    DateTime? futureFrom,
  }) async {
    final seriesId = updatedTask.seriesId ?? updatedTask.recurringTaskId!;
    print('DEBUG: updateSeries called for series $seriesId (all=$all)');

    if (all) {
       // Update the recurring rule
       final rule = await DatabaseHelper.instance.readRecurringTask(seriesId);
       if (rule != null) {
         print('DEBUG: Found rule ${rule.id}. Updating...');
         // Cancel the old series notification
         final initialInstance = _generateTaskInstance(rule, rule.startDate);
         await NotificationService.instance.cancelTaskNotification(initialInstance);

         final updatedRule = rule.copyWith(
           title: updatedTask.title,
           description: updatedTask.description,
           recurrence: updatedTask.recurrence,
           startDate: updatedTask.date, // Shift start date? Or keep original?
           // If we change startDate, we might shift the whole pattern.
           // Usually "Edit All" updates the properties but keeps the anchor unless explicitly changed.
           // But updatedTask comes from a specific instance.
           // Let's adopt the properties.
           colorValue: updatedTask.colorValue,
           iconCodePoint: updatedTask.iconCodePoint,
           startTime: updatedTask.startTime,
           endTime: updatedTask.endTime,
           reminders: updatedTask.reminders,
           subtasks: updatedTask.subtasks.map((s) => s.title).toList(),
         );
         print('DEBUG: Saving updated rule: StartDate=${updatedRule.startDate}, StartTime=${updatedRule.startTime}');
         await DatabaseHelper.instance.updateRecurringTask(updatedRule);

         // Clear exceptions to enforce uniformity?
         // Or keep exceptions? "Update All" usually overrides everything.
         final allTasks = await DatabaseHelper.instance.readAllTasks();
         for (var t in allTasks) {
            if (t.recurringTaskId == seriesId) {
              print('DEBUG: Deleting exception ${t.id}');
              await NotificationService.instance.cancelTaskNotification(t);
              await DatabaseHelper.instance.deleteTask(t.id);
            }
         }

         // Schedule notification for the updated series (using the new start date/time)
         await NotificationService.instance.scheduleTaskNotification(updatedTask);
       } else {
         print('DEBUG: Rule not found for series $seriesId');
       }
    } else {
       // "This & Future"
       // We split the series:
       // 1. Materialize past instances of the OLD rule (up to futureFrom).
       // 2. Delete the OLD rule.
       // 3. Create a NEW rule starting from futureFrom with NEW properties.

       if (futureFrom == null) {
          await updateSeries(updatedTask, all: true);
          return;
       }

       final oldRule = await DatabaseHelper.instance.readRecurringTask(seriesId);
       if (oldRule == null) return;

       // Cancel notification for old series
       final oldInitialInstance = _generateTaskInstance(oldRule, oldRule.startDate);
       await NotificationService.instance.cancelTaskNotification(oldInitialInstance);

       final cutOffDate = DateTime(futureFrom.year, futureFrom.month, futureFrom.day);

       // 1. Materialize past
       if (cutOffDate.isAfter(oldRule.startDate)) {
          final allTasks = await DatabaseHelper.instance.readAllTasks();
          final existingExceptions = allTasks.where((t) => t.recurringTaskId == seriesId).toList();

          DateTime loopDate = DateTime(oldRule.startDate.year, oldRule.startDate.month, oldRule.startDate.day);

          // Iterate using recurrence logic to skip unnecessary checks
          while (loopDate.isBefore(cutOffDate)) {
             if (_isOccurrence(oldRule, loopDate)) {
                // Check if exception exists
                final exists = existingExceptions.any((t) => isSameDay(t.date, loopDate) && !t.isDeleted);
                if (!exists) {
                   // Generate and save concrete task using OLD rule properties
                   final historicTask = _generateTaskInstance(oldRule, loopDate);

                   // Manually construct concrete task to ensure nulls are applied (copyWith ignores nulls)
                   final concreteId = const Uuid().v4();
                   final concrete = Task(
                      id: concreteId,
                      title: historicTask.title,
                      description: historicTask.description,
                      date: historicTask.date,
                      startTime: historicTask.startTime,
                      endTime: historicTask.endTime,
                      isDone: historicTask.isDone,
                      recurrence: RecurrenceType.none,
                      colorValue: historicTask.colorValue,
                      iconCodePoint: historicTask.iconCodePoint,
                      reminders: historicTask.reminders,
                      subtasks: historicTask.subtasks.map((s) => s.copyWith(id: const Uuid().v4(), taskId: concreteId)).toList(),
                      seriesId: null,
                      recurringTaskId: null,
                      isDeleted: false,
                   );
                   await DatabaseHelper.instance.createTask(concrete);
                }
             }

             // Optimization: Jump to next potential date
             switch (oldRule.recurrence) {
               case RecurrenceType.daily:
                 loopDate = loopDate.add(const Duration(days: 1));
                 break;
               case RecurrenceType.weekly:
                 loopDate = loopDate.add(const Duration(days: 7));
                 break;
               case RecurrenceType.monthly:
                 // Add 1 month, handle year rollover
                 int nextMonth = loopDate.month + 1;
                 int nextYear = loopDate.year;
                 if (nextMonth > 12) {
                   nextMonth = 1;
                   nextYear++;
                 }
                 // Try to keep the same day. If day doesn't exist (e.g. Feb 30), DateTime typically wraps to next month.
                 loopDate = DateTime(nextYear, nextMonth, oldRule.startDate.day);
                 break;
               case RecurrenceType.none:
                 loopDate = cutOffDate; // Stop loop
                 break;
             }
          }

          // Also detach existing past exceptions
          for (var t in existingExceptions) {
             final tDate = DateTime(t.date.year, t.date.month, t.date.day);
             if (tDate.isBefore(cutOffDate)) {
                // Manually construct detached task to ensure nulls are applied
                final detached = Task(
                  id: t.id,
                  title: t.title,
                  description: t.description,
                  date: t.date,
                  startTime: t.startTime,
                  endTime: t.endTime,
                  isDone: t.isDone,
                  recurrence: RecurrenceType.none,
                  colorValue: t.colorValue,
                  iconCodePoint: t.iconCodePoint,
                  reminders: t.reminders,
                  subtasks: t.subtasks,
                  seriesId: null,
                  recurringTaskId: null,
                  isDeleted: t.isDeleted,
                );
                await DatabaseHelper.instance.updateTask(detached);
             } else {
                // Future exceptions will be deleted below (as they are part of the old series "future")
             }
          }
       }

       // 2. Delete old rule
       await DatabaseHelper.instance.deleteRecurringTask(seriesId);

       // 3. Delete future exceptions of old rule
       // (We re-read or filter from previous list)
       final allTasksAgain = await DatabaseHelper.instance.readAllTasks();
       for (var t in allTasksAgain) {
          if (t.recurringTaskId == seriesId) {
             // These are effectively >= cutOffDate because we detached the past ones above
             await NotificationService.instance.cancelTaskNotification(t);
             await DatabaseHelper.instance.deleteTask(t.id);
          }
       }

       // 4. Create new rule
       final newSeriesId = const Uuid().v4();
       final newRule = RecurringTask(
         id: newSeriesId,
         title: updatedTask.title,
         description: updatedTask.description,
         recurrence: updatedTask.recurrence,
         startDate: cutOffDate,
         startTime: updatedTask.startTime,
         endTime: updatedTask.endTime,
         colorValue: updatedTask.colorValue,
         iconCodePoint: updatedTask.iconCodePoint,
         reminders: updatedTask.reminders,
         subtasks: updatedTask.subtasks.map((s) => s.title).toList(),
       );
       await DatabaseHelper.instance.createRecurringTask(newRule);

       // Schedule notification for new rule
       final firstInstance = _generateTaskInstance(newRule, cutOffDate);
       await NotificationService.instance.scheduleTaskNotification(firstInstance);
    }

    await clearCache();
    notifyListeners();
  }

  Future<void> clearCache() async {
    _tasksCache.clear();
    await loadTasksForDate(_selectedDate, force: true);
  }

  Future<void> toggleSubtask(Task task, Subtask subtask) async {
    // We need to modify the subtask state.
    // Since task might be generated, we can't just update subtask table.
    // We must update the task object and call updateTask.

    final updatedSubtasks = task.subtasks.map((s) {
      if (s.id == subtask.id) {
        return s.copyWith(isDone: !s.isDone);
      }
      return s;
    }).toList();

    final updatedTask = task.copyWith(subtasks: updatedSubtasks);
    await updateTask(updatedTask);
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }


}
