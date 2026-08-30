import 'package:flutter/material.dart';

class WaiterProTheme {
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
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: darkNavy),
      ),
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: pureWhite,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: royalBlue, width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: darkNavy, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: darkNavy, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkNavy),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
    );
  }

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}
