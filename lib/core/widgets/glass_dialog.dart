import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class GlassDialog extends StatefulWidget {
  const GlassDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.width = 480,
    this.icon,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double width;
  final IconData? icon;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    double width = 480,
    IconData? icon,
  }) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) => GlassDialog(
        title: title,
        icon: icon,
        width: width,
        actions: actions,
        child: child,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<GlassDialog> createState() => _GlassDialogState();
}

class _GlassDialogState extends State<GlassDialog> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: widget.width,
              constraints: const BoxConstraints(maxHeight: 640),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: colors.glassBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.px24,
                      AppSpacing.px20,
                      AppSpacing.px16,
                      AppSpacing.px16,
                    ),
                    child: Row(
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: AppSpacing.iconLg,
                            color: colors.primary,
                          ),
                          const SizedBox(width: AppSpacing.px12),
                        ],
                        Expanded(
                          child: Text(
                            widget.title,
                            style: AppTypography.titleLarge.copyWith(
                              color: colors.textHigh,
                            ),
                          ),
                        ),
                        _CloseButton(onTap: () => Navigator.pop(context)),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: colors.divider),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.px24),
                      child: widget.child,
                    ),
                  ),

                  if (widget.actions != null) ...[
                    Divider(height: 1, color: colors.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.px24,
                        vertical: AppSpacing.px16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: widget.actions!
                            .map((a) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.px8,
                                  ),
                                  child: a,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered ? colors.glass : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: colors.textMed,
          ),
        ),
      ),
    );
  }
}
