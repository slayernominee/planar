import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clearDatabase(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text(
          'Are you sure you want to delete all tasks? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // We can drop the tables and recreate them, or just delete all rows
      final db = await DatabaseHelper.instance.database;
      await db.delete('tasks');
      await db.delete('subtasks');

      // Reload current day tasks
      if (context.mounted) {
        final now = DateTime.now();
        final provider = context.read<TaskProvider>();
        provider.clearCache();
        provider.loadTasksForDate(now);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database cleared')),
        );
      }
    }
  }

  Future<void> _addSampleTasks(BuildContext context) async {
    final now = DateTime.now();
    final provider = context.read<TaskProvider>();

    final samples = [
      Task(
        title: 'Morning Exercise',
        description: '30 mins of yoga',
        date: now,
        startTime: DateTime(now.year, now.month, now.day, 8, 0),
        endTime: DateTime(now.year, now.month, now.day, 8, 30),
        colorValue: Colors.orange.value,
        iconCodePoint: Icons.fitness_center.codePoint,
      ),
      Task(
        title: 'Team Meeting',
        description: 'Sync with the design team',
        date: now,
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        endTime: DateTime(now.year, now.month, now.day, 11, 0),
        colorValue: Colors.blue.value,
        iconCodePoint: Icons.group.codePoint,
      ),
      Task(
        title: 'Lunch Break',
        date: now,
        startTime: DateTime(now.year, now.month, now.day, 12, 30),
        endTime: DateTime(now.year, now.month, now.day, 13, 30),
        colorValue: Colors.green.value,
        iconCodePoint: Icons.restaurant.codePoint,
      ),
      Task(
        title: 'Deep Work',
        description: 'Focus on core feature implementation',
        date: now,
        startTime: DateTime(now.year, now.month, now.day, 14, 0),
        endTime: DateTime(now.year, now.month, now.day, 16, 0),
        colorValue: Colors.purple.value,
        iconCodePoint: Icons.code.codePoint,
      ),
      Task(
        title: 'Quick Catchup',
        date: now,
        startTime: DateTime(now.year, now.month, now.day, 16, 15),
        endTime: DateTime(now.year, now.month, now.day, 16, 20),
        colorValue: Colors.red.value,
        iconCodePoint: Icons.chat.codePoint,
      ),
    ];

    for (var task in samples) {
      await provider.addTask(task);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('5 Sample tasks added')),
      );
    }
  }

  void _testNotification() {
    NotificationService.instance.showInstantNotification(
      'Developer Test',
      'This is a test notification from the developer menu!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.blue),
            title: const Text('Export Database'),
            subtitle: const Text('Save your tasks to a JSON file'),
            onTap: () async {
              await DatabaseHelper.instance.exportDatabase();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline, color: Colors.green),
            title: const Text('Import Database'),
            subtitle: const Text('Restore tasks from a backup file'),
            onTap: () async {
              final success = await DatabaseHelper.instance.importDatabase();
              if (success && context.mounted) {
                final provider = context.read<TaskProvider>();
                provider.clearCache();
                provider.loadTasksForDate(DateTime.now());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database imported successfully')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Clear Database',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Delete all tasks and data'),
            onTap: () => _clearDatabase(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Developer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('Add Sample Tasks'),
            subtitle: const Text('Insert 5 dummy tasks for today'),
            onTap: () => _addSampleTasks(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.notification_important, color: Colors.purple),
            title: const Text('Test Notification'),
            subtitle: const Text('Send an instant notification'),
            onTap: _testNotification,
          ),
          ListTile(
            leading: const Icon(Icons.timer, color: Colors.blueGrey),
            title: const Text('Test Scheduled Task'),
            subtitle: const Text('Schedule a reminder for 10 seconds from now'),
            onTap: () async {
              await NotificationService.instance.testTaskNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Test task scheduled for 10s from now')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.hourglass_bottom, color: Colors.blue),
            title: const Text('Test Delayed Notification'),
            subtitle:
                const Text('Wait 5s in code then show instant notification'),
            onTap: () async {
              await NotificationService.instance.testDelayedNotification();
            },
          ),
          const Divider(),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : 'Loading...';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                subtitle: Text(
                    'Version $version\nAuthor: slayernominee\nGitHub: https://github.com/slayernominee/planar'),
                isThreeLine: true,
                onTap: () async {
                  final url = Uri.parse('https://github.com/slayernominee/planar');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
