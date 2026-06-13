import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, ghost, danger, outline }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum AppButtonSize { small, medium, large }

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    _controller.forward();
  }

  void _onTapUp(_) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    final (bgColor, fgColor, borderColor) = _resolveColors(colors, isDisabled);
    final (height, hPad, fontSize) = _resolveSize();

    return MouseRegion(
      cursor:
          isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: isDisabled ? null : _onTapDown,
        onTapUp: isDisabled ? null : _onTapUp,
        onTapCancel: isDisabled ? null : _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: height,
                width: widget.isFullWidth ? double.infinity : null,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                decoration: BoxDecoration(
                  color: _hovered && !isDisabled
                      ? _hoverBg(bgColor, colors)
                      : bgColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: _hovered && !isDisabled
                        ? borderColor.withValues(alpha: 0.9)
                        : borderColor,
                    width: 1.0,
                  ),
                  boxShadow: widget.variant == AppButtonVariant.primary &&
                          _hovered &&
                          !isDisabled
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisSize:
                  widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fgColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.px8),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 15, color: fgColor),
                  const SizedBox(width: AppSpacing.px6),
                ],
                Text(
                  widget.label,
                  style: AppTypography.labelLarge.copyWith(
                    color: fgColor,
                    fontSize: fontSize,
                  ),
                ),
                if (widget.trailingIcon != null) ...[
                  const SizedBox(width: AppSpacing.px6),
                  Icon(widget.trailingIcon, size: 14, color: fgColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color bg, Color fg, Color border) _resolveColors(
    AppColors colors,
    bool disabled,
  ) {
    if (disabled) {
      return (
        colors.glass,
        colors.textDisabled,
        colors.glassBorder,
      );
    }
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return (colors.primary, colors.background, Colors.transparent);
      case AppButtonVariant.ghost:
        return (Colors.transparent, colors.textMed, Colors.transparent);
      case AppButtonVariant.danger:
        return (
          colors.dangerMuted,
          colors.danger,
          colors.danger.withValues(alpha: 0.4)
        );
      case AppButtonVariant.outline:
        return (colors.glass, colors.textHigh, colors.glassBorder);
    }
  }

  Color _hoverBg(Color base, AppColors colors) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return colors.primaryHover;
      case AppButtonVariant.ghost:
        return colors.glass;
      case AppButtonVariant.danger:
        return colors.danger.withValues(alpha: 0.25);
      case AppButtonVariant.outline:
        return colors.surfaceElevated;
    }
  }

  (double height, double hPad, double fontSize) _resolveSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return (28, AppSpacing.px10, AppTypography.xs);
      case AppButtonSize.medium:
        return (36, AppSpacing.px16, AppTypography.sm);
      case AppButtonSize.large:
        return (44, AppSpacing.px24, AppTypography.base);
    }
  }
}
