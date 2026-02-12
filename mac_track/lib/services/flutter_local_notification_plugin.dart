import 'package:day_night_time_picker/lib/state/time.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mac_track/config/constants.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Call this ONCE in main()
Future<void> initializeNotifications() async {
  tz.initializeTimeZones();

  // Ensure local timezone is set correctly
  tz.setLocalLocation(tz.getLocation(tz.local.name));

  const androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const initializationSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );
}

class Reminders {
  static Future<bool> setReminder({
    required String documentId,
    required Time time,
    required String type,
    required String reminderName,
  }) async {
    final now = DateTime.now();

    tz.TZDateTime scheduledTime = tz.TZDateTime.local(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      time.second,
    );

    // If selected time already passed today → schedule next valid occurrence
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Always cancel existing reminder to avoid stacking
    await cancelReminder(documentId);

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails =
        NotificationDetails(android: androidDetails);

    // ONCE reminder
    if (type == AppConstants.reminderOnce) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        documentId.hashCode,
        reminderName,
        "It's time for your reminder!",
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    }

    // REPEATED reminders
    await flutterLocalNotificationsPlugin.zonedSchedule(
      documentId.hashCode,
      reminderName,
      "It's time for your reminder!",
      scheduledTime,
      notificationDetails,
      matchDateTimeComponents: _getDateTimeComponents(type),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    return true;
  }

  static DateTimeComponents? _getDateTimeComponents(String type) {
    switch (type) {
      case AppConstants.reminderDaily:
        return DateTimeComponents.time;

      case AppConstants.reminderWeekly:
        return DateTimeComponents.dayOfWeekAndTime;

      case AppConstants.reminderMonthly:
        return DateTimeComponents.dayOfMonthAndTime;

      case AppConstants.reminderYearly:
        return DateTimeComponents.dateAndTime;

      default:
        return null;
    }
  }

  static Future<void> cancelReminder(String documentId) async {
    await flutterLocalNotificationsPlugin.cancel(
      documentId.hashCode,
    );
  }
}
