import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../features/downloads/domain/providers/downloads_provider.dart';

class DownloadsPanel extends ConsumerWidget {
  const DownloadsPanel({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 72, bottom: 64),
            child: Material(
              color: Colors.transparent,
              child: DownloadsPanel(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve =
            CurvedAnimation(parent: animation, curve: Curves.easeOutQuad);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.05, 0.0),
              end: Offset.zero,
            ).animate(curve),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curve),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tasks = ref.watch(downloadsProvider);

    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            padding: const EdgeInsets.all(AppSpacing.px16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_download_rounded,
                    color: colors.textHigh, size: 20),
                const SizedBox(width: AppSpacing.px8),
                Text('Active Tasks',
                    style: AppTypography.titleMedium
                        .copyWith(color: colors.textHigh)),
                const Spacer(),
                Text('${tasks.length}',
                    style: AppTypography.labelLarge
                        .copyWith(color: colors.primary)),
              ],
            ),
          ),

          Flexible(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.px32),
                    child: Text(
                      'No active downloads',
                      style: AppTypography.bodyMedium.copyWith(color: colors.textLow),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.px12),
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.px8),
                    itemBuilder: (ctx, i) {
                      final t = tasks[i];
                      return _TaskItem(
                        taskId: t.instanceId,
                        title: t.title,
                        subtitle: t.subtitle,
                        progress: t.progress,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskItem extends ConsumerWidget {
  const _TaskItem({
    required this.taskId,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String taskId;
  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.px12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style:
                      AppTypography.titleSmall.copyWith(color: colors.textHigh),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.px8),
              InkWell(
                onTap: () {
                  ref.read(downloadsProvider.notifier).removeTask(taskId);
                },
                borderRadius: BorderRadius.circular(12),
                child:
                    Icon(Icons.close_rounded, size: 16, color: colors.textLow),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.px4),
          Text(
            subtitle,
            style: AppTypography.labelSmall.copyWith(color: colors.textLow),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.px12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(colors.primary),
            borderRadius: BorderRadius.circular(2),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}
