import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData createDawaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DawaColors.purple,
      primary: DawaColors.purple,
      surface: DawaColors.white,
    ),
    scaffoldBackgroundColor: DawaColors.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: DawaColors.text,
      displayColor: DawaColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: DawaColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: DawaColors.text),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: DawaColors.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DawaColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaRadii.input),
        borderSide: const BorderSide(color: DawaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaRadii.input),
        borderSide: const BorderSide(color: DawaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DawaRadii.input),
        borderSide: const BorderSide(color: DawaColors.purple, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(fontSize: 13, color: DawaColors.text2),
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF9CA3AF)),
    ),
    cardTheme: CardThemeData(
      color: DawaColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DawaRadii.card),
        side: const BorderSide(color: DawaColors.border),
      ),
    ),
  );
}
