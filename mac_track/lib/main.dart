import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mac_track/services/flutter_local_notification_plugin.dart';
import 'package:mac_track/utils/transaction_semantic_classifier.dart';
import 'package:provider/provider.dart';
import 'ui/components/theme_manager.dart';
import 'services/default_firebase_option.dart';
import 'ui/splash_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeNotifications();
  await TransactionSemanticClassifier.loadDictionary();

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
          debugShowCheckedModeBanner: false,
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
