import 'package:day_night_time_picker/lib/state/time.dart';
import 'package:mac_track/config/constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

List<String> reminderRepetitions = [
  AppConstants.reminderOnce,
  AppConstants.reminderDaily,
  AppConstants.reminderWeekly,
  AppConstants.reminderMonthly,
  AppConstants.reminderYearly,
  AppConstants.reminderCustom,
];

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  tz.initializeTimeZones();
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);
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

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        documentId.hashCode,
        reminderName,
        'It\'s time for your reminder!',
        scheduledTime,
        const NotificationDetails(android: androidDetails),
        matchDateTimeComponents: _getDateTimeComponents(type),
        androidScheduleMode: AndroidScheduleMode.exact,
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
    await flutterLocalNotificationsPlugin.cancel(documentId.hashCode);
  }
}