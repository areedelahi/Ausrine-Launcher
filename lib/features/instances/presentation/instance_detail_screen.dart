import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/platform/file_service.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'dart:io';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import 'package:file_picker/file_picker.dart';
import '../data/instance_repository.dart';
import '../domain/providers/instance_provider.dart';
import '../domain/models/instance.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/providers/launch_provider.dart';
import '../../downloads/domain/providers/downloads_provider.dart';
import 'local_files_tab.dart';
import 'screenshots_tab.dart';
import '../domain/providers/version_metadata_provider.dart';
import '../../remote_mods/domain/models/remote_mod.dart';
import '../../remote_mods/domain/providers/modrinth_api_provider.dart';
import '../../remote_mods/domain/providers/curseforge_api_provider.dart';
import '../../../core/widgets/brand_icon.dart';

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

class InstanceDetailScreen extends ConsumerStatefulWidget {
  const InstanceDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<InstanceDetailScreen> createState() =>
      _InstanceDetailScreenState();
}

class _InstanceDetailScreenState extends ConsumerState<InstanceDetailScreen> {
  int _selectedIndex = 0;
  bool _isLaunching = false;

  final _tabs = [
    'Overview',
    'Mods',
    'Resourcepacks',
    'Shaders',
    'Worlds',
    'Screenshots',
    'Logs',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [

        Container(
          width: 200,
          decoration: BoxDecoration(
            color: colors.sidebarBg,
            border: Border(right: BorderSide(color: colors.glassBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Padding(
                padding: const EdgeInsets.all(AppSpacing.px16),
                child: Row(
                  children: [
                    AppButton(
                      label: '',
                      icon: Icons.arrow_back_rounded,
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                      onPressed: () => context.go('/instances'),
                    ),
                    const SizedBox(width: AppSpacing.px12),
                    Expanded(
                      child: Text(
                        widget.id,
                        style: AppTypography.titleMedium
                            .copyWith(color: colors.textHigh),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.px8, horizontal: AppSpacing.px8),
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return _LocalSidebarItem(
                      label: _tabs[index],
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedIndex = index),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.px16),
                child: AppButton(
                  label: _isLaunching ? 'Preparing...' : 'Launch',
                  icon: Icons.play_arrow_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _isLaunching
                      ? null
                      : () async {
                          final instances =
                              ref.read(instancesProvider).value ?? [];
                          final instance =
                              instances.firstWhere((e) => e.id == widget.id);
                          final repo = ref.read(instanceRepositoryProvider);

                          final authState = ref.read(authProvider);
                          if (authState.activeAccount == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please select an account in Settings first.')),
                              );
                            }
                            return;
                          }
                          setState(() => _isLaunching = true);
                          try {
                            try {
                              await ref
                                  .read(downloadsProvider.notifier)
                                  .startDownload(instance);
                            } catch (downloadError) {

                              print("Update check failed (offline mode?): $downloadError");
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Offline Mode: Skipping updates...')),
                                );
                              }
                            }

                            final instancesList =
                                ref.read(instancesProvider).value ?? [];
                            final updatedInstance = instancesList.firstWhere(
                              (i) => i.id == instance.id,
                              orElse: () => instance,
                            );

                            if (updatedInstance.minecraftVersion !=
                                    instance.minecraftVersion ||
                                updatedInstance.loader != instance.loader ||
                                updatedInstance.loaderVersion !=
                                    instance.loaderVersion) {
                              throw Exception(
                                  'Version configuration was changed during download. Please click Launch again to download the new version.');
                            }

                            await ref
                                .read(launchServiceProvider)
                                .launch(updatedInstance);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to launch: $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isLaunching = false);
                            }
                          }
                        },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    Widget content;
    switch (_selectedIndex) {
      case 0:
        content = _OverviewTab(instanceId: widget.id);
        break;
      case 1:
        content = LocalFilesTab(
            instanceId: widget.id, folderName: 'mods', title: 'Mods');
        break;
      case 2:
        content = LocalFilesTab(
            instanceId: widget.id,
            folderName: 'resourcepacks',
            title: 'Resourcepacks');
        break;
      case 3:
        content = LocalFilesTab(
            instanceId: widget.id, folderName: 'shaderpacks', title: 'Shaders');
        break;
      case 4:
        content = LocalFilesTab(
            instanceId: widget.id,
            folderName: 'saves',
            title: 'Worlds',
            allowToggle: false);
        break;
      case 5:
        content = ScreenshotsTab(instanceId: widget.id);
        break;
      case 6:
        content = _LogsTab(instanceId: widget.id);
        break;
      case 7:
        content = _SettingsTab(instanceId: widget.id);
        break;
      default:
        content = const SizedBox();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (child.key != ValueKey(_selectedIndex)) {
          return FadeTransition(opacity: animation, child: child);
        }
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_selectedIndex),
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topLeft,
        child: content,
      ),
    );
  }
}

class _LocalSidebarItem extends StatelessWidget {
  const _LocalSidebarItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.px12, vertical: AppSpacing.px10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: isSelected ? colors.primary : colors.textMed,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ModsTab extends ConsumerStatefulWidget {
  const _ModsTab({required this.instanceId});
  final String instanceId;

  @override
  ConsumerState<_ModsTab> createState() => _ModsTabState();
}

class _ModsTabState extends ConsumerState<_ModsTab> {
  String _search = '';
  String _currentView = 'Installed'; 

  final _stubs = [
    const _StubMod(
        'Sodium', 'CaffeineMC', '21.5M', 'Fabric 1.21.4', Color(0xFF4A9EFF)),
    const _StubMod('Iris Shaders', 'coderbot', '15.2M', 'Fabric 1.21.4',
        Color(0xFF9B72CF)),
    const _StubMod(
        'Lithium', 'CaffeineMC', '12.8M', 'Fabric 1.21.4', Color(0xFF4DFFB0)),
    const _StubMod('Distant Horizons', 'Clouded', '8.3M', 'Fabric/Forge',
        Color(0xFF87CEEB)),
    const _StubMod('Xaero\'s Minimap', 'xaero96', '19.1M', 'Multi-loader',
        Color(0xFFFFBC42)),
    const _StubMod('JEI', 'mezz', '110M', 'Forge 1.21.4', Color(0xFFE88C30)),
    const _StubMod(
        'Create', 'simibubi', '45.3M', 'Forge/Fabric', Color(0xFFB5A580)),
    const _StubMod(
        'Waystones', 'BlayTheNinth', '9.7M', 'Fabric/Forge', Color(0xFF7FFFD4)),
  ];

  List<_StubMod> get _filtered => _stubs
      .where((m) =>
          _search.isEmpty ||
          m.name.toLowerCase().contains(_search.toLowerCase()) ||
          m.author.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [

        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.px16, vertical: AppSpacing.px8),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider))),
          child: Row(
            children: [
              Text('Mods',
                  style: AppTypography.titleLarge
                      .copyWith(color: colors.textHigh)),
              const SizedBox(width: AppSpacing.px24),
              _SegmentedTabPicker(
                tabs: const ['Installed', 'Modrinth', 'CurseForge'],
                selected: _currentView,
                onChanged: (v) => setState(() => _currentView = v),
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                child: AppTextField(
                  hint: 'Search $_currentView…',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: AppSpacing.px12),
              AppButton(
                label: 'Open Folder',
                onPressed: () async {
                  final repo = ref.read(instanceRepositoryProvider);
                  final path = await repo.getInstancePath(widget.instanceId);
                  _openFolder('$path/mods');
                },
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.px16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 110,
              crossAxisSpacing: AppSpacing.px10,
              mainAxisSpacing: AppSpacing.px10,
            ),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) => _ModCard(
              mod: _filtered[i],
              isInstalledView: _currentView == 'Installed',
            ),
          ),
        ),
      ],
    );
  }
}

class _ModCard extends StatelessWidget {
  const _ModCard({required this.mod, required this.isInstalledView});
  final _StubMod mod;
  final bool isInstalledView;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: mod.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: mod.color.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.extension_rounded,
                color: mod.color, size: AppSpacing.iconLg),
          ),
          const SizedBox(width: AppSpacing.px12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(mod.name,
                    style: AppTypography.titleSmall
                        .copyWith(color: colors.textHigh),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(mod.author,
                    style:
                        AppTypography.bodySmall.copyWith(color: colors.textLow),
                    maxLines: 1),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.download_rounded,
                        size: 11, color: colors.textLow),
                    const SizedBox(width: 3),
                    Text(mod.downloads,
                        style: AppTypography.labelSmall
                            .copyWith(color: colors.textLow)),
                    const SizedBox(width: AppSpacing.px8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.glass,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: Text(mod.loader,
                            style: AppTypography.labelSmall
                                .copyWith(color: colors.textLow),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.px8),
          if (isInstalledView) ...[
            Switch(value: true, onChanged: (v) {}),
            const SizedBox(width: AppSpacing.px4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              iconSize: AppSpacing.iconSm,
              color: Colors.redAccent,
              splashRadius: 16,
              onPressed: () {},
            ),
          ] else ...[
            AppButton(
              label: 'Install',
              onPressed: () {},
              variant: AppButtonVariant.outline,
              size: AppButtonSize.small,
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedTabPicker extends StatelessWidget {
  const _SegmentedTabPicker(
      {required this.tabs, required this.selected, required this.onChanged});
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
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.px16, vertical: 6),
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

class _StubMod {
  const _StubMod(
      this.name, this.author, this.downloads, this.loader, this.color);
  final String name, author, downloads, loader;
  final Color color;
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.instanceId});
  final String instanceId;

  String _formatDuration(int ms) {
    if (ms == 0) return 'Never';
    final hours = ms ~/ 3600000;
    final minutes = (ms % 3600000) ~/ 60000;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final instancesAsync = ref.watch(instancesProvider);
    final instance =
        instancesAsync.value?.firstWhere((i) => i.id == instanceId);

    if (instance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.px24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview',
              style: AppTypography.headlineMedium
                  .copyWith(color: colors.textHigh)),
          const SizedBox(height: AppSpacing.px24),

          AppCard(
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: instance.icon.startsWith('data:image')
                        ? Image.memory(
                            Uri.parse(instance.icon).data!.contentAsBytes(),
                            fit: BoxFit.cover,
                          )
                        : Image.asset('assets/icons/${instance.icon}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.grass_rounded, size: 40)),
                  ),
                ),
                const SizedBox(width: AppSpacing.px24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(instance.name,
                          style: AppTypography.titleLarge
                              .copyWith(color: colors.textHigh)),
                      const SizedBox(height: AppSpacing.px8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primaryMuted,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(
                              'Minecraft ${instance.minecraftVersion}',
                              style: AppTypography.labelLarge
                                  .copyWith(color: colors.primary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.px8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                              border: Border.all(color: colors.glassBorder),
                            ),
                            child: Text(
                              '${instance.loader.displayName} ${instance.loaderVersion ?? ''}',
                              style: AppTypography.labelLarge
                                  .copyWith(color: colors.textMed),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.px24),

          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Play Time',
                          style: AppTypography.titleSmall
                              .copyWith(color: colors.textMed)),
                      const SizedBox(height: AppSpacing.px8),
                      Text(_formatDuration(instance.playTimeMs),
                          style: AppTypography.headlineMedium
                              .copyWith(color: colors.textHigh)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.px16),
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last Played',
                          style: AppTypography.titleSmall
                              .copyWith(color: colors.textMed)),
                      const SizedBox(height: AppSpacing.px8),
                      Text(_formatDate(instance.lastPlayed),
                          style: AppTypography.headlineMedium
                              .copyWith(color: colors.textHigh)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogsTab extends ConsumerStatefulWidget {
  const _LogsTab({required this.instanceId});
  final String instanceId;

  @override
  ConsumerState<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<_LogsTab> {
  String? _logContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() {
      _isLoading = true;
      _logContent = null;
    });

    try {
      final repo = ref.read(instanceRepositoryProvider);
      final path = await repo.getInstancePath(widget.instanceId);
      final file = File('$path/logs/latest.log');
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          _logContent = content;
        });
      } else {
        setState(() {
          _logContent = 'No latest.log found for this instance.';
        });
      }
    } catch (e) {
      setState(() {
        _logContent = 'Error reading log: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.px16, vertical: AppSpacing.px8),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider))),
          child: Row(
            children: [
              Text('Logs',
                  style: AppTypography.titleLarge
                      .copyWith(color: colors.textHigh)),
              const Spacer(),
              AppButton(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  onPressed: _loadLog,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(AppSpacing.px16),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : SingleChildScrollView(
                    child: SelectableText(
                      _logContent ?? 'No logs available.',
                      style: AppTypography.mono.copyWith(
                        color: colors.textMed,
                        height: 1.55,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({required this.instanceId});
  final String instanceId;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  bool _followGlobal = true;
  RangeValues _memoryRange = const RangeValues(1024, 4096);
  final TextEditingController _jvmArgsController = TextEditingController();
  final TextEditingController _javaPathController = TextEditingController();

  String? _version;
  bool _showSnapshots = false;
  String _loader = 'Vanilla';
  String? _loaderVersion;
  bool _showAllLoaderVersions = false;

  final _loaders = ['Vanilla', 'Fabric', 'Forge', 'NeoForge', 'Quilt'];

  List<String> get _availableLoaders {
    if (_version == null) return _loaders;
    return _loaders
        .where((l) => _isVersionSupportedByLoader(_version!, l))
        .toList();
  }

  bool _isVersionSupportedByLoader(String mcVersion, String loader) {
    if (loader == 'Vanilla') return true;

    final parts = mcVersion.split('.');
    if (parts.isEmpty) return true;

    final major = int.tryParse(parts[0]) ?? 1;
    final minor = parts.length > 1
        ? int.tryParse(parts[1].split(RegExp(r'[-a-zA-Z]'))[0]) ?? 0
        : 0;
    final patch = parts.length > 2
        ? int.tryParse(parts[2].split(RegExp(r'[-a-zA-Z]'))[0]) ?? 0
        : 0;

    if (loader == 'NeoForge') {
      if (major > 1) return true;
      if (major == 1 && minor > 20) return true;
      if (major == 1 && minor == 20 && patch >= 1) return true;
      return false;
    }

    if (loader == 'Fabric' || loader == 'Quilt') {
      if (major > 1) return true;
      if (major == 1 && minor >= 14) return true;
      return false;
    }

    if (loader == 'Forge') {
      return true;
    }

    return true;
  }

  AsyncValue<List<String>>? _getLoaderVersions(String loader) {
    switch (loader) {
      case 'Fabric':
        return ref.watch(fabricLoadersProvider);
      case 'Forge':
        return ref.watch(forgeLoadersProvider);
      case 'NeoForge':
        return ref.watch(neoForgeLoadersProvider);
      case 'Quilt':
        return ref.watch(quiltLoadersProvider);
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromInstance();
  }

  void _loadFromInstance() {
    final list = ref.read(instancesProvider).value ?? [];
    if (list.isEmpty)
      return; 
    try {
      final inst = list.firstWhere((e) => e.id == widget.instanceId);

      _followGlobal = inst.allocatedRamMb == null &&
          inst.jvmArgs == null &&
          inst.javaPath == null;
      _memoryRange = RangeValues(
        (inst.minAllocatedRamMb ?? 1024).toDouble(),
        (inst.allocatedRamMb ?? 4096).toDouble(),
      );
      _jvmArgsController.text = inst.jvmArgs ?? '';
      _javaPathController.text = inst.javaPath ?? '';

      _version = inst.minecraftVersion;
      _loader = inst.loader.name == 'vanilla'
          ? 'Vanilla'
          : inst.loader.name == 'fabric'
              ? 'Fabric'
              : inst.loader.name == 'forge'
                  ? 'Forge'
                  : inst.loader.name == 'neoforge'
                      ? 'NeoForge'
                      : inst.loader.name == 'quilt'
                          ? 'Quilt'
                          : 'Vanilla';
      _loaderVersion = inst.loaderVersion;
    } catch (_) {}
  }

  Future<void> _saveToInstance() async {
    final list = ref.read(instancesProvider).value ?? [];
    final inst = list.firstWhere((e) => e.id == widget.instanceId);

    Instance updated;
    if (_followGlobal) {
      updated = inst.clearOverrides();
    } else {
      final jvmArgsText = _jvmArgsController.text.trim();
      final javaPathText = _javaPathController.text.trim();
      updated = inst.copyWith(
        minAllocatedRamMb: _memoryRange.start.toInt(),
        allocatedRamMb: _memoryRange.end.toInt(),
        clearJvmArgs: jvmArgsText.isEmpty,
        jvmArgs: jvmArgsText.isEmpty ? null : jvmArgsText,
        clearJavaPath: javaPathText.isEmpty,
        javaPath: javaPathText.isEmpty ? null : javaPathText,
      );
    }

    await ref.read(instancesProvider.notifier).updateInstance(updated);
    try {
      final baseDir = await getAusrineSupportDirectory();
      final logDir = Directory(p.join(baseDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final logFile = File(p.join(logDir.path, 'save_log.txt'));
      await logFile.writeAsString(
          'Instance Save: followGlobal=$_followGlobal, ram=${updated.allocatedRamMb}, jvmArgs=${updated.jvmArgs}\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> _applyVersionChanges() async {
    final list = ref.read(instancesProvider).value ?? [];
    final inst = list.firstWhere((e) => e.id == widget.instanceId);

    final updated = inst.copyWith(
      minecraftVersion: _version,
      loader: ModLoader.fromString(_loader),
      loaderVersion: _loaderVersion,
    );
    await ref.read(instancesProvider.notifier).updateInstance(updated);
  }

  @override
  void didUpdateWidget(_SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final list = ref.read(instancesProvider).value ?? [];
    if (list.isEmpty) return;

    try {
      final inst = list.firstWhere((e) => e.id == widget.instanceId);
      final newFollowGlobal = inst.allocatedRamMb == null &&
          inst.jvmArgs == null &&
          inst.javaPath == null;
      final newRam = (inst.allocatedRamMb ?? 4096).toDouble();
      final newArgs = inst.jvmArgs ?? '';
      final newPath = inst.javaPath ?? '';

      bool needsRebuild = false;
      if (_followGlobal != newFollowGlobal) {
        _followGlobal = newFollowGlobal;
        needsRebuild = true;
      }
      final newMinRam = (inst.minAllocatedRamMb ?? 1024).toDouble();
      final newMaxRam = (inst.allocatedRamMb ?? 4096).toDouble();
      if (_memoryRange.start != newMinRam || _memoryRange.end != newMaxRam) {
        _memoryRange = RangeValues(newMinRam, newMaxRam);
        if (mounted) setState(() {});
      }
      if (_jvmArgsController.text != newArgs) {
        _jvmArgsController.text = newArgs;
      }
      if (_javaPathController.text != newPath) {
        _javaPathController.text = newPath;
      }

      final newLoaderName = inst.loader.name == 'vanilla'
          ? 'Vanilla'
          : inst.loader.name == 'fabric'
              ? 'Fabric'
              : inst.loader.name == 'forge'
                  ? 'Forge'
                  : inst.loader.name == 'neoforge'
                      ? 'NeoForge'
                      : inst.loader.name == 'quilt'
                          ? 'Quilt'
                          : 'Vanilla';

      if (_version != inst.minecraftVersion ||
          _loader != newLoaderName ||
          _loaderVersion != inst.loaderVersion) {
        _version = inst.minecraftVersion;
        _loader = newLoaderName;
        _loaderVersion = inst.loaderVersion;
        needsRebuild = true;
      }

      if (needsRebuild && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _jvmArgsController.dispose();
    _javaPathController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: Text('Delete Instance?',
            style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
        content: Text(
          'This will permanently delete the instance and all of its files. This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(color: colors.textMed),
        ),
        actionsPadding: const EdgeInsets.all(AppSpacing.px16),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      ref.read(instancesProvider.notifier).deleteInstance(widget.instanceId);
      context.go('/instances');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final instList = ref.watch(instancesProvider).value ?? [];
    if (instList.isEmpty) return const SizedBox();

    Instance? inst;
    try {
      inst = instList.firstWhere((e) => e.id == widget.instanceId);
    } catch (_) {
      return const SizedBox();
    }

    final isEnabled = !_followGlobal;
    final opacity = isEnabled ? 1.0 : 0.5;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.px24),
      children: [
        Text('Instance Settings',
            style:
                AppTypography.headlineMedium.copyWith(color: colors.textHigh)),
        const SizedBox(height: AppSpacing.px24),
        if (inst.sourceModpackId == null) ...[

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version & Loader',
                    style: AppTypography.titleSmall
                        .copyWith(color: colors.textHigh)),
                const SizedBox(height: AppSpacing.px8),
                Text(
                    'Change the Minecraft version and mod loader. Note that this might break compatibility with your existing mods.',
                    style: AppTypography.bodySmall
                        .copyWith(color: colors.textLow)),
                const SizedBox(height: AppSpacing.px16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Minecraft Version',
                              style: AppTypography.labelLarge
                                  .copyWith(color: colors.textMed)),
                          const SizedBox(height: AppSpacing.px8),
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.px12),
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: colors.glassBorder),
                            ),
                            child: ref.watch(vanillaVersionsProvider).when(
                                  data: (versions) {
                                    final filtered = versions
                                        .where((v) {
                                          return _showSnapshots ||
                                              v.versionType == 'release';
                                        })
                                        .map((v) => v.id)
                                        .toList();

                                    if (_version == null ||
                                        (!filtered.contains(_version) &&
                                            _version!.isNotEmpty)) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted && filtered.isNotEmpty) {
                                          setState(
                                              () => _version = filtered.first);
                                        }
                                      });
                                    }

                                    return DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: filtered.contains(_version)
                                            ? _version
                                            : (filtered.isNotEmpty
                                                ? filtered.first
                                                : null),
                                        isExpanded: true,
                                        dropdownColor: colors.surfaceElevated,
                                        icon: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: colors.textLow),
                                        style: AppTypography.bodyMedium
                                            .copyWith(color: colors.textHigh),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _version = v;
                                              if (!_availableLoaders
                                                  .contains(_loader)) {
                                                _loader = 'Vanilla';
                                                _loaderVersion = null;
                                              }
                                            });
                                            _applyVersionChanges();
                                          }
                                        },
                                        items: filtered.map((v) {
                                          return DropdownMenuItem(
                                              value: v, child: Text(v));
                                        }).toList(),
                                      ),
                                    );
                                  },
                                  loading: () => const Center(
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                  error: (e, st) => Text('Error',
                                      style: TextStyle(color: colors.danger)),
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.px16),
                    Row(
                      children: [
                        Text('Show Snapshots',
                            style: AppTypography.labelLarge
                                .copyWith(color: colors.textMed)),
                        const SizedBox(width: AppSpacing.px8),
                        Switch(
                          value: _showSnapshots,
                          onChanged: (v) => setState(() => _showSnapshots = v),
                          activeThumbColor: colors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.px20),

                Text('Mod Loader',
                    style: AppTypography.labelLarge
                        .copyWith(color: colors.textMed)),
                const SizedBox(height: AppSpacing.px8),
                Wrap(
                  spacing: AppSpacing.px8,
                  runSpacing: AppSpacing.px8,
                  children: _availableLoaders.map((l) {
                    final isSelected = _loader == l;
                    return ActionChip(
                      avatar: BrandIcon(
                        type: BrandIconType.fromName(l),
                        size: 16,
                      ),
                      label: Text(l),
                      labelStyle: AppTypography.labelLarge.copyWith(
                        color: isSelected ? colors.background : colors.textMed,
                      ),
                      backgroundColor:
                          isSelected ? colors.primary : colors.surfaceElevated,
                      side: BorderSide(
                          color:
                              isSelected ? colors.primary : colors.glassBorder),
                      onPressed: () => setState(() {
                        _loader = l;
                        _loaderVersion = null;
                      }),
                    );
                  }).toList(),
                ),

                if (_loader != 'Vanilla') ...[
                  const SizedBox(height: AppSpacing.px20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_loader Version',
                          style: AppTypography.labelLarge
                              .copyWith(color: colors.textMed)),
                      Row(
                        children: [
                          Text('Show All',
                              style: AppTypography.labelSmall
                                  .copyWith(color: colors.textLow)),
                          SizedBox(
                            height: 24,
                            width: 32,
                            child: Checkbox(
                              value: _showAllLoaderVersions,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _showAllLoaderVersions = v;
                                    _loaderVersion = null;
                                  });
                                  _applyVersionChanges();
                                }
                              },
                              fillColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? colors.primary
                                          : Colors.transparent),
                              side: BorderSide(color: colors.textLow),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.px8),
                  Container(
                    height: 36,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.px12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: _getLoaderVersions(_loader)?.when(
                          data: (versions) {
                            var filteredVersions = versions.toList();

                            if (['Forge', 'NeoForge'].contains(_loader)) {
                              filteredVersions =
                                  filteredVersions.reversed.toList();
                            }

                            if (!_showAllLoaderVersions) {
                              if (_loader == 'Forge' && _version != null) {
                                filteredVersions = filteredVersions
                                    .where((v) => v.startsWith('$_version-'))
                                    .toList();
                              } else if (_loader == 'NeoForge' &&
                                  _version != null) {
                                String prefix;
                                if (_version!.startsWith('1.')) {
                                  final parts = _version!.split('.');
                                  final minor =
                                      parts.length > 1 ? parts[1] : '0';
                                  final patch =
                                      parts.length > 2 ? parts[2] : '0';
                                  prefix = patch == '0'
                                      ? '$minor.'
                                      : '$minor.$patch.';
                                } else {

                                  prefix = '$_version.';
                                }

                                filteredVersions = filteredVersions
                                    .where((v) => v.startsWith(prefix))
                                    .toList();
                              }
                            }

                            if (filteredVersions.isEmpty)
                              return const Text('No versions available');

                            final limit = _showAllLoaderVersions
                                ? filteredVersions.length
                                : (filteredVersions.length > 30
                                    ? 30
                                    : filteredVersions.length);
                            final displayVersions =
                                filteredVersions.take(limit).toList();

                            if (_loaderVersion == null ||
                                !displayVersions.contains(_loaderVersion)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && displayVersions.isNotEmpty) {
                                  setState(() =>
                                      _loaderVersion = displayVersions.first);
                                  _applyVersionChanges();
                                }
                              });
                            }

                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: displayVersions.contains(_loaderVersion)
                                    ? _loaderVersion
                                    : (displayVersions.isNotEmpty
                                        ? displayVersions.first
                                        : null),
                                isExpanded: true,
                                dropdownColor: colors.surfaceElevated,
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: colors.textLow),
                                style: AppTypography.bodyMedium
                                    .copyWith(color: colors.textHigh),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _loaderVersion = v);
                                    _applyVersionChanges();
                                  }
                                },
                                items: displayVersions.map((v) {
                                  return DropdownMenuItem(
                                      value: v, child: Text(v));
                                }).toList(),
                              ),
                            );
                          },
                          loading: () => const Center(
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                          error: (e, st) => Text('Error loading',
                              style: TextStyle(color: colors.danger)),
                        ) ??
                        const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.px24),
        ],

        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Follow Global Settings',
                        style: AppTypography.titleSmall
                            .copyWith(color: colors.textHigh)),
                    const SizedBox(height: 3),
                    Text(
                        'Use the memory and Java settings defined in the main launcher settings.',
                        style: AppTypography.bodySmall
                            .copyWith(color: colors.textLow)),
                  ],
                ),
              ),
              Switch(
                value: _followGlobal,
                onChanged: (v) {
                  setState(() => _followGlobal = v);
                  _saveToInstance();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.px24),

        Opacity(
          opacity: opacity,
          child: IgnorePointer(
            ignoring: !isEnabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Memory Allocation',
                              style: AppTypography.titleSmall
                                  .copyWith(color: colors.textHigh)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primaryMuted,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Text(
                              '${(_memoryRange.start / 1024).toStringAsFixed(1)} GB - ${(_memoryRange.end / 1024).toStringAsFixed(1)} GB',
                              style: AppTypography.labelLarge
                                  .copyWith(color: colors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.px12),
                      SliderTheme(
                        data: SliderTheme.of(context),
                        child: RangeSlider(
                          values: _memoryRange,
                          min: 512,
                          max: 32768,
                          divisions: 63,
                          labels: RangeLabels(
                            '${_memoryRange.start.toInt()} MB',
                            '${_memoryRange.end.toInt()} MB',
                          ),
                          onChanged: (v) {
                            setState(() => _memoryRange = v);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('512 MB',
                              style: AppTypography.labelSmall
                                  .copyWith(color: colors.textLow)),
                          Text('32 GB',
                              style: AppTypography.labelSmall
                                  .copyWith(color: colors.textLow)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.px8),
                      Text(
                        'To use a custom value, add -Xms<value> or -Xmx<value> in JVM Arguments below.',
                        style: AppTypography.labelSmall.copyWith(
                            color: colors.textLow, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.px16),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JVM Arguments',
                          style: AppTypography.titleSmall
                              .copyWith(color: colors.textHigh)),
                      const SizedBox(height: AppSpacing.px8),
                      Text(
                          'Custom flags to pass to the Java Virtual Machine for this instance.',
                          style: AppTypography.bodySmall
                              .copyWith(color: colors.textLow)),
                      const SizedBox(height: AppSpacing.px12),
                      TextField(
                        controller: _jvmArgsController,
                        maxLines: 3,
                        style: TextStyle(color: colors.textHigh),
                        onChanged: (_) {},
                        decoration: InputDecoration(
                          hintText:
                              '-XX:+UseG1GC -Dsun.rmi.dgc.server.gcInterval=2147483646...',
                          hintStyle: TextStyle(color: colors.textLow),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.all(AppSpacing.px12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.px16),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Java Executable',
                          style: AppTypography.titleSmall
                              .copyWith(color: colors.textHigh)),
                      const SizedBox(height: AppSpacing.px8),
                      Text(
                          'Select an installed JRE or browse for a custom path.',
                          style: AppTypography.bodySmall
                              .copyWith(color: colors.textLow)),
                      const SizedBox(height: AppSpacing.px12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _javaPathController,
                              style: TextStyle(color: colors.textHigh),
                              onChanged: (_) {},
                              decoration: InputDecoration(
                                hintText: 'Enter custom Java executable path',
                                hintStyle: TextStyle(color: colors.textLow),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.px12),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.px12),
                          AppButton(
                            label: 'Browse',
                            onPressed: () async {
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles();
                              if (result != null &&
                                  result.files.single.path != null) {
                                _javaPathController.text =
                                    result.files.single.path!;
                              }
                            },
                            variant: AppButtonVariant.outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_followGlobal) ...[
          const SizedBox(height: AppSpacing.px16),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Save Java Settings',
              icon: Icons.save_rounded,
              onPressed: () async {
                await _saveToInstance();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Instance Java settings saved!')),
                  );
                }
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.px32),

        if (inst.sourceModpackId != null) ...[
          _ModpackUpdatesSection(instance: inst),
          const SizedBox(height: AppSpacing.px32),
        ],

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Danger Zone',
                  style: AppTypography.titleSmall
                      .copyWith(color: Colors.redAccent)),
              const SizedBox(height: AppSpacing.px8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Permanently delete this instance and all of its files. This action cannot be undone.',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textLow),
                    ),
                  ),
                  AppButton(
                    label: 'Delete Instance',
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => _confirmDelete(context),
                    variant: AppButtonVariant.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModpackUpdatesSection extends ConsumerStatefulWidget {
  const _ModpackUpdatesSection({required this.instance});
  final Instance instance;

  @override
  ConsumerState<_ModpackUpdatesSection> createState() =>
      _ModpackUpdatesSectionState();
}

class _ModpackUpdatesSectionState
    extends ConsumerState<_ModpackUpdatesSection> {
  bool _isChecking = false;

  Future<void> _checkForUpdates() async {
    final colors = context.colors;
    setState(() => _isChecking = true);
    try {
      final isNumeric = int.tryParse(widget.instance.sourceModpackId!) != null;

      List<dynamic> versions;
      String sourceName;
      if (isNumeric) {
        final api = CurseForgeApiProvider();
        versions = await api.getVersions(widget.instance.sourceModpackId!);
        sourceName = 'curseforge';
      } else {
        final api = ModrinthApiProvider();
        versions = await api.getVersions(widget.instance.sourceModpackId!);
        sourceName = 'modrinth';
      }

      if (!mounted) return;
      setState(() => _isChecking = false);

      final compatibleVersions = versions.where((v) {
        if (widget.instance.loader.name != 'vanilla') {
          return v.loaders.contains(widget.instance.loader.name);
        }
        return true;
      }).toList();

      if (compatibleVersions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No compatible updates found.')),
        );
        return;
      }

      final RemoteMod remoteMod = RemoteMod(
        id: widget.instance.sourceModpackId!,
        slug: widget.instance.sourceModpackId!,
        title: 'Modpack Update',
        description: 'Update for Modpack',
        author: 'Unknown',
        downloadCount: 0,
        iconUrl: '',
        categories: [],
        source: sourceName,
      );

      _showUpdateDialog(remoteMod, compatibleVersions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking for updates: $e')),
      );
    }
  }

  void _showUpdateDialog(RemoteMod mod, List<dynamic> versions) {
    final colors = context.colors;
    bool overwriteConfig = false;
    dynamic selectedVersion = versions.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: colors.glassBorder),
              ),
              title: Text('Update Modpack',
                  style: AppTypography.titleLarge
                      .copyWith(color: colors.textHigh)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a version to update to. WARNING: This will overwrite your existing mods folder. Please make a backup if you added custom mods.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: Colors.redAccent),
                    ),
                    const SizedBox(height: AppSpacing.px16),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.px12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: colors.glassBorder),
                        ),
                        child: DropdownButton<dynamic>(
                          value: selectedVersion,
                          isExpanded: true,
                          dropdownColor: colors.surfaceElevated,
                          style: AppTypography.bodyMedium
                              .copyWith(color: colors.textHigh),
                          items: versions.map((v) {
                            final name = v.name;
                            final isCurrent =
                                v.id == widget.instance.sourceModpackVersionId;
                            return DropdownMenuItem(
                              value: v,
                              child: Text(isCurrent ? '$name (Current)' : name),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null)
                              setStateDialog(() => selectedVersion = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.px16),
                    Row(
                      children: [
                        Checkbox(
                          value: overwriteConfig,
                          onChanged: (v) {
                            setStateDialog(() => overwriteConfig = v ?? false);
                          },
                          fillColor: WidgetStateProperty.resolveWith((states) =>
                              states.contains(WidgetState.selected)
                                  ? colors.primary
                                  : Colors.transparent),
                          side: BorderSide(color: colors.textLow),
                        ),
                        Expanded(
                          child: Text(
                            'Overwrite Configs & Options',
                            style: AppTypography.bodyMedium
                                .copyWith(color: colors.textMed),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        'Checking this will replace your existing settings with the new modpack version defaults.',
                        style: AppTypography.bodySmall
                            .copyWith(color: colors.textLow),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.all(AppSpacing.px16),
              actions: [
                AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                AppButton(
                  label: 'Update',
                  icon: Icons.system_update_alt_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(downloadsProvider.notifier).installModpack(
                          mod,
                          selectedVersion,
                          updateInstance: widget.instance,
                          overwriteConfig: overwriteConfig,
                        );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modpack Updates',
              style: AppTypography.titleSmall.copyWith(color: colors.textHigh)),
          const SizedBox(height: AppSpacing.px8),
          Text(
            'Check for new versions of this modpack on Modrinth.',
            style: AppTypography.bodySmall.copyWith(color: colors.textLow),
          ),
          const SizedBox(height: AppSpacing.px16),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: _isChecking ? 'Checking...' : 'Check for Updates',
              icon: Icons.refresh_rounded,
              onPressed: _isChecking ? () {} : _checkForUpdates,
              variant: AppButtonVariant.outline,
            ),
          ),
        ],
      ),
    );
  }
}
