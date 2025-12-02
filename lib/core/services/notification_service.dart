import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings);

    // Request permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Initialize timezone database for zoned scheduling
    tz.initializeTimeZones();

    // Create channel for events
    const channel = AndroidNotificationChannel(
      'events_channel',
      'Event Reminders',
      description: 'Notifications for upcoming events',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> scheduleEventNotification({
    required String id,
    required DateTime dateTime,
    required String title,
    String? body,
  }) async {
    await init();
    if (dateTime.isBefore(DateTime.now())) return; // Skip past time

    const androidDetails = AndroidNotificationDetails(
      'events_channel',
      'Event Reminders',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    final hashId = id.hashCode & 0x7FFFFFFF;

    final tzDateTime = tz.TZDateTime.from(dateTime.toLocal(), tz.local);

    await _plugin.zonedSchedule(
      hashId,
      title,
      body ?? 'Sắp đến thời điểm diễn ra sự kiện',
      tzDateTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  /// Schedule a recurring notification for events following a simple daily/weekly pattern.
  /// Uses matchDateTimeComponents for Android exact scheduling.
  Future<void> scheduleRecurringEventNotification({
    required String id,
    required DateTime dateTime,
    required String recurrencePattern, // 'daily' or 'weekly'
    required String title,
    String? body,
  }) async {
    await init();

    final androidDetails = const AndroidNotificationDetails(
      'events_channel',
      'Event Reminders',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    final hashId = id.hashCode & 0x7FFFFFFF;

    final tzDateTime = tz.TZDateTime.from(dateTime.toLocal(), tz.local);

    DateTimeComponents? match;
    switch (recurrencePattern) {
      case 'daily':
        match = DateTimeComponents.time;
        break;
      case 'weekly':
        match = DateTimeComponents.dayOfWeekAndTime;
        break;
      default:
        match = null;
        break;
    }

    await _plugin.zonedSchedule(
      hashId,
      title,
      body ?? 'Sắp đến thời điểm diễn ra sự kiện',
      tzDateTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: match,
    );
  }

  Future<void> cancelEventNotification(String id) async {
    await init();
    final hashId = id.hashCode & 0x7FFFFFFF;
    await _plugin.cancel(hashId);
  }

  Future<void> showImmediate(
      {required int id, required String title, required String body}) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'events_channel',
      'Event Reminders',
      channelDescription: 'Notifications for upcoming events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details);
  }
}
