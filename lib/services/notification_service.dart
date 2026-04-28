import 'dart:convert';
import 'dart:developer'; // Added for log()
import 'dart:io';        // Added for Platform check
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data; // Changed to latest_all
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NotificationRepository {
  static const String _scheduledNotificationsKey = 'scheduled_notifications';

  Future<void> saveScheduledNotification({
    required String taskId,
    required int notificationId,
    required DateTime scheduledTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getScheduledNotifications();
    notifications[taskId] = {
      'notificationId': notificationId,
      'scheduledTime': scheduledTime.toIso8601String(),
    };
    await prefs.setString(_scheduledNotificationsKey, jsonEncode(notifications));
  }

  Future<Map<String, dynamic>> getScheduledNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_scheduledNotificationsKey);
    if (data == null) return {};
    return jsonDecode(data);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final _NotificationRepository _repository = _NotificationRepository();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    // Manual setup for KL
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await Permission.notification.request();

      // Check for Exact Alarm permission
      if (await Permission.scheduleExactAlarm.isDenied) {
        await openAppSettings();
      }
    }
  }

  Future<void> scheduleTaskReminder({
    required String bookingId,
    required String taskTitle,
    required DateTime taskDateTime,
    int minutesBefore = 10,
  }) async {
    final scheduledTime = taskDateTime.subtract(Duration(minutes: minutesBefore));

    if (scheduledTime.isBefore(DateTime.now())) {
      log('⚠️ Notification time ($scheduledTime) is in the past, skipping.');
      return;
    }

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_reminders',
      'Booking Reminders',
      channelDescription: 'Reminders for your private lessons',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    int id = generateStableId(bookingId);

    await _localNotifications.zonedSchedule(
      id,
      'Class Reminder',
      'Your $taskTitle starts in $minutesBefore minutes!',
      tzTime,
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: bookingId,
    );

    // Save to repository
    await _repository.saveScheduledNotification(
      taskId: bookingId,
      notificationId: id,
      scheduledTime: scheduledTime,
    );

    log('🔔 Booking Reminder set for $tzTime (ID: $id)');
  }

  int generateStableId(String stringId) {
    int hash = 0;
    for (int i = 0; i < stringId.length; i++) {
      hash = 31 * hash + stringId.codeUnitAt(i);
    }
    return hash.abs() % 2147483647;
  }
}