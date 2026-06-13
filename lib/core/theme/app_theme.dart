import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  // Material 3 dark theme with custom Minecraft-styled color palette
  static ThemeData build() {
    const colors = AppColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.surface,
      cardColor: colors.surface,
      dividerColor: colors.divider,

      // Define semantic colors for consistent UI elements
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: colors.primary,
        onPrimary: colors.background,
        secondary: colors.primaryMuted,
        onSecondary: colors.primary,
        error: colors.danger,
        onError: colors.background,
        surface: colors.surface,
        onSurface: colors.textHigh,
        surfaceContainerHighest: colors.surfaceElevated,
        outline: colors.divider,
      ),

      textTheme: AppTypography.buildTextTheme(colors.textHigh),

      iconTheme: const IconThemeData(
        color: Color(0xFFADB5C7),
        size: AppSpacing.iconMd,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: colors.textHigh,
        ),
        iconTheme: IconThemeData(color: colors.textMed),
      ),

      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: colors.glassBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.glassBorder, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.glass,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.px12,
          vertical: AppSpacing.px10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.glassBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.glassBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.danger, width: 1),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: colors.textLow),
        labelStyle: AppTypography.labelLarge.copyWith(color: colors.textMed),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor:
            WidgetStateProperty.all(colors.textLow.withValues(alpha: 0.4)),
        radius: const Radius.circular(AppSpacing.radiusFull),
        thickness: WidgetStateProperty.all(4),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: colors.glassBorder),
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: colors.textHigh),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.px8,
          vertical: AppSpacing.px4,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.glass,
        linearMinHeight: 3,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.glass,
        thumbColor: colors.primary,
        overlayColor: colors.primaryMuted,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: colors.textHigh),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: colors.glassBorder, width: 1),
        ),
      ),

      extensions: const <ThemeExtension<dynamic>>[
        AppColors.dark,
      ],
    );
  }
}
