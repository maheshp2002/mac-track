import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/themeManager.dart';
import 'services/defaultFirebaseOption.dart';
import 'services/firebaseService.dart';
import 'services/notification-listener.dart';
import 'splashScreen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final FirebaseService firebaseService = FirebaseService();

  await initializeNotifications((transaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await firebaseService.addNotificationExpense(
        amount: transaction.amount,
        type: transaction.type,
        timestamp: transaction.timestamp,
        userEmail: user.email!,
      );
    }
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        if (!themeManager.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return MaterialApp(
          themeMode: themeManager.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: BotToastInit(),
          navigatorObservers: [BotToastNavigatorObserver()],
          home: const SplashScreen(),
        );
      },
    );
  }
}
