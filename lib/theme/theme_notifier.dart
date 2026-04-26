import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'dresser_theme_mode';

/// Global ValueNotifier for the app's ThemeMode.
/// Call [ThemeNotifier.init] once at startup, then toggle via [ThemeNotifier.toggle].
class ThemeNotifier {
  ThemeNotifier._();

  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kThemeKey) ?? false;
    notifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final isDark = notifier.value == ThemeMode.dark;
    notifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, !isDark);
  }

  static bool get isDark => notifier.value == ThemeMode.dark;
}
