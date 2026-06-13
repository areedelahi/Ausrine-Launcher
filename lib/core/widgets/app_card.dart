import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.isSelected = false,
    this.isHoverable = true,
    this.blurSigma = 12.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool isSelected;
  final bool isHoverable;
  final double blurSigma;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;

  late AnimationController _controller;
  late Animation<double> _elevationAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _elevationAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = widget.borderRadius ?? AppSpacing.radiusMd;

    return MouseRegion(
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: widget.isHoverable
          ? (_) {
              setState(() => _hovered = true);
              _controller.forward();
            }
          : null,
      onExit: widget.isHoverable
          ? (_) {
              setState(() => _hovered = false);
              _controller.reverse();
            }
          : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _elevationAnim,
          builder: (context, child) {
            final hoverFactor = _elevationAnim.value;
            final isActive = widget.isSelected || _hovered;

            return ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      widget.padding ?? const EdgeInsets.all(AppSpacing.px16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.glass.withValues(
                            alpha: (hoverFactor * 0.06) +
                                (widget.isSelected ? 0.06 : 0),
                          )
                        : colors.glass,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: widget.isSelected
                          ? colors.primary.withValues(alpha: 0.5)
                          : isActive
                              ? colors.glassBorder.withValues(alpha: 0.4)
                              : colors.glassBorder,
                      width: widget.isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.15 + hoverFactor * 0.1,
                        ),
                        blurRadius: 16 + hoverFactor * 8,
                        offset: Offset(0, 4 + hoverFactor * 4),
                      ),
                      if (widget.isSelected)
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          spreadRadius: -2,
                        ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
