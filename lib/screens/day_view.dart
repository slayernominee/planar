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

  void _openAddTask({DateTime? startTime}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTaskScreen(
          initialDate: widget.date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final tasks = taskProvider.getTasksFor(widget.date);
        final timedTasks = tasks.where((t) => t.startTime != null).toList();
        timedTasks.sort((a, b) => a.startTime!.compareTo(b.startTime!));

        return Container(
          color: Colors.white, // Light background
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              if (tasks.isEmpty) _buildEmptyState(),
              if (tasks.isNotEmpty) ..._buildTimeline(timedTasks),
              const SizedBox(height: 80), // Padding for FAB
            ],
          ),
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
            Icon(Icons.event_note, size: 60, color: Colors.grey.withOpacity(0.3)),
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

  List<Widget> _buildTimeline(List<Task> tasks) {
    List<Widget> widgets = [];
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    if (isToday && tasks.isNotEmpty && now.isBefore(tasks.first.startTime!)) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildNowLineContent(),
      ));
    }

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final isLast = i == tasks.length - 1;
      final nextTask = isLast ? null : tasks[i + 1];

      // 1. The Task Row
      widgets.add(_buildTaskRow(task));

      // 2. The Gap (Connecting Line + Optional Content)
      if (!isLast) {
        widgets.add(_buildConnector(task, nextTask!));
      }
    }

    if (isToday &&
        tasks.isNotEmpty &&
        now.isAfter(tasks.last.endTime ?? tasks.last.startTime!)) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 16),
        child: _buildNowLineContent(),
      ));
    }

    return widgets;
  }

  Widget _buildNowLineContent() {
    return Row(
      children: [
        SizedBox(
          width: 45,
          child: Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 8),
        const SizedBox(
          width: 30,
          child: Center(
            child: CircleAvatar(
              radius: 4,
              backgroundColor: Colors.red,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 2,
            color: Colors.red.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskRow(Task task) {
    final startTime = DateFormat('HH:mm').format(task.startTime!);
    final endTime = task.endTime != null ? DateFormat('HH:mm').format(task.endTime!) : '';
    final duration = task.endTime?.difference(task.startTime!).inMinutes ?? 0;

    // Calculate height logic
    // 1 minute = 1.5 logical pixels, but clamped between 50 and 400
    double durationHeight = 50;
    if (task.endTime != null) {
      durationHeight = (duration * 1.5).clamp(50.0, 400.0);
    }

    // Icon Logic
    final iconData = task.iconCodePoint != null
        ? IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons')
        : Icons.event;

    final color = Color(task.colorValue);
    final isRecurring = task.seriesId != null;
    final isDone = task.isDone;

    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
    final isNowInTask = isToday &&
        now.isAfter(task.startTime!) &&
        (task.endTime == null || now.isBefore(task.endTime!));

    Widget rowContent = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Time Label
          SizedBox(
            width: 45,
            child: Column(
              mainAxisAlignment: (duration >= 5 && task.endTime != null)
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      top: (duration >= 5 && task.endTime != null) ? 13.0 : 0),
                  child: Text(
                    startTime,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (duration >= 5 && task.endTime != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 13.0),
                    child: Text(
                      endTime,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Center: Node
          SizedBox(
            width: 30,
            child: Column(
              children: [
                if (duration >= 5 && task.endTime != null)
                  Container(
                    width: 2,
                    height: 14,
                    color: Colors.grey.withOpacity(0.2),
                  )
                else
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
                if (duration >= 5 && task.endTime != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 14,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: Task Details (Styled Card)
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddTaskScreen(
                      initialDate: widget.date,
                      taskToEdit: task,
                    ),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: durationHeight),
                child: Container(
                  margin: const EdgeInsets.only(top: 19, bottom: 19),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.grey[100] : color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: isDone ? Colors.grey : color,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Opacity(
                    opacity: isDone ? 0.6 : 1.0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(iconData, color: color, size: 24),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time Range
                              Row(
                                children: [
                                  Text(
                                    duration >= 5 && task.endTime != null ? '$startTime - $endTime' : startTime,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      decoration:
                                          isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (isRecurring) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.repeat,
                                        size: 14, color: Colors.black.withOpacity(0.5)),
                                  ],

                                ],
                              ),
                              const SizedBox(height: 4),
                              // Title
                              Text(
                                task.title,
                                style: TextStyle(
                                  color: isDone ? Colors.black54 : Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  decoration:
                                      task.isDone ? TextDecoration.lineThrough : null,
                                  decorationColor: Colors.black54,
                                ),
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              if (task.subtasks.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.checklist,
                                        size: 14, color: Colors.black54),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.subtasks.where((s) => s.isDone).length}/${task.subtasks.length}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            final updated = task.copyWith(isDone: !task.isDone);
                            context.read<TaskProvider>().updateTask(updated);
                          },
                          child: Icon(
                            task.isDone
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: task.isDone ? Colors.grey : color,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isNowInTask) {
      final minutesFromStart = now.difference(task.startTime!).inMinutes;
      final topOffset = (duration >= 5 && task.endTime != null)
          ? (minutesFromStart * 1.5 + 19).clamp(19.0, durationHeight + 19)
          : (durationHeight / 2 + 19);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          rowContent,
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _buildNowLineContent()),
          ),
        ],
      );
    }

    return rowContent;
  }

  Widget _buildConnector(Task current, Task next) {
    if (current.endTime == null || next.startTime == null) {
      return const SizedBox.shrink();
    }

    final gap = next.startTime!.difference(current.endTime!);
    if (gap.inMinutes <= 0) {
      return const SizedBox.shrink();
    }

    // 1 minute = 1.5 logical pixels, but clamped to reasonable values (max 2h)
    final gapHeight = (gap.inMinutes * 1.5).clamp(20.0, 180.0);

    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
    final isNowInGap = isToday &&
        now.isAfter(current.endTime!) &&
        now.isBefore(next.startTime!);

    Widget connector = SizedBox(
      height: gapHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 45 + 8), // Indent for Node column

          // The Line Column
          SizedBox(
            width: 30,
            child: Center(
              child: CustomPaint(
                size: const Size(2, double.infinity),
                painter: DashedLinePainter(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // The Content in the Gap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (gap.inMinutes >= 15) ...[
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 6),
                      Text(
                        '${gap.inHours > 0 ? '${gap.inHours}h ' : ''}${gap.inMinutes % 60}m free',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (isNowInGap) {
      final minutesFromEnd = now.difference(current.endTime!).inMinutes;
      final topOffset = (minutesFromEnd * 1.5).clamp(0.0, gapHeight);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          connector,
          Positioned(
            top: topOffset,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _buildNowLineContent()),
          ),
        ],
      );
    }

    return connector;
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const double dashHeight = 4;
    const double dashSpace = 4;
    double startY = 0;

    final x = size.width / 2;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
