import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  AppThemeService._();

  static const String _prefKey = 'app.theme.darkMode';

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? true;
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _applySystemUi(isDark);
  }

  static Future<void> setDarkMode(bool isDark) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _applySystemUi(isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
  }

  static void _applySystemUi(bool isDark) {
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    final navColor = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF2F5FF);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: navColor,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }
}
