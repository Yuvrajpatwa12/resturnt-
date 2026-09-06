import 'package:flutter/material.dart';

class AdminTheme {
  static const Color pearlWhite = Color(0xFFF8FAFC);
  static const Color royalBlue = Color(0xFF0047AB);
  static const Color darkNavy = Color(0xFF002D62);
  static const Color emeraldGreen = Color(0xFF00C49F);
  static const Color pureWhite = Color(0xFFFFFFFF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: pearlWhite,
      primaryColor: royalBlue,
      colorScheme: ColorScheme.light(
        primary: royalBlue,
        secondary: darkNavy,
        surface: pureWhite,
        onPrimary: pureWhite,
        onSecondary: pureWhite,
        onSurface: darkNavy,
        tertiary: emeraldGreen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkNavy,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: darkNavy),
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: royalBlue,
        unselectedLabelColor: Colors.grey,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: pureWhite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];
}
