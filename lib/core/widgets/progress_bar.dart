import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppProgressBar extends StatefulWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.label,
    this.height = 6.0,
    this.showShimmer = true,
    this.borderRadius,
  });

  final double? value;
  final String? label;
  final double height;
  final bool showShimmer;
  final double? borderRadius;

  @override
  State<AppProgressBar> createState() => _AppProgressBarState();
}

class _AppProgressBarState extends State<AppProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = widget.borderRadius ?? widget.height / 2;
    final isIndeterminate = widget.value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: AppSpacing.px10,
              color: colors.textLow,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.px4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: widget.height,
            child: isIndeterminate
                ? LinearProgressIndicator(
                    backgroundColor: colors.glass,
                    color: colors.primary,
                    minHeight: widget.height,
                  )
                : Stack(
                    children: [

                      Container(
                        width: double.infinity,
                        height: widget.height,
                        color: colors.glass,
                      ),

                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        widthFactor: widget.value!.clamp(0.0, 1.0),
                        child: Container(
                          height: widget.height,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.8),
                                colors.primary,
                                colors.primaryHover,
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (widget.showShimmer && (widget.value ?? 0) > 0)
                        AnimatedBuilder(
                          animation: _shimmerAnim,
                          builder: (context, _) {
                            return FractionallySizedBox(
                              widthFactor: widget.value!.clamp(0.0, 1.0),
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    begin: Alignment(
                                      _shimmerAnim.value - 0.5,
                                      0,
                                    ),
                                    end: Alignment(
                                      _shimmerAnim.value + 0.5,
                                      0,
                                    ),
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.25),
                                      Colors.transparent,
                                    ],
                                  ).createShader(rect);
                                },
                                child: Container(
                                  height: widget.height,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
