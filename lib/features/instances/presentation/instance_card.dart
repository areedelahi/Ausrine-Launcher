import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/brand_icon.dart';

class InstanceCard extends StatefulWidget {
  const InstanceCard({
    super.key,
    required this.name,
    required this.version,
    required this.loader,
    required this.loaderVersion,
    required this.modsCount,
    required this.lastPlayed,
    required this.isRunning,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
    required this.onPlay,
    required this.onSettingsTap,
    required this.onOpenFolderTap,
    required this.icon,
  });

  final String name;
  final String version;
  final String loader;
  final String loaderVersion;
  final int modsCount;
  final String lastPlayed;
  final bool isRunning;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onSettingsTap;
  final VoidCallback onOpenFolderTap;
  final String icon;

  @override
  State<InstanceCard> createState() => _InstanceCardState();
}

class _InstanceCardState extends State<InstanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _overlayCtrl;
  late Animation<double> _overlayAnim;

  @override
  void initState() {
    super.initState();
    _overlayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _overlayAnim = CurvedAnimation(
      parent: _overlayCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _overlayCtrl.dispose();
    super.dispose();
  }

  void _onHoverEnter() {
    _overlayCtrl.forward();
  }

  void _onHoverExit() {
    _overlayCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: AppCard(
        isSelected: widget.isSelected,
        isHoverable: true,
        padding: EdgeInsets.zero,
        onTap: widget.onTap,
        child: SizedBox(
          width: AppSpacing.instanceCardWidth,
          height: AppSpacing.instanceCardHeight,
          child: Stack(
            children: [

              Padding(
                padding: const EdgeInsets.all(AppSpacing.px12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: widget.iconColor.withValues(alpha: 0.3),
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      alignment: Alignment.center,
                      child: BrandIcon(
                        type: BrandIconType.fromName(widget.loader),
                        url: widget.icon,
                        size: 36, 
                      ),
                    ),
                    const SizedBox(height: AppSpacing.px10),

                    Text(
                      widget.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: colors.textHigh,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.px4),

                    _Pill(
                      label: widget.version,
                      color: widget.iconColor,
                    ),
                    if (widget.loader != 'Vanilla' &&
                        widget.loaderVersion.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.px4),
                      _Pill(
                        label: '${widget.loader} ${widget.loaderVersion}',
                        color: widget.iconColor,
                      ),
                    ],
                    if (widget.isRunning) ...[
                      const SizedBox(height: AppSpacing.px6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(
                            color: colors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Running',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.success,
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.px12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.modsCount > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.extension_rounded,
                                size: 11,
                                color: colors.textLow,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.modsCount}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: colors.textLow,
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox(),
                        Text(
                          widget.lastPlayed,
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.textLow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Positioned(
                top: AppSpacing.px8,
                right: AppSpacing.px8,
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.folder_open_rounded),
                        iconSize: AppSpacing.iconSm,
                        color: colors.textMed,
                        splashRadius: 16,
                        onPressed: widget.onOpenFolderTap,
                        tooltip: 'Open Instance Folder',
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        iconSize: AppSpacing.iconSm,
                        color: colors.textMed,
                        splashRadius: 16,
                        onPressed: widget.onSettingsTap,
                        tooltip: 'Instance Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: AppTypography.versionBadge.copyWith(color: color),
      ),
    );
  }
}
