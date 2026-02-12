// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'transaction-parser.dart';

// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// Future<void> initializeNotifications(Function(TransactionDetails) onParsed) async {
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');

//   final InitializationSettings initializationSettings =
//       InitializationSettings(android: initializationSettingsAndroid);

//   await flutterLocalNotificationsPlugin.initialize(
//     initializationSettings,
//     onDidReceiveNotificationResponse: (details) {
//       final body = details.payload ?? '';
//       final parsed = TransactionParser.parse(body, DateTime.now());
//       if (parsed != null) {
//         onParsed(parsed);
//       }
//     },
//   );
// }
