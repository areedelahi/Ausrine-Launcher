import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/brand_icon.dart';
import '../core/widgets/progress_bar.dart';

import '../features/instances/domain/models/instance.dart';
import '../features/instances/domain/providers/instance_provider.dart';
import '../features/instances/domain/providers/launch_provider.dart';
import '../features/downloads/domain/providers/downloads_provider.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/instances/domain/providers/running_instances_provider.dart';

class LaunchBar extends ConsumerStatefulWidget {
  const LaunchBar({super.key});

  @override
  ConsumerState<LaunchBar> createState() => _LaunchBarState();
}

class _LaunchBarState extends ConsumerState<LaunchBar>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool _isLaunching = false;

  void _simulateLaunch(Instance instance) async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {

      String? newProfileId;
      try {
        newProfileId = await ref.read(downloadsProvider.notifier).startDownload(instance);
      } catch (downloadError) {
        print("Update check failed (offline mode?): $downloadError");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline Mode: Skipping updates. If game files are incomplete, the game may not launch properly.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      final instances = ref.read(instancesProvider).value ?? [];
      final updatedInstance = instances.firstWhere(
        (i) => i.id == instance.id,
        orElse: () => instance,
      );

      final launchInstance = updatedInstance.copyWith(
        profileId: newProfileId ?? updatedInstance.profileId
      );

      await ref.read(launchServiceProvider).launch(launchInstance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  void _killGame() {
    final selectedInstance = ref.read(selectedInstanceProvider);
    if (selectedInstance != null) {
      ref.read(downloadsProvider.notifier).removeTask(selectedInstance.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task removed from UI. (Background process may still run)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final selectedInstance = ref.watch(selectedInstanceProvider);
    final downloads = ref.watch(downloadsProvider);

    ref.watch(authProvider);

    final taskInfo = selectedInstance != null
        ? downloads.where((t) => t.instanceId == selectedInstance.id).firstOrNull
        : null;

    final runningInstances = ref.watch(runningInstancesProvider);
    final isRunning = selectedInstance != null && runningInstances.containsKey(selectedInstance.id);

    final isDownloading = taskInfo != null;
    final isBusy = isDownloading || isRunning;

    final progress = taskInfo?.progress ?? 0.0;
    final statusText = isRunning ? 'Game is running' : (taskInfo?.subtitle ?? '');

    return Container(
      height: AppSpacing.launchBarHeight,
      color: colors.sidebarBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.px16,
        vertical: AppSpacing.px4,
      ),
      child: Row(
        children: [

          _InstanceThumb(instance: selectedInstance),
          const SizedBox(width: AppSpacing.px12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  selectedInstance?.name ?? 'No instance selected',
                  style: AppTypography.titleSmall.copyWith(
                    color: selectedInstance == null ? colors.textDisabled : colors.textHigh,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                if (selectedInstance != null)
                  Row(
                    children: [
                      _VersionBadge(version: selectedInstance.minecraftVersion, color: colors.vanilla),
                      if (selectedInstance.loader != ModLoader.vanilla) ...[
                        const SizedBox(width: AppSpacing.px6),
                        _VersionBadge(
                            version: '${selectedInstance.loader.displayName} ${selectedInstance.loaderVersion ?? 'Latest'}', 
                            color: _getColorForLoader(selectedInstance.loader, colors)),
                      ]
                    ],
                  ),

                if (isDownloading) ...[
                  const SizedBox(height: AppSpacing.px6),
                  AppProgressBar(
                    value: progress,
                    height: 3,
                    showShimmer: true,
                  ),
                ],
                if (isBusy) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          statusText,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.textLow,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDownloading)
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.textLow,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.px16),

          if (isRunning)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.px8),
              child: AppButton(
                label: 'Kill',
                onPressed: () {
                  if (selectedInstance != null) {
                    ref.read(runningInstancesProvider.notifier).kill(selectedInstance.id);
                  }
                },
                icon: Icons.stop_rounded,
                variant: AppButtonVariant.danger,
                size: AppButtonSize.small,
              ),
            ),

          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: isBusy ? 1.0 : _pulseAnim.value,
                child: child,
              );
            },
            child: _PlayButton(
              isLaunching: isDownloading,
              isRunning: isRunning,
              isEnabled: selectedInstance != null && !isBusy,
              onPressed: () {
                if (selectedInstance != null) {
                  _simulateLaunch(selectedInstance);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForLoader(ModLoader loader, AppColors colors) {
    switch (loader) {
      case ModLoader.fabric:
        return colors.fabric;
      case ModLoader.forge:
        return colors.forge;
      case ModLoader.neoforge:
        return const Color(0xFFFFA500);
      case ModLoader.quilt:
        return colors.primary;
      default:
        return colors.vanilla;
    }
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.isLaunching, required this.isRunning, required this.isEnabled, required this.onPressed});
  final bool isLaunching;
  final bool isRunning;
  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isBusy = widget.isLaunching || widget.isRunning;

    return MouseRegion(
      cursor: !widget.isEnabled || isBusy ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: !widget.isEnabled || isBusy
                  ? [colors.textLow, colors.textLow]
                  : _hovered
                      ? [colors.primaryHover, colors.primary]
                      : [
                          colors.primary,
                          colors.primary.withValues(alpha: 0.85)
                        ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: widget.isEnabled && !isBusy && _hovered
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLaunching)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.background,
                  ),
                )
              else if (widget.isRunning)
                Icon(
                  Icons.videogame_asset_rounded,
                  size: 22,
                  color: colors.background,
                )
              else
                Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: colors.background,
                ),
              const SizedBox(width: 6),
              Text(
                widget.isLaunching ? 'Launching' : (widget.isRunning ? 'Running' : 'Play'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.md,
                  color: colors.background,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstanceThumb extends StatelessWidget {
  const _InstanceThumb({this.instance});
  final Instance? instance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.glassBorder),
      ),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.center,
      child: instance == null
          ? Icon(
              Icons.videogame_asset_rounded,
              color: colors.textMed,
              size: AppSpacing.iconLg,
            )
          : BrandIcon(
              type: BrandIconType.fromName(instance!.loader.name),
              url: instance!.icon,
              size: 30, 
            ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version, required this.color});
  final String version;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        version,
        style: AppTypography.versionBadge.copyWith(color: color),
      ),
    );
  }
}
