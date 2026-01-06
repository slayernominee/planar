import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/icon_picker_dialog.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final Task? taskToEdit;

  const AddTaskScreen({super.key, required this.initialDate, this.taskToEdit});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _taskId;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  DateTime? _startTime;
  DateTime? _endTime;
  late int _selectedColor;
  int? _selectedIconCodePoint;
  late RecurrenceType _recurrence;
  List<int> _reminders = [];
  List<Subtask> _subtasks = [];

  final List<int> _colors = [
    0xFF90CAF9, // Blue 200
    0xFFA5D6A7, // Green 200
    0xFFFFF59D, // Yellow 200
    0xFFEF9A9A, // Red 200
    0xFFCE93D8, // Purple 200
    0xFF80DEEA, // Cyan 200
    0xFFFFCC80, // Orange 200
    0xFFF48FB1, // Pink 200
    0xFFB0BEC5, // Blue Grey 200
    0xFFBCAAA4, // Brown 200
    0xFFEEEEEE, // Grey 200
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    _taskId = task?.id ?? const Uuid().v4();
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _selectedDate = task?.date ?? widget.initialDate;
    _startTime = task?.startTime;
    _endTime = task?.endTime;
    _selectedColor = task?.colorValue ?? _colors[0];
    _selectedIconCodePoint = task?.iconCodePoint;
    _recurrence = task?.recurrence ?? RecurrenceType.none;

    if (task != null) {
      _subtasks = task.subtasks.map((s) => s.copyWith()).toList();
    }

    // Default times if new and not provided
    if (_startTime == null && widget.taskToEdit == null) {
      final now = DateTime.now();
      final minutesToAdd = 5 - (now.minute % 5);
      final baseTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
      );
      _startTime = baseTime.add(Duration(minutes: minutesToAdd));
      _endTime = _startTime!.add(const Duration(minutes: 15));
    }
    if (_endTime == null && _startTime != null) {
      _endTime = _startTime!.add(const Duration(minutes: 15));
    }
    _reminders = widget.taskToEdit != null
        ? List.from(widget.taskToEdit!.reminders)
        : [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final IconData? picked = await showDialog(
      context: context,
      builder: (context) => IconPickerDialog(
        selectedIcon: _selectedIconCodePoint != null
            ? IconData(_selectedIconCodePoint!, fontFamily: 'MaterialIcons')
            : null,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedIconCodePoint = picked.codePoint;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final newDate = DateTime(picked.year, picked.month, picked.day);
        if (_startTime != null) {
          _startTime = DateTime(
            newDate.year,
            newDate.month,
            newDate.day,
            _startTime!.hour,
            _startTime!.minute,
          );
        }
        if (_endTime != null) {
          _endTime = DateTime(
            newDate.year,
            newDate.month,
            newDate.day,
            _endTime!.hour,
            _endTime!.minute,
          );
        }
        _selectedDate = newDate;
      });
    }
  }

  void _openTimePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TimePickerSheet(
        initialStartTime: _startTime ?? DateTime.now(),
        initialEndTime:
            _endTime ?? DateTime.now().add(const Duration(minutes: 15)),
        onSave: (start, end) {
          setState(() {
            _startTime = start;
            _endTime = end;
          });
        },
      ),
    );
  }

  void _addSubtask() {
    setState(() {
      _subtasks.add(Subtask(title: '', taskId: _taskId));
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final newTask = Task(
      id: _taskId,
      title: _titleController.text,
      description: _descriptionController.text,
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      colorValue: _selectedColor,
      recurrence: _recurrence,
      subtasks: _subtasks.where((s) => s.title.trim().isNotEmpty).toList(),
      isDone: widget.taskToEdit?.isDone ?? false,
      iconCodePoint: _selectedIconCodePoint,
      seriesId: widget.taskToEdit?.seriesId,
      reminders: _reminders,
    );

    final provider = context.read<TaskProvider>();
    if (widget.taskToEdit != null) {
      if (widget.taskToEdit!.seriesId != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Update Recurring Task',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'This task is part of a series. How do you want to update it?',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Decouple this instance from the series to avoid accidental
                  // duplication or future updates affecting it.
                  final standaloneTask = newTask.copyWith(
                    seriesId: null,
                    recurrence: (widget.taskToEdit?.recurrence == _recurrence)
                        ? RecurrenceType.none
                        : _recurrence,
                  );
                  await provider.updateTask(standaloneTask);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Only This',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Only propagate recurrence change if it actually changed,
                  // otherwise keep child tasks as non-recurring.
                  final taskToUpdate =
                      (widget.taskToEdit?.recurrence == _recurrence)
                      ? newTask.copyWith(recurrence: RecurrenceType.none)
                      : newTask;
                  await provider.updateSeries(
                    taskToUpdate,
                    all: false,
                    futureFrom: newTask.date,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'This & Future',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () async {
                  // Only propagate recurrence change if it actually changed.
                  final taskToUpdate =
                      (widget.taskToEdit?.recurrence == _recurrence)
                      ? newTask.copyWith(recurrence: RecurrenceType.none)
                      : newTask;
                  await provider.updateSeries(taskToUpdate, all: true);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('All', style: TextStyle(color: Colors.teal)),
              ),
            ],
          ),
        );
      } else {
        if (widget.taskToEdit!.recurrence == _recurrence) {
          newTask.recurrence = RecurrenceType.none;
        }
        await provider.updateTask(newTask);
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      await provider.addTask(newTask);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _deleteTask() async {
    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      if (task.seriesId != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Delete Recurring Task',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'This task is part of a series. What would you like to delete?',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<TaskProvider>().deleteTask(task.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Only This',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<TaskProvider>().deleteSeries(
                    task.seriesId!,
                    all: false,
                    futureFrom: task.date,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'This & Future',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<TaskProvider>().deleteSeries(
                    task.seriesId!,
                    all: true,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('All', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      } else {
        await context.read<TaskProvider>().deleteTask(task.id);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  String _getDurationString() {
    if (_startTime == null || _endTime == null) return '15 min';
    final diff = _endTime!.difference(_startTime!);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes} min';
  }

  String _getRecurrenceLabel() {
    switch (_recurrence) {
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.none:
        return 'No repeat';
    }
  }

  void _showReminderPicker() {
    int h = 0;
    int m = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Reminders",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (({
                      0,
                      5,
                      10,
                      15,
                      30,
                      60,
                    }..addAll(_reminders)).toList()..sort()).map((mins) {
                      final isSelected = _reminders.contains(mins);
                      String label;
                      if (mins == 0) {
                        label = "At task";
                      } else if (mins < 60) {
                        label = "$mins min before";
                      } else {
                        final hours = mins ~/ 60;
                        final minutes = mins % 60;
                        label = minutes == 0
                            ? "$hours h before"
                            : "$hours h $minutes m before";
                      }
                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!_reminders.contains(mins))
                                _reminders.add(mins);
                            } else {
                              _reminders.remove(mins);
                            }
                            _reminders.sort();
                          });
                          setModalState(() {});
                        },
                        selectedColor: Colors.teal.withOpacity(0.2),
                        checkmarkColor: Colors.teal,
                      );
                    }).toList(),
              ),
              const Divider(height: 32),
              const Text(
                "Custom Reminder",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (val) => h = val,
                        children: List.generate(
                          24,
                          (i) => Center(child: Text("$i h")),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 120,
                      child: CupertinoPicker(
                        itemExtent: 32,
                        onSelectedItemChanged: (val) => m = val,
                        children: List.generate(
                          60,
                          (i) => Center(child: Text("$i m")),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final totalMins = h * 60 + m;
                    setState(() {
                      if (!_reminders.contains(totalMins)) {
                        _reminders.add(totalMins);
                        _reminders.sort();
                      }
                    });
                    setModalState(() {});
                  },
                  child: const Text("Add Custom Reminder"),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecurrencePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Repeat",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...RecurrenceType.values.map((type) {
              String label = 'Never';
              switch (type) {
                case RecurrenceType.daily:
                  label = 'Daily';
                  break;
                case RecurrenceType.weekly:
                  label = 'Weekly';
                  break;
                case RecurrenceType.monthly:
                  label = 'Monthly';
                  break;
                case RecurrenceType.none:
                  label = 'Does not repeat';
                  break;
              }
              return ListTile(
                title: Text(label, style: const TextStyle(color: Colors.black)),
                trailing: _recurrence == type
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () {
                  setState(() => _recurrence = type);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Task' : 'New Task',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.teal, size: 28),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Title & Icon Row
            Row(
              children: [
                GestureDetector(
                  onTap: _pickIcon,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedIconCodePoint != null
                          ? IconData(
                              _selectedIconCodePoint!,
                              fontFamily: 'MaterialIcons',
                            )
                          : Icons.sentiment_satisfied_alt,
                      color: Colors.black54,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, d MMM').format(_selectedDate),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _openTimePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_startTime != null ? DateFormat('HH:mm').format(_startTime!) : '--:--'} - ${_endTime != null ? DateFormat('HH:mm').format(_endTime!) : '--:--'}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Color Picker
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final colorValue = _colors[index];
                  final isSelected = _selectedColor == colorValue;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorValue),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Recurrence
            InkWell(
              onTap: _showRecurrencePicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.repeat, color: Colors.black54),
                        const SizedBox(width: 12),
                        Text(
                          _getRecurrenceLabel(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Reminder
            InkWell(
              onTap: _showReminderPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _reminders.isEmpty
                              ? 'No reminders'
                              : _reminders
                                    .map((m) => m == 0 ? "At task" : "${m}m")
                                    .join(", "),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Subtasks & Notes
            const Text(
              'Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Subtasks List
                  ..._subtasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final subtask = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              () => subtask.isDone = !subtask.isDone,
                            ),
                            child: Icon(
                              subtask.isDone
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: subtask.isDone ? Colors.teal : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: subtask.title,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) => subtask.title = val,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _subtasks.removeAt(index)),
                            child: const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // Add Subtask Button
                  InkWell(
                    onTap: _addSubtask,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: const [
                          Icon(Icons.add, color: Colors.grey),
                          SizedBox(width: 12),
                          Text(
                            "Add Subtask",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: TextFormField(
                      controller: _descriptionController,
                      maxLines: null,
                      minLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notes...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            if (isEditing)
              Center(
                child: TextButton.icon(
                  onPressed: _deleteTask,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete Task',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  final DateTime initialStartTime;
  final DateTime initialEndTime;
  final Function(DateTime, DateTime) onSave;

  const _TimePickerSheet({
    required this.initialStartTime,
    required this.initialEndTime,
    required this.onSave,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late DateTime _start;
  late DateTime _end;
  late FixedExtentScrollController _startHourCtrl;
  late FixedExtentScrollController _startMinCtrl;
  late FixedExtentScrollController _endHourCtrl;
  late FixedExtentScrollController _endMinCtrl;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStartTime;
    _end = widget.initialEndTime;
    // Infinite loop trick
    _startHourCtrl = FixedExtentScrollController(
      initialItem: 1000 * 24 + _start.hour,
    );
    _startMinCtrl = FixedExtentScrollController(
      initialItem: 1000 * 60 + _start.minute,
    );
    _endHourCtrl = FixedExtentScrollController(
      initialItem: 1000 * 24 + _end.hour,
    );
    _endMinCtrl = FixedExtentScrollController(
      initialItem: 1000 * 60 + _end.minute,
    );
  }

  @override
  void dispose() {
    _startHourCtrl.dispose();
    _startMinCtrl.dispose();
    _endHourCtrl.dispose();
    _endMinCtrl.dispose();
    super.dispose();
  }

  void _updateStartTime(int hour, int minute) {
    final h = hour % 24;
    final m = minute % 60;
    final oldStart = _start;
    final newStart = DateTime(
      oldStart.year,
      oldStart.month,
      oldStart.day,
      h,
      m,
    );
    final duration = _end.difference(oldStart);

    setState(() {
      _start = newStart;
      _end = newStart.add(duration);
    });

    if (_endHourCtrl.hasClients) {
      _endHourCtrl.jumpToItem(1000 * 24 + _end.hour);
    }
    if (_endMinCtrl.hasClients) {
      _endMinCtrl.jumpToItem(1000 * 60 + _end.minute);
    }
  }

  void _updateEndTime(int hour, int minute) {
    final h = hour % 24;
    final m = minute % 60;
    final newEnd = DateTime(_end.year, _end.month, _end.day, h, m);
    setState(() {
      _end = newEnd;
    });
  }

  void _setDuration(int minutes) {
    setState(() {
      _end = _start.add(Duration(minutes: minutes));
    });
    if (_endHourCtrl.hasClients) {
      _endHourCtrl.jumpToItem(1000 * 24 + _end.hour);
    }
    if (_endMinCtrl.hasClients) {
      _endMinCtrl.jumpToItem(1000 * 60 + _end.minute);
    }
  }

  Widget _buildPicker(
    FixedExtentScrollController ctrl,
    int count,
    Function(int) onChanged,
  ) {
    return SizedBox(
      width: 40,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 32,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        useMagnifier: true,
        magnification: 1.2,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            return Center(
              child: Text(
                (index % count).toString().padLeft(2, '0'),
                style: const TextStyle(color: Colors.black, fontSize: 18),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Time',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  widget.onSave(_start, _end);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Wheel Container
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPicker(
                  _startHourCtrl,
                  24,
                  (val) => _updateStartTime(val, _start.minute),
                ),
                _buildPicker(
                  _startMinCtrl,
                  60,
                  (val) => _updateStartTime(_start.hour, val),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                _buildPicker(
                  _endHourCtrl,
                  24,
                  (val) => _updateEndTime(val, _end.minute),
                ),
                _buildPicker(
                  _endMinCtrl,
                  60,
                  (val) => _updateEndTime(_end.hour, val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Duration',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int min in [5, 15, 30, 45, 60, 90, 120])
                  GestureDetector(
                    onTap: () => _setDuration(min),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _end.difference(_start).inMinutes == min
                              ? Colors.teal
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        min < 60
                            ? '${min}m'
                            : (min % 60 == 0
                                  ? '${min ~/ 60}h'
                                  : '${(min / 60).toStringAsFixed(1)}h'),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
