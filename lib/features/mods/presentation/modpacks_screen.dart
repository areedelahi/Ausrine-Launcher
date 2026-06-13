import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../remote_mods/domain/providers/remote_mods_provider.dart';
import '../../remote_mods/domain/models/remote_mod.dart';
import '../../downloads/domain/providers/downloads_provider.dart';

class ModpacksScreen extends ConsumerStatefulWidget {
  const ModpacksScreen({super.key});
  @override
  ConsumerState<ModpacksScreen> createState() => _ModpacksScreenState();
}

class _ModpacksScreenState extends ConsumerState<ModpacksScreen> {
  String _search = '';
  String _currentView = 'Modrinth'; 

  Future<void> _installModpack(RemoteMod pack, RemoteSearchQuery searchQuery) async {
    final colors = context.colors;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Text('Fetching Versions...', style: AppTypography.titleMedium.copyWith(color: colors.textHigh)),
          content: const SizedBox(
            width: 50, height: 50,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final versions = await ref.read(remoteModsProvider(searchQuery).notifier).getVersions(pack);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (versions.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No versions found.')));
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: colors.surface,
              title: Text('Install ' + pack.title, style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
              content: SizedBox(
                width: 600,
                height: 400,
                child: ListView.separated(
                  itemCount: versions.length,
                  separatorBuilder: (context, index) => Divider(color: colors.divider),
                  itemBuilder: (context, index) {
                    final v = versions[index];
                    return ListTile(
                      title: Text(v.name, style: AppTypography.bodyMedium.copyWith(color: colors.textHigh)),
                      subtitle: Text(
                        v.releaseType.toUpperCase() + ' • ' + v.gameVersions.take(3).join(', ') + ' • ' + v.loaders.join(', '),
                        style: AppTypography.labelSmall.copyWith(color: colors.textMed),
                      ),
                      trailing: AppButton(
                        label: 'Install',
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(downloadsProvider.notifier).installModpack(pack, v);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installing ' + v.name + '...')));
                        },
                        size: AppButtonSize.small,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: colors.textMed)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch versions: ' + e.toString())));
      }
    }
  }

  Future<void> _importLocalModpack() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mrpack'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      ref.read(downloadsProvider.notifier).installLocalModpack(file);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importing local modpack...')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final queryArgs = (
      source: _currentView.toLowerCase(),
      query: _search.isEmpty ? 'optimization' : _search, 
      folderName: 'modpacks',
      instance: null,
      showAllVersions: false,
    );

    final packsAsync = ref.watch(remoteModsProvider(queryArgs));

    return Column(
      children: [

        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px12, vertical: AppSpacing.px8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/heading_logo.svg',
                height: 28,
              ),
              const SizedBox(width: AppSpacing.px12),
              Text('Modpacks', style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
              const SizedBox(width: AppSpacing.px24),
              SizedBox(
                width: 260,
                child: AppTextField(
                  hint: 'Search modpacks...',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const Spacer(),
              _SegmentedTabPicker(
                tabs: const ['Modrinth', 'CurseForge'],
                selected: _currentView,
                onChanged: (v) => setState(() => _currentView = v),
              ),
              const SizedBox(width: AppSpacing.px16),
              AppButton(
                label: 'Import',
                icon: Icons.file_upload_rounded,
                onPressed: _importLocalModpack,
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),

        Expanded(
          child: _currentView == 'CurseForge'
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.construction_rounded, size: 64, color: colors.textLow),
                      const SizedBox(height: 16),
                      Text('CurseForge API Coming Soon', style: AppTypography.titleMedium.copyWith(color: colors.textMed)),
                      const SizedBox(height: 8),
                      Text('Awaiting API Key Approval', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
                    ],
                  ),
                )
              : packsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: ' + e.toString(), style: TextStyle(color: colors.danger))),
                  data: (packs) {
                    if (packs.isEmpty) {
                      return Center(child: Text('No modpacks found.', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.px16),
                      itemCount: packs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.px8),
                      itemBuilder: (ctx, i) => _ModpackRow(
                        pack: packs[i],
                        onInstall: () => _installModpack(packs[i], queryArgs),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ModpackRow extends StatelessWidget {
  const _ModpackRow({required this.pack, required this.onInstall});
  final RemoteMod pack;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      child: Row(
        children: [

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: colors.glassBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: (pack.iconUrl ?? '').isNotEmpty
                  ? Image.network(
                      pack.iconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.inventory_2_rounded, color: colors.textLow, size: AppSpacing.iconLg),
                    )
                  : Icon(Icons.inventory_2_rounded, color: colors.textLow, size: AppSpacing.iconLg),
            ),
          ),
          const SizedBox(width: AppSpacing.px12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.title, style: AppTypography.titleSmall.copyWith(color: colors.textHigh)),
                const SizedBox(height: 3),
                Text('by ' + pack.author, style: AppTypography.bodySmall.copyWith(color: colors.textLow)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.download_rounded, size: 12, color: colors.textLow),
                    const SizedBox(width: 4),
                    Text(pack.downloadCount.toString(), style: AppTypography.labelSmall.copyWith(color: colors.textLow)),
                  ],
                ),
              ],
            ),
          ),

          AppButton(
            label: 'Install',
            icon: Icons.download_rounded,
            onPressed: onInstall,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabPicker extends StatelessWidget {
  const _SegmentedTabPicker({required this.tabs, required this.selected, required this.onChanged});
  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.glass,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((t) {
          final isSelected = t == selected;
          return GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                t,
                style: AppTypography.labelLarge.copyWith(
                  color: isSelected ? colors.primary : colors.textLow,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
