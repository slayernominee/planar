import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dayplanner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN seriesId TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN iconCodePoint INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN reminderMinutes INTEGER');
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const boolType = 'INTEGER NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const integerNullableType = 'INTEGER';

    await db.execute('''
CREATE TABLE tasks (
  id $idType,
  title $textType,
  description $textType,
  date $textType,
  startTime $textNullableType,
  endTime $textNullableType,
  isDone $boolType,
  recurrence $integerType,
  colorValue $integerType,
  seriesId $textNullableType,
  iconCodePoint $integerNullableType,
  reminderMinutes $integerNullableType
)
''');

    await db.execute('''
CREATE TABLE subtasks (
  id $idType,
  title $textType,
  isDone $boolType,
  taskId $textType,
  FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
)
''');
  }

  Future<void> createTask(Task task) async {
    final db = await instance.database;

    await db.insert('tasks', task.toMap());

    for (var subtask in task.subtasks) {
      await db.insert('subtasks', subtask.toMap());
    }
  }

  Future<Task> readTask(String id) async {
    final db = await instance.database;

    final maps = await db.query(
      'tasks',
      columns: null,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final task = Task.fromMap(maps.first);
      final subtasks = await readSubtasks(task.id);
      task.subtasks = subtasks;
      return task;
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Subtask>> readSubtasks(String taskId) async {
    final db = await instance.database;

    final result = await db.query(
      'subtasks',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );

    return result.map((json) => Subtask.fromMap(json)).toList();
  }

  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    const orderBy = 'startTime ASC';
    final result = await db.query('tasks', orderBy: orderBy);

    List<Task> tasks = result.map((json) => Task.fromMap(json)).toList();

    for (var task in tasks) {
      task.subtasks = await readSubtasks(task.id);
    }

    return tasks;
  }

  Future<List<Task>> readTasksByDate(DateTime date) async {
    final db = await instance.database;
    const orderBy = 'startTime ASC';

    // We store dates as ISO8601 strings.
    // To match a specific day, we can filter where date string starts with YYYY-MM-DD
    // However, since we store the exact DateTime object in the 'date' field in toMap(),
    // it will be 2023-10-27T00:00:00.000 (if we normalize) or some specific time.
    // The Task model has a 'date' field which likely represents the "day" the task is planned for.
    // Let's assume the app logic normalizes this date to midnight for query comparison or we compare ranges.

    // For simplicity and performance, assume `date` field in DB stores the start of the day.
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();

    final result = await db.query(
      'tasks',
      where: 'date LIKE ?',
      whereArgs: ['${dateStr.split('T')[0]}%'],
      orderBy: orderBy
    );

    List<Task> tasks = result.map((json) => Task.fromMap(json)).toList();

    for (var task in tasks) {
      task.subtasks = await readSubtasks(task.id);
    }

    return tasks;
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;

    int result = await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    // For subtasks, it's easier to delete all and recreate them, or complex diffing.
    // Given the scale, deleting and re-inserting is acceptable.
    await db.delete('subtasks', where: 'taskId = ?', whereArgs: [task.id]);

    for (var subtask in task.subtasks) {
      await db.insert('subtasks', subtask.toMap());
    }

    return result;
  }

  Future<int> updateSubtask(Subtask subtask) async {
    final db = await instance.database;

    return await db.update(
      'subtasks',
      subtask.toMap(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await instance.database;

    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> exportDatabase() async {
    final tasks = await readAllTasks();
    final List<Map<String, dynamic>> jsonData = [];

    for (var task in tasks) {
      final taskMap = task.toMap();
      taskMap['subtasks'] = task.subtasks.map((s) => s.toMap()).toList();
      jsonData.add(taskMap);
    }

    final String jsonString = jsonEncode(jsonData);
    final List<int> bytes = utf8.encode(jsonString);

    await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: 'dayplanner_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<bool> importDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        List<dynamic> jsonData = jsonDecode(content);

        final db = await instance.database;

        await db.transaction((txn) async {
          // Foreign keys ON DELETE CASCADE will handle subtasks, but manual clear is safer
          await txn.delete('subtasks');
          await txn.delete('tasks');

          for (var taskData in jsonData) {
            Map<String, dynamic> taskMap = Map<String, dynamic>.from(taskData);
            List<dynamic> subtasksData = taskMap.remove('subtasks') ?? [];

            await txn.insert('tasks', taskMap);
            for (var subtaskData in subtasksData) {
              await txn.insert('subtasks', Map<String, dynamic>.from(subtaskData));
            }
          }
        });
        return true;
      }
    } catch (e) {
      // Import failed
    }
    return false;
  }
}
