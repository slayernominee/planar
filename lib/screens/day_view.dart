import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';
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
    return Consumer2<TaskProvider, SettingsProvider>(
      builder: (context, taskProvider, settingsProvider, child) {
        final tasks = taskProvider.getTasksFor(widget.date);
        final timedTasks = tasks.where((t) => t.startTime != null).toList();

        return Container(
          color: Colors.white,
          child: timedTasks.isEmpty
              ? _buildEmptyState()
              : _build24hTimeline(timedTasks, settingsProvider.isCompact),
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

  Widget _build24hTimeline(List<Task> tasks, bool isCompact) {
    const double timeLineWidth = 60.0;
    final availableWidth =
        MediaQuery.of(context).size.width - timeLineWidth - 32;
    tasks.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    final layouts = _calculateTaskLayouts(tasks);
    final dayStart = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );

    // 1. Create Timeline Segments
    final segments = _createTimelineSegments(tasks, dayStart, isCompact);

    // 2. Calculate offsets and build widgets
    final backgroundWidgets = <Widget>[];
    final segmentOffsets = <_TimelineSegment, double>{};
    double currentY = 0;

    for (final segment in segments) {
      segmentOffsets[segment] = currentY;
      backgroundWidgets.add(segment.buildWidget(context, timeLineWidth));
      currentY += segment.height;
    }
    if (segments.isNotEmpty) {
      backgroundWidgets.add(
        _buildLastTimeLabel(segments.last.endTime, timeLineWidth),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Stack(
          children: [
            Column(children: backgroundWidgets),
            ...layouts.map((layout) {
              final task = layout.task;
              _TaskBlockSegment? taskSegment;
              for (var s in segments) {
                if (s is _TaskBlockSegment && s.tasks.contains(task)) {
                  taskSegment = s;
                  break;
                }
              }

              if (taskSegment == null) return const SizedBox.shrink();

              final segmentTop = segmentOffsets[taskSegment]!;
              final topInSegment =
                  (task.startTime!
                      .difference(taskSegment.startTime)
                      .inMinutes) *
                  taskSegment.pixelsPerMinute;
              final top = segmentTop + topInSegment;

              final duration =
                  (task.endTime ??
                          task.startTime!.add(const Duration(minutes: 30)))
                      .difference(task.startTime!)
                      .inMinutes;
              final height = duration * taskSegment.pixelsPerMinute;

              return Positioned(
                top: top,
                left:
                    timeLineWidth +
                    (layout.column *
                        (1.0 / layout.totalColumns) *
                        availableWidth),
                width: (1.0 / layout.totalColumns) * availableWidth,
                height: height.clamp(
                  _TimelineSegment.minTaskHeight,
                  double.infinity,
                ),
                child: _buildTaskCard(task, isCompact),
              );
            }).toList(),
            if (_isToday())
              _buildNowLine(timeLineWidth, segments, segmentOffsets),
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

  List<_TimelineSegment> _createTimelineSegments(
    List<Task> tasks,
    DateTime dayStart,
    bool isCompact,
  ) {
    final segments = <_TimelineSegment>[];
    if (tasks.isEmpty) {
      segments.add(
        _FreeTimeSegment(
          dayStart,
          dayStart.add(const Duration(days: 1)),
          isCompact,
        ),
      );
      return segments;
    }

    // Start at the first task's start time to trim leading free time
    DateTime cursor = tasks.first.startTime!;

    int i = 0;
    while (i < tasks.length) {
      final firstTaskInBlock = tasks[i];

      // Add free time before this block
      if (firstTaskInBlock.startTime!.isAfter(cursor)) {
        segments.add(
          _FreeTimeSegment(cursor, firstTaskInBlock.startTime!, isCompact),
        );
      }

      // Find all overlapping tasks for this block
      final taskBlock = <Task>[firstTaskInBlock];
      DateTime blockEnd =
          firstTaskInBlock.endTime ??
          firstTaskInBlock.startTime!.add(const Duration(minutes: 30));
      int j = i + 1;
      while (j < tasks.length) {
        final nextTask = tasks[j];
        if (nextTask.startTime!.isBefore(blockEnd)) {
          taskBlock.add(nextTask);
          final nextTaskEnd =
              nextTask.endTime ??
              nextTask.startTime!.add(const Duration(minutes: 30));
          if (nextTaskEnd.isAfter(blockEnd)) {
            blockEnd = nextTaskEnd;
          }
          j++;
        } else {
          break;
        }
      }

      final blockStart = firstTaskInBlock.startTime!;
      segments.add(
        _TaskBlockSegment(blockStart, blockEnd, taskBlock, isCompact),
      );

      cursor = blockEnd;
      i = j;
    }

    return segments;
  }

  Widget _buildLastTimeLabel(DateTime time, double timeLineWidth) {
    final endsNextDay =
        time.day != widget.date.day ||
        time.month != widget.date.month ||
        time.year != widget.date.year;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: timeLineWidth,
          height: 0,
          child: OverflowBox(
            minHeight: 40,
            maxHeight: 40,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(time),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (endsNextDay)
                    Text(
                      '+1',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNowLine(
    double timeLineWidth,
    List<_TimelineSegment> segments,
    Map<_TimelineSegment, double> segmentOffsets,
  ) {
    final now = DateTime.now();
    _TimelineSegment? segment;
    for (var s in segments) {
      if (now.isAtSameMomentAs(s.startTime) ||
          (now.isAfter(s.startTime) && now.isBefore(s.endTime))) {
        segment = s;
        break;
      }
    }
    if (segment == null) return const SizedBox.shrink();

    final segmentTop = segmentOffsets[segment]!;
    final minutesIntoSegment = now.difference(segment.startTime).inMinutes;
    final top = segmentTop + (minutesIntoSegment * segment.pixelsPerMinute);

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

  Widget _buildTaskCard(Task task, bool isCompact) {
    final color = Color(task.colorValue);
    final isDone = task.isDone;
    final iconData = task.iconCodePoint != null
        ? IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons')
        : Icons.event;
    final isRecurring = task.seriesId != null;
    final startTimeStr = DateFormat('HH:mm').format(task.startTime!);
    final endTimeStr = task.endTime != null
        ? DateFormat('HH:mm').format(task.endTime!)
        : '?';

    final completedSubtasks = task.subtasks.where((s) => s.isDone).length;
    final totalSubtasks = task.subtasks.length;

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
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isCompact ? 36 : 44,
                height: isCompact ? 36 : 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
                  border: Border.all(color: color.withOpacity(0.2), width: 1),
                ),
                child: Icon(iconData, color: color, size: isCompact ? 20 : 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: task.title,
                              style: TextStyle(
                                color: isDone ? Colors.black54 : Colors.black87,
                                fontSize: isCompact ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            TextSpan(
                              text: ' ($startTimeStr-$endTimeStr)',
                              style: TextStyle(
                                color: Colors.black38,
                                fontSize: isCompact ? 11 : 13,
                                fontWeight: FontWeight.normal,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (isRecurring)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.repeat,
                                    size: isCompact ? 12 : 14,
                                    color: Colors.black26,
                                  ),
                                ),
                              ),
                            if (task.endTime != null &&
                                (task.endTime!.day != task.startTime!.day ||
                                    task.endTime!.month !=
                                        task.startTime!.month ||
                                    task.endTime!.year != task.startTime!.year))
                              TextSpan(
                                text: ' +1',
                                style: TextStyle(
                                  color: color.withOpacity(0.8),
                                  fontSize: isCompact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: isCompact ? 10 : 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: isCompact ? 1 : 2,
                        ),
                      ],
                      if (totalSubtasks > 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.checklist,
                              size: isCompact ? 12 : 14,
                              color: color.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$completedSubtasks/$totalSubtasks tasks',
                                style: TextStyle(
                                  color: color.withOpacity(0.7),
                                  fontSize: isCompact ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  final updated = task.copyWith(isDone: !task.isDone);
                  context.read<TaskProvider>().updateTask(updated);
                },
                child: Icon(
                  isDone ? Icons.check_circle : Icons.circle_outlined,
                  color: isDone ? Colors.grey : color,
                  size: 24,
                ),
              ),
            ],
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

// Helper classes for dynamic timeline layout
abstract class _TimelineSegment {
  final DateTime startTime;
  final DateTime endTime;
  final bool isCompact;

  static const double minTaskHeight = 40.0;
  double get basePixelsPerMinute => isCompact ? (80.0 / 60.0) : (140.0 / 60.0);
  static const double minFreeTimeHeight = 20.0;
  double get collapsedFreeTimeHeight => isCompact ? 50.0 : 70.0;
  double get freeTimeCollapseThresholdMinutes => isCompact ? 180 : 240;

  _TimelineSegment(this.startTime, this.endTime, this.isCompact);

  int get durationInMinutes => endTime.difference(startTime).inMinutes;
  double get height;
  double get pixelsPerMinute;

  Widget buildWidget(BuildContext context, double timeLineWidth);
}

class _TaskBlockSegment extends _TimelineSegment {
  final List<Task> tasks;
  late final double _pixelsPerMinute;
  late final double _height;

  _TaskBlockSegment(
    DateTime startTime,
    DateTime endTime,
    this.tasks,
    bool isCompact,
  ) : super(startTime, endTime, isCompact) {
    double maxNeededPpm = basePixelsPerMinute;

    for (var task in tasks) {
      final duration =
          (task.endTime ?? task.startTime!.add(const Duration(minutes: 30)))
              .difference(task.startTime!)
              .inMinutes;
      if (duration <= 0) continue;

      double neededHeight = _TimelineSegment.minTaskHeight;
      if (!isCompact) {
        // In regular mode, content defines min height
        // Title (~20) + Padding (16)
        neededHeight = 40;
        if (task.description.isNotEmpty) {
          neededHeight += 25; // space for description
        }
        if (task.subtasks.isNotEmpty) {
          neededHeight += 20; // space for subtask progress
        }
      }

      final neededPpm = neededHeight / duration;
      if (neededPpm > maxNeededPpm) {
        maxNeededPpm = neededPpm;
      }
    }

    _pixelsPerMinute = maxNeededPpm;
    _height = (durationInMinutes * _pixelsPerMinute).clamp(
      isCompact ? _TimelineSegment.minTaskHeight : 60.0,
      double.infinity,
    );
  }

  @override
  double get height => _height;
  @override
  double get pixelsPerMinute => _pixelsPerMinute;

  @override
  Widget buildWidget(BuildContext context, double timeLineWidth) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: timeLineWidth,
                height: 0,
                child: OverflowBox(
                  minHeight: 40,
                  maxHeight: 40,
                  child: Center(
                    child: Text(
                      DateFormat('HH:mm').format(startTime),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[100]!)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FreeTimeSegment extends _TimelineSegment {
  _FreeTimeSegment(DateTime startTime, DateTime endTime, bool isCompact)
    : super(startTime, endTime, isCompact);

  @override
  double get pixelsPerMinute =>
      durationInMinutes > 0 ? height / durationInMinutes : 0;

  @override
  double get height {
    if (durationInMinutes > freeTimeCollapseThresholdMinutes) {
      return collapsedFreeTimeHeight;
    }
    final calculatedHeight = durationInMinutes * basePixelsPerMinute;
    return calculatedHeight.clamp(
      _TimelineSegment.minFreeTimeHeight,
      collapsedFreeTimeHeight,
    );
  }

  @override
  Widget buildWidget(BuildContext context, double timeLineWidth) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: timeLineWidth,
                height: 0,
                child: OverflowBox(
                  minHeight: 40,
                  maxHeight: 40,
                  child: Center(
                    child: Text(
                      DateFormat('HH:mm').format(startTime),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: Container()),
            ],
          ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[100]!)),
                  ),
                ),
              ),
            ],
          ),
          if (durationInMinutes > 30)
            Positioned.fill(
              left: timeLineWidth,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  durationInMinutes >= 60
                      ? '${durationInMinutes ~/ 60}h ${durationInMinutes % 60}min free'
                      : '$durationInMinutes min free',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
