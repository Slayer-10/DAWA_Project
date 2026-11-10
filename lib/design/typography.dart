import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

class DawaTypography {
  static TextStyle display({Color color = DawaColors.text}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle title({Color color = DawaColors.text}) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle section({Color color = DawaColors.text}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
        height: 1.3,
      );

  static TextStyle body({Color color = DawaColors.text, FontWeight weight = FontWeight.w400, double height = 1.45}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle caption({Color color = DawaColors.text2}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.3,
      );

  static TextStyle label({Color color = DawaColors.text2, FontWeight weight = FontWeight.w600}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.1,
      );

  static TextStyle button({Color color = Colors.white, FontWeight weight = FontWeight.w600}) => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.1,
      );

  /// Tabular figures for prices, quantities, distances, numbers
  static TextStyle numeric({
    double size = 15,
    FontWeight weight = FontWeight.w700,
    Color color = DawaColors.text,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Urdu/Arabic styling using Noto Sans Arabic
  static TextStyle urdu({
    double size = 15,
    FontWeight weight = FontWeight.w600,
    Color color = DawaColors.text,
  }) =>
      GoogleFonts.notoSansArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.6,
      );
}
