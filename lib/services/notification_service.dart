import 'dart:developer';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  }

  Future<void> scheduleTaskReminder({
    required String bookingId,
    required String taskTitle,
    required DateTime taskDateTime,
    int minutesBefore = 1,
  }) async {
    DateTime scheduledTime = taskDateTime.subtract(Duration(minutes: minutesBefore));
    DateTime now = DateTime.now();

    if (scheduledTime.isBefore(now)) {
      if (taskDateTime.isAfter(now)) {
        scheduledTime = now.add(const Duration(seconds: 5));
      } else {
        return;
      }
    }

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'booking_reminders',
      'Class Reminders',
      channelDescription: 'Reminders for your dance lessons',
      importance: Importance.max,
      priority: Priority.high,
    );

    int id = _generateStableId(bookingId);

    await _localNotifications.zonedSchedule(
      id,
      'Class Starting Soon!',
      'Your session "$taskTitle" starts in $minutesBefore minute(s)!',
      tzTime,
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    log('🔔 Notification ID: $id set for $tzTime');
  }

  int _generateStableId(String stringId) {
    return stringId.hashCode.abs() % 2147483647;
  }
}