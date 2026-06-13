import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/providers/local_files_provider.dart';
import '../data/instance_repository.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openFolder(String path) async {
  final uri = Uri.directory(path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    final fallbackUri = Uri.parse('file://$path');
    if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri);
    }
  }
}

class ScreenshotsTab extends ConsumerWidget {
  const ScreenshotsTab({super.key, required this.instanceId});
  final String instanceId;

  void _showImageDialog(BuildContext context, String path, WidgetRef ref, dynamic file) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.px24),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: AppButton(
                  label: 'Delete',
                  icon: Icons.delete_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    ref.read(localFilesProvider((instanceId: instanceId, folderName: 'screenshots')).notifier).deleteFile(file);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final query = (instanceId: instanceId, folderName: 'screenshots');
    final filesAsync = ref.watch(localFilesProvider(query));

    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px16, vertical: AppSpacing.px8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
          child: Row(
            children: [
              Text('Screenshots', style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
              const Spacer(),
              AppButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  ref.read(localFilesProvider(query).notifier).refresh();
                },
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
              ),
              const SizedBox(width: AppSpacing.px8),
              AppButton(
                label: 'Open Folder',
                onPressed: () async {
                  final repo = ref.read(instanceRepositoryProvider);
                  final path = await repo.getInstancePath(instanceId);
                  _openFolder('$path/screenshots');
                },
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),
        Expanded(
          child: filesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: colors.danger))),
            data: (files) {
              final images = files.where((f) => !f.isDirectory && f.name.toLowerCase().endsWith('.png')).toList();

              if (images.isEmpty) {
                return Center(
                  child: Text('No screenshots found.', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.px16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisSpacing: AppSpacing.px12,
                  crossAxisSpacing: AppSpacing.px12,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final file = images[index];
                  return GestureDetector(
                    onTap: () => _showImageDialog(context, file.path, ref, file),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.glassBorder),
                        image: DecorationImage(
                          image: FileImage(File(file.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
