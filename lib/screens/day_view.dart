import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'add_task_screen.dart';

class DayView extends StatefulWidget {
  final DateTime date;

  const DayView({super.key, required this.date});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        if (widget.date.year == now.year &&
            widget.date.month == now.month &&
            widget.date.day == now.day) {
          setState(() {});
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasksForDate(widget.date);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final tasks = taskProvider.getTasksFor(widget.date);
        final timedTasks = tasks.where((t) => t.startTime != null).toList();

        return Container(
          color: Colors.white,
          child: timedTasks.isEmpty
              ? _buildEmptyState()
              : _build24hTimeline(timedTasks),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100.0),
        child: Column(
          children: [
            Icon(
              Icons.event_note,
              size: 60,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No plans yet',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build24hTimeline(List<Task> tasks) {
    const double hourHeight = 80.0;
    const double timeLineWidth = 60.0;
    final availableWidth =
        MediaQuery.of(context).size.width - timeLineWidth - 32;

    tasks.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    final layouts = _calculateTaskLayouts(tasks);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Stack(
          children: [
            Column(
              children: List.generate(24, (hour) {
                return SizedBox(
                  height: hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: timeLineWidth,
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            ...layouts.map((layout) {
              final task = layout.task;
              final start = task.startTime!;
              DateTime end =
                  task.endTime ?? start.add(const Duration(minutes: 30));

              // Handle tasks ending on a different day for visualization
              if (end.year != start.year ||
                  end.month != start.month ||
                  end.day != start.day) {
                end = DateTime(start.year, start.month, start.day, 23, 59, 59);
              }

              final top = (start.hour + start.minute / 60.0) * hourHeight;
              final height =
                  (end.difference(start).inMinutes / 60.0) * hourHeight;

              return Positioned(
                top: top,
                left:
                    timeLineWidth +
                    (layout.column *
                        (1.0 / layout.totalColumns) *
                        availableWidth),
                width: (1.0 / layout.totalColumns) * availableWidth,
                height: height.clamp(30.0, 24 * hourHeight),
                child: _buildTaskCard(task),
              );
            }).toList(),
            if (_isToday()) _buildNowLine(hourHeight, timeLineWidth),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    final now = DateTime.now();
    return widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
  }

  Widget _buildNowLine(double hourHeight, double timeLineWidth) {
    final now = DateTime.now();
    final top = (now.hour + now.minute / 60.0) * hourHeight;

    return Positioned(
      top: top - 5,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: timeLineWidth,
            child: Text(
              DateFormat('HH:mm').format(now),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final color = Color(task.colorValue);
    final isDone = task.isDone;
    final iconData = task.iconCodePoint != null
        ? IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons')
        : Icons.event;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                AddTaskScreen(initialDate: widget.date, taskToEdit: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDone ? Colors.grey[100] : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: isDone ? Colors.grey : color, width: 4),
          ),
        ),
        child: Opacity(
          opacity: isDone ? 0.6 : 1.0,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(iconData, color: color, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          color: isDone ? Colors.black54 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    style: const TextStyle(color: Colors.black54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_TaskLayout> _calculateTaskLayouts(List<Task> tasks) {
    if (tasks.isEmpty) return [];

    final layouts = tasks.map((t) => _TaskLayout(t)).toList();
    List<List<_TaskLayout>> groups = [];

    for (var layout in layouts) {
      List<List<_TaskLayout>> overlappingGroups = [];
      for (var group in groups) {
        if (group.any((l) => _overlaps(l.task, layout.task))) {
          overlappingGroups.add(group);
        }
      }

      if (overlappingGroups.isEmpty) {
        groups.add([layout]);
      } else {
        var firstGroup = overlappingGroups[0];
        firstGroup.add(layout);
        for (int i = 1; i < overlappingGroups.length; i++) {
          firstGroup.addAll(overlappingGroups[i]);
          groups.remove(overlappingGroups[i]);
        }
      }
    }

    for (var group in groups) {
      group.sort((a, b) => a.task.startTime!.compareTo(b.task.startTime!));
      int maxCol = 0;
      for (var layout in group) {
        int col = 0;
        while (group.any(
          (other) =>
              other != layout &&
              other.column == col &&
              _overlaps(other.task, layout.task) &&
              group.indexOf(other) < group.indexOf(layout),
        )) {
          col++;
        }
        layout.column = col;
        if (col > maxCol) maxCol = col;
      }
      for (var layout in group) {
        layout.totalColumns = maxCol + 1;
      }
    }

    return layouts;
  }

  bool _overlaps(Task a, Task b) {
    final startA = a.startTime!;
    final endA = a.endTime ?? a.startTime!.add(const Duration(minutes: 30));
    final startB = b.startTime!;
    final endB = b.endTime ?? b.startTime!.add(const Duration(minutes: 30));
    return startA.isBefore(endB) && endA.isAfter(startB);
  }
}

class _TaskLayout {
  final Task task;
  int column = 0;
  int totalColumns = 1;
  _TaskLayout(this.task);
}
