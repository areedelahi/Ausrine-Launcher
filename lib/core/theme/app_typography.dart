import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static String get fontFamily => GoogleFonts.inter().fontFamily!;
  static const String monoFontFamily = 'monospace';

  static const double xs = 11.0;
  static const double sm = 12.0;
  static const double base = 13.0;
  static const double md = 14.0;
  static const double lg = 16.0;
  static const double xl = 18.0;
  static const double xl2 = 22.0;
  static const double xl3 = 28.0;
  static const double xl4 = 36.0;

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: xl4,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: xl3,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: xl2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: xl,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: lg,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: md,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
      );

  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: base,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: md,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: base,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: sm,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: sm,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.4,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: xs,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.4,
      );

  static TextStyle get mono => const TextStyle(
        fontFamily: 'monospace',
        fontSize: sm,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.6,
      );

  static TextStyle get monoBold => const TextStyle(
        fontFamily: 'monospace',
        fontSize: sm,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.6,
      );

  static TextStyle get versionBadge => GoogleFonts.inter(
        fontSize: xs,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.0,
      );

  static TextTheme buildTextTheme(Color defaultColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: defaultColor),
      displayMedium: displayMedium.copyWith(color: defaultColor),
      displaySmall: headlineLarge.copyWith(color: defaultColor),
      headlineLarge: headlineLarge.copyWith(color: defaultColor),
      headlineMedium: headlineMedium.copyWith(color: defaultColor),
      headlineSmall: titleLarge.copyWith(color: defaultColor),
      titleLarge: titleLarge.copyWith(color: defaultColor),
      titleMedium: titleMedium.copyWith(color: defaultColor),
      titleSmall: titleSmall.copyWith(color: defaultColor),
      bodyLarge: bodyLarge.copyWith(color: defaultColor),
      bodyMedium: bodyMedium.copyWith(color: defaultColor),
      bodySmall: bodySmall.copyWith(color: defaultColor),
      labelLarge: labelLarge.copyWith(color: defaultColor),
      labelMedium: labelLarge.copyWith(color: defaultColor),
      labelSmall: labelSmall.copyWith(color: defaultColor),
    );
  }
}
