import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static const Color primaryColor = Color(0xFFC67C4E);
  static const Color secondaryColor = Color(0xFFEDD6C8);
  static const Color darkColor = Color(0xFF313131);
  static const Color grayColor = Color(0xFFE3E3E3);

  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF9F9F9),
    useMaterial3: true,
    fontFamily: GoogleFonts.sora().fontFamily,
    textTheme: GoogleFonts.soraTextTheme(),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
  );
}
