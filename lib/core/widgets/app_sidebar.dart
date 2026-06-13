import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.routePath,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String routePath;
  final String? badge;
}

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedPath,
    required this.onItemTap,
    this.header,
    this.footer,
  });

  final List<SidebarItem> items;
  final String selectedPath;
  final ValueChanged<SidebarItem> onItemTap;
  final Widget? header;
  final Widget? footer;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  bool _hoverExpanded = false;
  bool _pinned = false;

  bool get _expanded => _pinned || _hoverExpanded;

  late AnimationController _controller;
  late Animation<double> _widthAnim;

  static const _pinKey = 'sidebar_pinned_state';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _widthAnim = Tween<double>(
      begin: AppSpacing.sidebarWidth,
      end: AppSpacing.sidebarExpandedWidth,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _loadPinnedState();
  }

  Future<void> _loadPinnedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPinned = prefs.getBool(_pinKey) ?? false;
      if (isPinned && mounted) {
        setState(() {
          _pinned = true;

          _controller.value = 1.0;
        });
      }
    } catch (_) {

    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    if (_pinned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _hoverExpanded = true);
      _controller.forward();
    });
  }

  void _onHoverExit() {
    if (_pinned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _hoverExpanded = false);
      _controller.reverse();
    });
  }

  Future<void> _togglePin() async {
    setState(() {
      _pinned = !_pinned;
      _hoverExpanded = false;
    });
    if (_pinned) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pinKey, _pinned);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: AnimatedBuilder(
        animation: _widthAnim,
        builder: (context, child) {
          return SizedBox(
            width: _widthAnim.value,
            child: ColoredBox(color: colors.sidebarBg, child: child),
          );
        },
        child: Column(
          children: [

            _HamburgerButton(
              expanded: _expanded,
              pinned: _pinned,
              onTap: _togglePin,
            ),

            if (widget.header != null) widget.header!,

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.px4,
                  horizontal: AppSpacing.px12,
                ),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.px2),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = item.routePath == widget.selectedPath;
                  return _SidebarNavItem(
                    item: item,
                    isSelected: isSelected,
                    isExpanded: _expanded,
                    onTap: () => widget.onItemTap(item),
                  );
                },
              ),
            ),

            if (widget.footer != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.px8,
                  horizontal: AppSpacing.px12,
                ),
                child: widget.footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class _HamburgerButton extends StatefulWidget {
  const _HamburgerButton({
    required this.expanded,
    required this.pinned,
    required this.onTap,
  });
  final bool expanded;
  final bool pinned;
  final VoidCallback onTap;

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.px12, AppSpacing.px8, AppSpacing.px12, AppSpacing.px4),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hovered = true);
          }),
          onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hovered = false);
          }),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hovered ? colors.sidebarSelected : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Center(
                child: Icon(
                  Icons.menu_rounded,
                  size: AppSpacing.iconMd,
                  color: widget.pinned ? colors.primary : colors.textLow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  final SidebarItem item;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  late AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;

  @override
  void initState() {
    super.initState();
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _indicatorAnim = CurvedAnimation(
      parent: _indicatorCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(_SidebarNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _indicatorCtrl.forward();
      } else {
        _indicatorCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isActive = widget.isSelected || _hovered;

    final iconColor = widget.isSelected
        ? colors.primary
        : _hovered
            ? colors.textHigh
            : colors.textLow;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = true);
      }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hovered = false);
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.isExpanded ? '' : widget.item.label,
          preferBelow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 44,

            width: widget.isExpanded ? double.maxFinite : 44,
            decoration: BoxDecoration(
              color: isActive ? colors.sidebarSelected : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            clipBehavior: Clip.hardEdge,
            child: widget.isExpanded

                ? Stack(
                    alignment: Alignment.centerLeft,
                    children: [

                      Positioned(
                        left: 0,
                        top: 8,
                        bottom: 8,
                        child: AnimatedBuilder(
                          animation: _indicatorAnim,
                          builder: (context, _) => AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 3 * _indicatorAnim.value,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(2),
                                bottomRight: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      OverflowBox(
                        minWidth: AppSpacing.sidebarExpandedWidth -
                            24, 
                        maxWidth: AppSpacing.sidebarExpandedWidth - 24,
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.px12),
                          child: Row(
                            children: [
                              Icon(widget.item.icon,
                                  size: AppSpacing.iconMd, color: iconColor),
                              const SizedBox(width: AppSpacing.px10),
                              Expanded(
                                child: Text(
                                  widget.item.label,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: widget.isSelected
                                        ? colors.textHigh
                                        : colors.textMed,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.item.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.primaryMuted,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    widget.item.badge!,
                                    style: AppTypography.labelSmall
                                        .copyWith(color: colors.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )

                : Center(
                    child: Icon(widget.item.icon,
                        size: AppSpacing.iconMd, color: iconColor),
                  ),
          ),
        ),
      ),
    );
  }
}
