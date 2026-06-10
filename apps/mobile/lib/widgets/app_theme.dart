import 'package:flutter/material.dart';

class AppTheme {
  static const Color navy = Color(0xFF1E2A3A);
  static const Color navyLight = Color(0xFF243447);
  static const Color background = Color(0xFFF5F6FA);
  static const Color cardWhite = Colors.white;
  static const Color green = Color(0xFF4CAF50);
  static const Color blue = Color(0xFF2196F3);
  static const Color red = Color(0xFFF44336);
  static const Color purple = Color(0xFF9C27B0);
  static const Color yellow = Color(0xFFF5C518);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color textDark = Color(0xFF1E2A3A);
  static const Color textMid = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        scaffoldBackgroundColor: background,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFEEF0F3)),
          ),
        ),
        useMaterial3: true,
      );

  static List<Color> get chartColors => [green, blue, yellow, red, purple, cyan];
}
