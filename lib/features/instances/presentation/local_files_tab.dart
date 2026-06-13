import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/instance_repository.dart';
import '../domain/models/local_file_item.dart';
import '../domain/models/instance.dart';
import '../domain/providers/instance_provider.dart';
import '../domain/providers/local_files_provider.dart';
import '../../remote_mods/domain/models/remote_mod.dart';
import '../../remote_mods/domain/providers/remote_mods_provider.dart';
import '../../remote_mods/domain/providers/modrinth_api_provider.dart';
import '../../remote_mods/domain/providers/curseforge_api_provider.dart';

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

class _SegmentedTabPicker extends StatelessWidget {
  const _SegmentedTabPicker({
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = tab == selected;
          return GestureDetector(
            onTap: () => onChanged(tab),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                tab,
                style: AppTypography.labelLarge.copyWith(
                  color: isSelected ? colors.primary : colors.textLow,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class LocalFilesTab extends ConsumerStatefulWidget {
  const LocalFilesTab({
    super.key,
    required this.instanceId,
    required this.folderName,
    required this.title,
    this.allowToggle = true,
  });

  final String instanceId;
  final String folderName;
  final String title;
  final bool allowToggle;

  @override
  ConsumerState<LocalFilesTab> createState() => _LocalFilesTabState();
}

class _LocalFilesTabState extends ConsumerState<LocalFilesTab> {
  String _currentView = 'Installed';
  String _searchQuery = '';
  bool _showAllVersions = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final instance = ref.watch(instancesProvider).value?.firstWhere((i) => i.id == widget.instanceId);

    if (instance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px16, vertical: AppSpacing.px8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(widget.title, style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
                const SizedBox(width: AppSpacing.px24),
                if (widget.allowToggle) 
                  _SegmentedTabPicker(
                    tabs: const ['Installed', 'Modrinth', 'CurseForge'],
                    selected: _currentView,
                    onChanged: (v) => setState(() => _currentView = v),
                  ),
                const SizedBox(width: AppSpacing.px24),
                if (_currentView != 'Installed' && widget.folderName != 'resourcepacks' && widget.folderName != 'shaderpacks') ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _showAllVersions,
                        onChanged: (v) => setState(() => _showAllVersions = v ?? false),
                      ),
                      Text('Show All Versions', style: AppTypography.bodySmall.copyWith(color: colors.textMed)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.px12),
                ],
                SizedBox(
                  width: 240,
                  child: AppTextField(
                    hint: 'Search $_currentView...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.px12),
                if (_currentView == 'Installed')
                  AppButton(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      ref.read(localFilesProvider((instanceId: widget.instanceId, folderName: widget.folderName)).notifier).refresh();
                    },
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.small,
                  ),
                if (_currentView == 'Installed')
                  const SizedBox(width: AppSpacing.px8),
                AppButton(
                  label: 'Open Folder',
                  onPressed: () async {
                    final repo = ref.read(instanceRepositoryProvider);
                    final path = await repo.getInstancePath(widget.instanceId);
                    _openFolder('$path/${widget.folderName}');
                  },
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_currentView == 'Installed') {
      return _LocalInstalledView(
        instanceId: widget.instanceId,
        folderName: widget.folderName,
        searchQuery: _searchQuery,
        allowToggle: widget.allowToggle,
      );
    } else {
      final source = _currentView.toLowerCase();
      final instance = ref.read(instancesProvider).value?.firstWhere((i) => i.id == widget.instanceId);
      if (instance == null) return const SizedBox();

      return _RemoteBrowserView(
        source: source,
        folderName: widget.folderName,
        query: _searchQuery,
        instance: instance,
        showAllVersions: _showAllVersions,
      );
    }
  }
}

class _LocalInstalledView extends ConsumerWidget {
  const _LocalInstalledView({
    required this.instanceId,
    required this.folderName,
    required this.searchQuery,
    required this.allowToggle,
  });

  final String instanceId;
  final String folderName;
  final String searchQuery;
  final bool allowToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final query = (instanceId: instanceId, folderName: folderName);
    final filesAsync = ref.watch(localFilesProvider(query));

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: colors.danger))),
      data: (files) {
        final filtered = files.where((f) {
          final q = searchQuery.toLowerCase();
          final metaName = f.metadata?.name.toLowerCase() ?? '';
          return q.isEmpty || f.name.toLowerCase().contains(q) || metaName.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text('No files found.', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.px16),
          itemCount: filtered.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.px8),
          itemBuilder: (context, index) {
            final file = filtered[index];
            final sizeKb = file.sizeBytes / 1024;
            final sizeStr = sizeKb > 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '${sizeKb.toStringAsFixed(1)} KB';

            final displayName = file.metadata?.name ?? file.name;
            final displayDesc = file.metadata?.description ?? (file.isDirectory ? 'Folder • ' + sizeStr : sizeStr);
            final displayVersion = file.metadata?.version;

            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.px12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: Icon(
                      file.isDirectory ? Icons.folder_rounded : Icons.extension_rounded,
                      color: file.isEnabled ? colors.primary : colors.textLow,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.px16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: AppTypography.titleMedium.copyWith(
                                  color: file.isEnabled ? colors.textHigh : colors.textLow,
                                  decoration: file.isEnabled ? null : TextDecoration.lineThrough,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (displayVersion != null && displayVersion.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.px8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(displayVersion, style: AppTypography.labelSmall.copyWith(color: colors.textLow)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.px4),
                        Text(
                          displayDesc,
                          style: AppTypography.bodySmall.copyWith(color: colors.textLow),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (allowToggle && !file.isDirectory)
                    Switch(
                      value: file.isEnabled,
                      onChanged: (val) {
                        ref.read(localFilesProvider(query).notifier).toggleFile(file);
                      },
                    ),
                  const SizedBox(width: AppSpacing.px12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: colors.danger,
                    onPressed: () {
                      ref.read(localFilesProvider(query).notifier).deleteFile(file);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RemoteBrowserView extends ConsumerWidget {
  const _RemoteBrowserView({
    required this.source,
    required this.folderName,
    required this.query,
    required this.instance,
    required this.showAllVersions,
  });

  final String source;
  final String folderName;
  final String query;
  final Instance instance;
  final bool showAllVersions;

  Future<void> _showVersionPicker(BuildContext context, WidgetRef ref, RemoteMod mod, RemoteSearchQuery searchQuery) async {
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

      final versions = await ref.read(remoteModsProvider(searchQuery).notifier).getVersions(mod);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); 

      if (versions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No versions found.')));
        }
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return _VersionSelectionDialog(
              mod: mod,
              versions: versions,
              onInstall: (version) {
                Navigator.pop(context);
                ref.read(remoteModsProvider(searchQuery).notifier).installSpecificVersion(mod, version).catchError((e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Install failed: $e')));
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installing ${version.name}...')));
              },
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch versions: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (query.isEmpty) {
      return Center(
        child: Text('Search to discover new content!', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
      );
    }

    final searchQuery = (
      source: source,
      query: query,
      folderName: folderName,
      instance: instance,
      showAllVersions: showAllVersions || folderName != 'mods',
    );

    if (source == 'curseforge') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_rounded, size: 48, color: colors.textLow),
            const SizedBox(height: AppSpacing.px16),
            Text(
              'CurseForge Coming Soon',
              style: AppTypography.titleMedium.copyWith(color: colors.textMed),
            ),
            const SizedBox(height: AppSpacing.px8),
            Text(
              'Awaiting API key approval.',
              style: AppTypography.bodySmall.copyWith(color: colors.textLow),
            ),
          ],
        ),
      );
    }

    final remoteAsync = ref.watch(remoteModsProvider(searchQuery));
    final localFiles = ref.watch(localFilesProvider((instanceId: instance.id, folderName: folderName))).value ?? [];

    return remoteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Search Error: $err', style: TextStyle(color: colors.danger))),
      data: (mods) {
        if (mods.isEmpty) {
          return Center(
            child: Text('No results found.', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.px16),
          itemCount: mods.length,
          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.px8),
          itemBuilder: (context, index) {
            final mod = mods[index];
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.px12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: colors.glassBorder),
                      image: mod.iconUrl != null
                          ? DecorationImage(image: NetworkImage(mod.iconUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: mod.iconUrl == null
                        ? Icon(Icons.extension_rounded, color: colors.primary, size: 24)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.px16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mod.title,
                          style: AppTypography.titleMedium.copyWith(color: colors.textHigh),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.px2),
                        Text(
                          'by ${mod.author}',
                          style: AppTypography.bodySmall.copyWith(color: colors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.px4),
                        Row(
                          children: [
                            Icon(Icons.download_rounded, size: 14, color: colors.textLow),
                            const SizedBox(width: 4),
                            Text('${mod.downloadCount}', style: AppTypography.labelSmall.copyWith(color: colors.textLow)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mod.description,
                                style: AppTypography.labelSmall.copyWith(color: colors.textMed),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.px12),
                  if (localFiles.any((f) => 
                      f.metadata?.id == mod.slug || 
                      f.metadata?.id == mod.id || 
                      f.name.toLowerCase().contains(mod.slug.toLowerCase()) || 
                      f.name.toLowerCase().contains(mod.id.toLowerCase())))
                    const Icon(Icons.check_circle_rounded, color: Colors.green)
                  else
                    AppButton(
                      label: 'Install...',
                      onPressed: () => _showVersionPicker(context, ref, mod, searchQuery),
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.small,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VersionSelectionDialog extends StatelessWidget {
  const _VersionSelectionDialog({
    required this.mod,
    required this.versions,
    required this.onInstall,
  });

  final RemoteMod mod;
  final List<RemoteModVersion> versions;
  final void Function(RemoteModVersion) onInstall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text('Install ${mod.title}', style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
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
                '${v.releaseType.toUpperCase()} • ${v.gameVersions.take(3).join(', ')}${v.gameVersions.length > 3 ? '...' : ''} • ${v.loaders.join(', ')}',
                style: AppTypography.labelSmall.copyWith(color: colors.textMed),
              ),
              trailing: AppButton(
                label: 'Install',
                onPressed: () => onInstall(v),
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
  }
}
