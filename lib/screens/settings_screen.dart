import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../providers/task_provider.dart';

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
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text(
                'Version 1.1.0\nAuthor: slayernominee\nGitHub: https://github.com/slayernominee/planar'),
            isThreeLine: true,
            onTap: () async {
              final url = Uri.parse('https://github.com/slayernominee/planar');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
