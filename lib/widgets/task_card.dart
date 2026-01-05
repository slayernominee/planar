import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/add_task_screen.dart';

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final taskColor = Color(task.colorValue);
    final isDone = task.isDone;
    IconData? taskIcon;
    if (task.iconCodePoint != null) {
      taskIcon = IconData(task.iconCodePoint!, fontFamily: 'MaterialIcons');
    }

    // Formatting time
    String timeString = '';
    if (task.startTime != null) {
      timeString = DateFormat('HH:mm').format(task.startTime!);
      if (task.endTime != null) {
        timeString += ' - ${DateFormat('HH:mm').format(task.endTime!)}';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddTaskScreen(
              initialDate: task.date,
              taskToEdit: task,
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isDone ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: taskColor.withOpacity(0.15),
            border: Border(
              left: BorderSide(
                color: taskColor,
                width: 6,
              ),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeString.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text(
                            timeString,
                            style: TextStyle(
                              color: Colors.black87.withOpacity(0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (taskIcon != null) ...[
                            Icon(
                              taskIcon,
                              size: 18,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            task.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (task.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _buildSubtaskProgress(context),
                      ],
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: isDone,
                    shape: const CircleBorder(),
                    activeColor: taskColor,
                    onChanged: (val) {
                      if (val != null) {
                        final updatedTask = task.copyWith(isDone: val);
                        context.read<TaskProvider>().updateTask(updatedTask);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtaskProgress(BuildContext context) {
    int total = task.subtasks.length;
    int done = task.subtasks.where((s) => s.isDone).length;

    return Row(
      children: [
        const Icon(Icons.checklist, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Text(
          '$done/$total',
          style: const TextStyle(
            color: Colors.black45,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
