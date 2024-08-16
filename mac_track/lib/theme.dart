import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6200EE);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color gradientStart = Color(0xFF000000);
  static const Color gradientMiddle = Color(0xFF1A1A1A);
  static const Color gradientEnd = Color(0xFF333333);
  static const Color primaryGreen = Colors.greenAccent;
  static const Color secondaryGreen = Color(0xFF3BED97);
}

class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16.0,
    color: Colors.black,
  );
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    iconTheme: const IconThemeData(color: Colors.black87),
    primaryColor: AppColors.backgroundLight,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline.copyWith(color: Colors.black87),
      bodyLarge: AppTextStyles.bodyText.copyWith(color: Colors.black87),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor:
          AppColors.backgroundLight, // Light mode drawer background
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    iconTheme: const IconThemeData(color: Colors.white),
    primaryColor: AppColors.backgroundDark,
    scaffoldBackgroundColor:
        AppColors.backgroundDark, // Dark mode scaffold background
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline.copyWith(color: Colors.white),
      bodyLarge: AppTextStyles.bodyText.copyWith(color: Colors.white),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.backgroundDark, // Dark mode drawer background
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );

  static BoxDecoration getBackgroundDecoration(ThemeMode themeMode) {
    return BoxDecoration(
        gradient: themeMode == ThemeMode.dark
            ? const LinearGradient(
                colors: [
                  AppColors.gradientStart,
                  AppColors.gradientMiddle,
                  AppColors.gradientEnd,
                ],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Colors.white, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ));
  }
}
