import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initMaximized() async {
    final max = await windowManager.isMaximized();
    if (mounted) setState(() => _isMaximized = max);
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMac = Platform.isMacOS;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: AppSpacing.titleBarHeight,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [

            if (widget.title != null)
              Text(
                widget.title!,
                style: AppTypography.titleSmall.copyWith(
                  color: colors.textMed,
                  fontSize: AppTypography.sm,
                ),
              ),

            Positioned(
              left: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMac) ...[
                    const SizedBox(width: AppSpacing.px8),
                    _MacTrafficLights(isMaximized: _isMaximized),
                    const SizedBox(width: AppSpacing.px8),
                  ],
                  if (widget.leading != null) widget.leading!,
                ],
              ),
            ),

            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.trailing != null) widget.trailing!,
                  if (!isMac) ...[
                    _WinButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Minimize',
                      onTap: windowManager.minimize,
                    ),
                    _WinButton(
                      icon: _isMaximized
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      tooltip: _isMaximized ? 'Restore' : 'Maximize',
                      onTap: () async {
                        if (_isMaximized) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      },
                    ),
                    _WinButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      isDanger: true,
                      onTap: windowManager.close,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacTrafficLights extends StatefulWidget {
  const _MacTrafficLights({required this.isMaximized});
  final bool isMaximized;

  @override
  State<_MacTrafficLights> createState() => _MacTrafficLightsState();
}

class _MacTrafficLightsState extends State<_MacTrafficLights> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TrafficLight(
            color: const Color(0xFFFF5F57),
            hoverIcon: Icons.close_rounded,
            isHovered: _hovered,
            onTap: windowManager.close,
            tooltip: 'Close',
          ),
          const SizedBox(width: AppSpacing.px6),
          _TrafficLight(
            color: const Color(0xFFFFBD2E),
            hoverIcon: Icons.remove_rounded,
            isHovered: _hovered,
            onTap: windowManager.minimize,
            tooltip: 'Minimize',
          ),
          const SizedBox(width: AppSpacing.px6),
          _TrafficLight(
            color: const Color(0xFF28CA41),
            hoverIcon: widget.isMaximized
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            isHovered: _hovered,
            onTap: () async {
              if (widget.isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            tooltip: widget.isMaximized ? 'Restore' : 'Zoom',
          ),
        ],
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  const _TrafficLight({
    required this.color,
    required this.hoverIcon,
    required this.isHovered,
    required this.onTap,
    required this.tooltip,
  });

  final Color color;
  final IconData hoverIcon;
  final bool isHovered;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: isHovered
              ? Icon(hoverIcon,
                  size: 8, color: Colors.black.withValues(alpha: 0.7))
              : null,
        ),
      ),
    );
  }
}

class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isDanger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool isDanger;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 46,
            height: AppSpacing.titleBarHeight,
            color: _hovered
                ? (widget.isDanger ? const Color(0xFFE81123) : colors.glass)
                : Colors.transparent,
            child: Icon(
              widget.icon,
              size: AppSpacing.iconSm,
              color:
                  _hovered && widget.isDanger ? Colors.white : colors.textMed,
            ),
          ),
        ),
      ),
    );
  }
}
