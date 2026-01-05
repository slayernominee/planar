import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import '../models/task.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final dynamic timeZone = await FlutterTimezone.getLocalTimezone();
      String? locationName;
      if (timeZone is String) {
        locationName = timeZone;
      } else if (timeZone != null) {
        // The logs show toString() returns "TimezoneInfo(Europe/Berlin, ...)"
        // We need to extract just "Europe/Berlin"
        final String raw = timeZone.toString();
        if (raw.contains('(') && raw.contains(',')) {
          locationName = raw.substring(raw.indexOf('(') + 1, raw.indexOf(',')).trim();
        } else {
          locationName = raw;
        }
      }

      if (kDebugMode) print('NotificationService: Local timezone detected as $locationName');
      tz.setLocalLocation(tz.getLocation(locationName ?? 'UTC'));
    } catch (e) {
      if (kDebugMode) print('NotificationService: Timezone detection failed, using UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    // Request notification permissions
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      // On some versions of the plugin, canScheduleExactAlarms is not available.
      // We will just request the permission directly.
      await androidImplementation.requestExactAlarmsPermission();
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      final macosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>();
      if (macosImplementation != null) {
        await macosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  }

  Future<void> scheduleTaskNotification(Task task) async {
    // Cancel existing notifications for this task
    await cancelTaskNotification(task);

    if (task.reminderMinutes == null || task.startTime == null || task.isDone) {
      if (kDebugMode) {
        print('Notification skipped for task "${task.title}": reminderMinutes=${task.reminderMinutes}, startTime=${task.startTime}, isDone=${task.isDone}');
      }
      return;
    }

    final scheduledTime = task.startTime!.subtract(Duration(minutes: task.reminderMinutes!));
    if (scheduledTime.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('Notification skipped for task "${task.title}": scheduledTime ($scheduledTime) is in the past');
      }
      return;
    }

    // Use a fixed ID for testing to avoid collision issues
    final int notificationId = task.title.contains('Test') ? 12345 : task.id.hashCode;

    if (kDebugMode) {
      print('DEBUG NOTIFICATIONS: Task=${task.title}, ID=$notificationId, Time=$scheduledTime');
    }

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Task Reminder',
        '${task.title} starts in ${task.reminderMinutes} minutes',
        tzTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: task.id,
        matchDateTimeComponents: _getMatchComponents(task.recurrence),
      );
      if (kDebugMode) print('Notification scheduled successfully (Exact)');
    } catch (e) {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Task Reminder',
        '${task.title} starts in ${task.reminderMinutes} minutes',
        tzTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id,
        matchDateTimeComponents: _getMatchComponents(task.recurrence),
      );
      if (kDebugMode) print('Notification scheduled successfully (Inexact)');
    }

    if (kDebugMode) {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('NotificationService: Total pending requests after scheduling: ${pending.length}');
    }
  }

  Future<void> cancelTaskNotification(Task task) async {
    await _notificationsPlugin.cancel(task.id.hashCode);
  }

  Future<void> showInstantNotification(String title, String body) async {
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      _getNotificationDetails(),
    );
  }

  Future<void> testTaskNotification() async {
    final now = DateTime.now();
    final testTask = Task(
      title: 'Test Task (20s)',
      date: now,
      startTime: now.add(const Duration(seconds: 20)),
      reminderMinutes: 0,
    );
    await scheduleTaskNotification(testTask);

    if (kDebugMode) {
      final List<PendingNotificationRequest> pending =
          await _notificationsPlugin.pendingNotificationRequests();
      print('PENDING NOTIFICATIONS: ${pending.length}');
      for (var p in pending) {
        print('  - ID: ${p.id}, Title: ${p.title}');
      }
    }
  }

  Future<void> testDelayedNotification() async {
    if (kDebugMode) print('Starting 5s delay before instant notification...');
    await Future.delayed(const Duration(seconds: 5));
    await showInstantNotification(
      'Delayed Test',
      'This was triggered with a 5s code delay!',
    );
  }

  NotificationDetails _getNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders_v4',
        'Task Reminders',
        channelDescription: 'Notifications for upcoming tasks',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Planar Task Reminder',
        showWhen: true,
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  DateTimeComponents? _getMatchComponents(RecurrenceType recurrence) {
    switch (recurrence) {
      case RecurrenceType.daily:
        return DateTimeComponents.time;
      case RecurrenceType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RecurrenceType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
      case RecurrenceType.none:
      default:
        return null;
    }
  }
}
