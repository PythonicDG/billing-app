import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F2C59); // Zoho corporate slate blue
  static const Color accentColor = Color(0xFF006FDF); // Zoho active primary blue
  static const Color backgroundColor = Color(0xFFF5F7FA); // Zoho light grey panel background
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B); // Slate-800
  static const Color subtitleColor = Color(0xFF64748B); // Slate-500
  static const Color borderColor = Color(0xFFD1D5DB); // Zoho clean border grey

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: borderColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: cardColor,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme.copyWith(
        bodyLarge: const TextStyle(color: textColor, fontSize: 14),
        bodyMedium: const TextStyle(color: textColor, fontSize: 13),
        titleMedium: const TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      labelStyle: const TextStyle(color: subtitleColor, fontSize: 13.5),
    ),
  );
}
