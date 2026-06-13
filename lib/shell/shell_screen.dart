import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../core/widgets/app_sidebar.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'downloads_panel.dart';
import 'launch_bar.dart';
import '../features/downloads/domain/providers/downloads_provider.dart';

const _navItems = [
  SidebarItem(icon: Icons.home_rounded, label: 'Home', routePath: '/'),
  SidebarItem(
      icon: Icons.grid_view_rounded,
      label: 'Instances',
      routePath: '/instances'),
  SidebarItem(
      icon: Icons.person_rounded, label: 'Accounts', routePath: '/accounts'),
  SidebarItem(
      icon: Icons.inventory_2_rounded,
      label: 'Modpacks',
      routePath: '/modpacks'),
  SidebarItem(
      icon: Icons.receipt_long_rounded, label: 'Logs', routePath: '/console'),
];

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final location = GoRouterState.of(context).uri.path;
    final hasActiveDownloads = ref.watch(downloadsProvider).isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [

          // macOS hides native title bar, need draggable area for window movement
          if (Platform.isMacOS)
            const DragToMoveArea(
              child: SizedBox(
                height: 28,
                width: double.infinity,
              ),
            ),

          Expanded(
            child: Row(
              children: [

                AppSidebar(
                  items: _navItems,
                  selectedPath: location,
                  onItemTap: (item) => context.go(item.routePath),
                  footer: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FooterNavItem(
                        icon: Icons.cloud_download_rounded,
                        tooltip: 'Downloads',
                        isSelected: false,
                        hasBadge: hasActiveDownloads,
                        onTap: () => DownloadsPanel.show(context),
                      ),
                      const SizedBox(height: AppSpacing.px8),
                      _FooterNavItem(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        isSelected: location == '/settings',
                        onTap: () => context.go('/settings'),
                      ),
                    ],
                  ),
                ),

                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colors.divider,
                ),

                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colors.divider),
          const LaunchBar(),
        ],
      ),
    );
  }
}

class _FooterNavItem extends StatefulWidget {
  const _FooterNavItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
    this.hasBadge = false,
  });
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  State<_FooterNavItem> createState() => _FooterNavItemState();
}

class _FooterNavItemState extends State<_FooterNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
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
          child: Tooltip(
            message: widget.tooltip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.isSelected || _hovered
                    ? colors.sidebarSelected
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      widget.icon,
                      size: AppSpacing.iconMd,
                      color: widget.isSelected
                          ? colors.primary
                          : _hovered
                              ? colors.textHigh
                              : colors.textLow,
                    ),
                  ),
                  if (widget.hasBadge)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
