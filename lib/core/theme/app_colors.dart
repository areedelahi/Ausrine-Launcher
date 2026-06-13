import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.glass,
    required this.glassBorder,
    required this.primary,
    required this.primaryHover,
    required this.primaryMuted,
    required this.danger,
    required this.dangerMuted,
    required this.warn,
    required this.warnMuted,
    required this.success,
    required this.textHigh,
    required this.textMed,
    required this.textLow,
    required this.textDisabled,
    required this.sidebarBg,
    required this.sidebarSelected,
    required this.divider,

    required this.vanilla,
    required this.fabric,
    required this.quilt,
    required this.forge,
    required this.neoforge,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color glass;
  final Color glassBorder;
  final Color primary;
  final Color primaryHover;
  final Color primaryMuted;
  final Color danger;
  final Color dangerMuted;
  final Color warn;
  final Color warnMuted;
  final Color success;
  final Color textHigh;
  final Color textMed;
  final Color textLow;
  final Color textDisabled;
  final Color sidebarBg;
  final Color sidebarSelected;
  final Color divider;
  final Color vanilla;
  final Color fabric;
  final Color quilt;
  final Color forge;
  final Color neoforge;

  static const AppColors dark = AppColors(
    background: Color(0xFF0C0E13),
    surface: Color(0xFF12151C),
    surfaceElevated: Color(0xFF181C26),
    glass: Color(0x0FFFFFFF), 
    glassBorder: Color(0x1AFFFFFF), 
    primary: Color(0xFF4A80FF), 
    primaryHover: Color(0xFF759FFF),
    primaryMuted: Color(0x334A80FF),
    danger: Color(0xFFFF4F6B),
    dangerMuted: Color(0x33FF4F6B),
    warn: Color(0xFFFFBC42),
    warnMuted: Color(0x33FFBC42),
    success: Color(0xFF4FFFB0),
    textHigh: Color(0xFFF2F4F8),
    textMed: Color(0xFFADB5C7),
    textLow: Color(0xFF6B7590),
    textDisabled: Color(0xFF3D4258),
    sidebarBg: Color(0xFF0A0C10),
    sidebarSelected: Color(0xFF1A1F2E),
    divider: Color(0x1AFFFFFF),
    vanilla: Color(0xFF4DFFB0),
    fabric: Color(0xFFD4B896),
    quilt: Color(0xFF9B72CF),
    forge: Color(0xFFE88C30),
    neoforge: Color(0xFFFF5A36),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? glass,
    Color? glassBorder,
    Color? primary,
    Color? primaryHover,
    Color? primaryMuted,
    Color? danger,
    Color? dangerMuted,
    Color? warn,
    Color? warnMuted,
    Color? success,
    Color? textHigh,
    Color? textMed,
    Color? textLow,
    Color? textDisabled,
    Color? sidebarBg,
    Color? sidebarSelected,
    Color? divider,
    Color? vanilla,
    Color? fabric,
    Color? quilt,
    Color? forge,
    Color? neoforge,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      danger: danger ?? this.danger,
      dangerMuted: dangerMuted ?? this.dangerMuted,
      warn: warn ?? this.warn,
      warnMuted: warnMuted ?? this.warnMuted,
      success: success ?? this.success,
      textHigh: textHigh ?? this.textHigh,
      textMed: textMed ?? this.textMed,
      textLow: textLow ?? this.textLow,
      textDisabled: textDisabled ?? this.textDisabled,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      divider: divider ?? this.divider,
      vanilla: vanilla ?? this.vanilla,
      fabric: fabric ?? this.fabric,
      quilt: quilt ?? this.quilt,
      forge: forge ?? this.forge,
      neoforge: neoforge ?? this.neoforge,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerMuted: Color.lerp(dangerMuted, other.dangerMuted, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnMuted: Color.lerp(warnMuted, other.warnMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      textHigh: Color.lerp(textHigh, other.textHigh, t)!,
      textMed: Color.lerp(textMed, other.textMed, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarSelected: Color.lerp(sidebarSelected, other.sidebarSelected, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      vanilla: Color.lerp(vanilla, other.vanilla, t)!,
      fabric: Color.lerp(fabric, other.fabric, t)!,
      quilt: Color.lerp(quilt, other.quilt, t)!,
      forge: Color.lerp(forge, other.forge, t)!,
      neoforge: Color.lerp(neoforge, other.neoforge, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
