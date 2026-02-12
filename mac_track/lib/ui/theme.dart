import 'package:flutter/material.dart';

class AppColors {
  static const Color secondary = Color(0xFF03DAC6);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color gradientStart = Color(0xFF000000);
  static const Color gradientMiddle = Color(0xFF1A1A1A);
  static const Color gradientEnd = Color(0xFF333333);
  static const Color primaryGreen = Color(0xFF69F0AE);
  static const Color secondaryGreen = Color(0xFF3BED97);
  static const Color filterButtonBlack = Color(0xFF1e202e);
  static const Color filterButtonWhite = Color(0xFFfbfbfb);
  static const Color filterButtonGreen = Color(0xFF7efa8b);
  static const Color linkColor = Colors.blue;
  static const Color danger = Color(0xFFED3B3B);
  static const Color warning = Color(0xFFED9A3B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black87 = Color(0xDD000000);
  static const Color transparent = Color(0x00000000);
  static const Color purple = Color(0xFF9C27B0);
  static const Color amber = Color(0xFFFFC107);
}

class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontSize: 25.0,
    color: Colors.white,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16.0,
    color: Colors.white,
  );

  static const TextStyle labelTextWhite = TextStyle(
    fontSize: 16.0,
    color: Colors.white,
  );

  static const TextStyle labelTextBlack = TextStyle(
    fontSize: 16.0,
    color: Colors.white,
  );
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color toggleButtonBorderColor;
  final Color toggleButtonFillColor;
  final Color toggleButtonSelectedColor;
  final Color toggleButtonTextColor;
  final Color toggleButtonBackgroundColor;
  final Color modalBackgroundColor;
  final Color chipBackgroundColor;
  final Color dropdownBorderColor;
  final Color dropdownIconColor;

  AppThemeExtension(
      {required this.toggleButtonBorderColor,
      required this.toggleButtonFillColor,
      required this.toggleButtonSelectedColor,
      required this.toggleButtonTextColor,
      required this.toggleButtonBackgroundColor,
      required this.modalBackgroundColor,
      required this.chipBackgroundColor,
      required this.dropdownBorderColor,
      required this.dropdownIconColor});

  @override
  AppThemeExtension copyWith(
      {Color? toggleButtonBorderColor,
      Color? toggleButtonFillColor,
      Color? toggleButtonSelectedColor,
      Color? toggleButtonTextColor,
      Color? toggleButtonBackgroundColor,
      Color? modalBackgroundColor,
      Color? chipBackgroundColor,
      Color? dropdownBorderColor,
      Color? dropdownIconColor}) {
    return AppThemeExtension(
      toggleButtonBorderColor:
          toggleButtonBorderColor ?? this.toggleButtonBorderColor,
      toggleButtonFillColor:
          toggleButtonFillColor ?? this.toggleButtonFillColor,
      toggleButtonSelectedColor:
          toggleButtonSelectedColor ?? this.toggleButtonSelectedColor,
      toggleButtonTextColor:
          toggleButtonTextColor ?? this.toggleButtonTextColor,
      toggleButtonBackgroundColor:
          toggleButtonBackgroundColor ?? this.toggleButtonBackgroundColor,
      modalBackgroundColor: modalBackgroundColor ?? this.modalBackgroundColor,
      chipBackgroundColor: chipBackgroundColor ?? this.chipBackgroundColor,
      dropdownBorderColor: dropdownBorderColor ?? this.dropdownBorderColor,
      dropdownIconColor: dropdownIconColor ?? this.dropdownIconColor,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      toggleButtonBorderColor: Color.lerp(
          toggleButtonBorderColor, other.toggleButtonBorderColor, t)!,
      toggleButtonFillColor:
          Color.lerp(toggleButtonFillColor, other.toggleButtonFillColor, t)!,
      toggleButtonSelectedColor: Color.lerp(
          toggleButtonSelectedColor, other.toggleButtonSelectedColor, t)!,
      toggleButtonTextColor:
          Color.lerp(toggleButtonTextColor, other.toggleButtonTextColor, t)!,
      toggleButtonBackgroundColor: Color.lerp(
          toggleButtonBackgroundColor, other.toggleButtonBackgroundColor, t)!,
      modalBackgroundColor:
          Color.lerp(modalBackgroundColor, other.modalBackgroundColor, t)!,
      chipBackgroundColor:
          Color.lerp(chipBackgroundColor, other.chipBackgroundColor, t)!,
      dropdownBorderColor:
          Color.lerp(dropdownBorderColor, other.dropdownBorderColor, t)!,
      dropdownIconColor:
          Color.lerp(dropdownIconColor, other.dropdownIconColor, t)!,
    );
  }
}

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    extensions: <ThemeExtension<AppThemeExtension>>[
      AppThemeExtension(
          toggleButtonBorderColor: AppColors.primaryGreen,
          toggleButtonFillColor: AppColors.secondaryGreen,
          toggleButtonSelectedColor: Colors.white,
          toggleButtonTextColor: AppColors.primaryGreen,
          toggleButtonBackgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.white70,
          chipBackgroundColor: Colors.white60,
          dropdownBorderColor: AppColors.secondaryGreen,
          dropdownIconColor: AppColors.secondaryGreen),
    ],
    dropdownMenuTheme: const DropdownMenuThemeData(),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.backgroundLight),
    iconTheme: const IconThemeData(color: Colors.black87),
    primaryColor: AppColors.backgroundLight,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    buttonTheme: const ButtonThemeData(buttonColor: AppColors.primaryGreen),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline.copyWith(color: Colors.black87),
      titleLarge:
          AppTextStyles.headline.copyWith(color: Colors.black87, fontSize: 20),
      bodyLarge: AppTextStyles.bodyText.copyWith(color: Colors.black87),
      headlineLarge: AppTextStyles.bodyText.copyWith(
          color: Colors.black87, fontSize: 25, fontWeight: FontWeight.bold),
      displayMedium: AppTextStyles.appBarTitle
          .copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
      labelSmall: AppTextStyles.appBarTitle
          .copyWith(color: Colors.black87, fontSize: 15),
      bodySmall: AppTextStyles.appBarTitle
          .copyWith(color: Colors.black54, fontSize: 12),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.backgroundLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    extensions: <ThemeExtension<AppThemeExtension>>[
      AppThemeExtension(
          toggleButtonBorderColor: Colors.black54,
          toggleButtonFillColor: Colors.grey[800]!,
          toggleButtonSelectedColor: Colors.white,
          toggleButtonTextColor: Colors.white,
          toggleButtonBackgroundColor: Colors.black54,
          modalBackgroundColor: Colors.black12,
          chipBackgroundColor: Colors.black87,
          dropdownBorderColor: Colors.white70,
          dropdownIconColor: Colors.white70),
    ],
    iconTheme: const IconThemeData(color: Colors.white),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.backgroundDark),
    buttonTheme: const ButtonThemeData(buttonColor: AppColors.primaryGreen),
    primaryColor: AppColors.backgroundDark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    textTheme: TextTheme(
      displayLarge: AppTextStyles.headline.copyWith(color: Colors.white),
      titleLarge:
          AppTextStyles.headline.copyWith(color: Colors.white, fontSize: 20),
      bodyLarge: AppTextStyles.bodyText.copyWith(color: Colors.white),
      headlineLarge: AppTextStyles.bodyText.copyWith(
          color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
      displayMedium: AppTextStyles.appBarTitle
          .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      labelSmall:
          AppTextStyles.appBarTitle.copyWith(color: Colors.white, fontSize: 15),
      bodySmall: AppTextStyles.appBarTitle
          .copyWith(color: Colors.white60, fontSize: 12),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.backgroundDark,
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
            ),
    );
  }
}
