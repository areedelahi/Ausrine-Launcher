import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_icon.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/models/instance.dart';
import '../domain/providers/instance_provider.dart';
import '../domain/providers/version_metadata_provider.dart';
import '../../downloads/domain/providers/downloads_provider.dart';

class CreateInstanceDialog extends ConsumerStatefulWidget {
  const CreateInstanceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const CreateInstanceDialog(),
    );
  }

  @override
  ConsumerState<CreateInstanceDialog> createState() =>
      _CreateInstanceDialogState();
}

class _CreateInstanceDialogState extends ConsumerState<CreateInstanceDialog> {
  String _name = '';
  String? _version;
  bool _showSnapshots = false;
  String _loader = 'Vanilla';
  String? _loaderVersion;
  bool _showAllLoaderVersions = false;

  final _loaders = ['Vanilla', 'Fabric', 'Forge', 'NeoForge', 'Quilt'];

  List<String> get _availableLoaders {
    if (_version == null) return _loaders;
    return _loaders.where((l) => _isVersionSupportedByLoader(_version!, l)).toList();
  }

  bool _isVersionSupportedByLoader(String mcVersion, String loader) {
    if (loader == 'Vanilla') return true;

    final parts = mcVersion.split('.');
    if (parts.isEmpty) return true;

    final major = int.tryParse(parts[0]) ?? 1;
    final minor = parts.length > 1 ? int.tryParse(parts[1].split(RegExp(r'[-a-zA-Z]'))[0]) ?? 0 : 0;
    final patch = parts.length > 2 ? int.tryParse(parts[2].split(RegExp(r'[-a-zA-Z]'))[0]) ?? 0 : 0;

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

  String _generateId(String name) {
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (slug.isEmpty)
      return 'new_instance_${DateTime.now().millisecondsSinceEpoch}';
    return slug;
  }

  void _createInstance() {
    if (_name.isEmpty || _version == null) return;
    if (_loader != 'Vanilla' && _loaderVersion == null) return;

    final newInstance = Instance(
      id: _generateId(_name),
      name: _name,
      minecraftVersion: _version!,
      loader: ModLoader.fromString(_loader),
      loaderVersion: _loader == 'Vanilla' ? null : _loaderVersion,
      icon: 'grass_block', 
      playTimeMs: 0,
    );

    ref.read(instancesProvider.notifier).addInstance(newInstance);
    ref.read(downloadsProvider.notifier).startDownload(newInstance);

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final vanillaAsync = ref.watch(vanillaVersionsProvider);
    final modLoaderAsync = _getLoaderVersions(_loader);

    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: BorderSide(color: colors.glassBorder),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.px24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Icon(Icons.add_box_rounded, color: colors.primary, size: 28),
                const SizedBox(width: AppSpacing.px12),
                Text('Create Instance',
                    style: AppTypography.titleLarge
                        .copyWith(color: colors.textHigh)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textLow),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.px24),

            Text('Name',
                style:
                    AppTypography.labelLarge.copyWith(color: colors.textMed)),
            const SizedBox(height: AppSpacing.px8),
            AppTextField(
              hint: 'e.g. My Awesome Modpack',
              onChanged: (v) => setState(() => _name = v),
            ),
            const SizedBox(height: AppSpacing.px20),

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
                        child: vanillaAsync.when(
                          data: (versions) {
                            final filtered = versions.where((v) {
                              return _showSnapshots || v.versionType == 'release';
                            }).map((v) => v.id).toList();

                            if (_version == null || !filtered.contains(_version)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && filtered.isNotEmpty) {
                                  setState(() => _version = filtered.first);
                                }
                              });
                            }

                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _version,
                                isExpanded: true,
                                dropdownColor: colors.surfaceElevated,
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: colors.textLow),
                                style: AppTypography.bodyMedium
                                    .copyWith(color: colors.textHigh),
                                onChanged: (v) {
                                  if (v != null) setState(() {
                                    _version = v;
                                    if (!_availableLoaders.contains(_loader)) {
                                      _loader = 'Vanilla';
                                      _loaderVersion = null;
                                    }
                                  });
                                },
                                items: filtered.map((v) {
                                  return DropdownMenuItem(value: v, child: Text(v));
                                }).toList(),
                              ),
                            );
                          },
                          loading: () => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (e, st) {
                            print("Forge error: $e");
                            return Text('Error loading', style: TextStyle(color: colors.danger));
                          },
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
                style:
                    AppTypography.labelLarge.copyWith(color: colors.textMed)),
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
                      color: isSelected ? colors.primary : colors.glassBorder),
                  onPressed: () => setState(() {
                    _loader = l;
                    _loaderVersion = null; 
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.px20),

            if (_loader != 'Vanilla')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_loader Version',
                          style: AppTypography.labelLarge
                              .copyWith(color: colors.textMed)),
                      Row(
                        children: [
                          Text('Show All', style: AppTypography.labelSmall.copyWith(color: colors.textLow)),
                          SizedBox(
                            height: 24,
                            width: 32,
                            child: Checkbox(
                              value: _showAllLoaderVersions,
                              onChanged: (v) {
                                setState(() {
                                  _showAllLoaderVersions = v ?? false;
                                  _loaderVersion = null; 
                                });
                              },
                              fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? colors.primary : Colors.transparent),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.px12),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: colors.glassBorder),
                    ),
                    child: modLoaderAsync?.when(
                          data: (versions) {
                            var filteredVersions = versions.toList();

                            if (['Forge', 'NeoForge'].contains(_loader)) {
                              filteredVersions = filteredVersions.reversed.toList();
                            }

                            if (!_showAllLoaderVersions) {
                              if (_loader == 'Forge' && _version != null) {
                                filteredVersions = filteredVersions.where((v) => v.startsWith('$_version-')).toList();
                              } else if (_loader == 'NeoForge' && _version != null) {
                                String prefix;
                                if (_version!.startsWith('1.')) {
                                  final parts = _version!.split('.');
                                  final minor = parts.length > 1 ? parts[1] : '0';
                                  final patch = parts.length > 2 ? parts[2] : '0';
                                  prefix = patch == '0' ? '$minor.' : '$minor.$patch.';
                                } else {

                                  prefix = '$_version.';
                                }
                                filteredVersions = filteredVersions.where((v) => v.startsWith(prefix)).toList();
                              }
                            }

                            if (filteredVersions.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No versions found. Try checking "Show All".', style: TextStyle(color: colors.textLow, fontSize: 12)),
                              );
                            }

                            if (_loaderVersion == null || !filteredVersions.contains(_loaderVersion)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && filteredVersions.isNotEmpty) {
                                  setState(() => _loaderVersion = filteredVersions.first);
                                }
                              });
                            }

                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _loaderVersion,
                                isExpanded: true,
                                dropdownColor: colors.surfaceElevated,
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: colors.textLow),
                                style: AppTypography.bodyMedium
                                    .copyWith(color: colors.textHigh),
                                onChanged: (v) {
                                  if (v != null) setState(() => _loaderVersion = v);
                                },
                                items: filteredVersions.map((v) {
                                  return DropdownMenuItem(value: v, child: Text(v));
                                }).toList(),
                              ),
                            );
                          },
                          loading: () => const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                          error: (e, st) {
                            print("Forge error: $e");
                            return Text('Error loading', style: TextStyle(color: colors.danger));
                          },
                        ) ??
                        const SizedBox.shrink(),
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.px32),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  variant: AppButtonVariant.ghost,
                ),
                const SizedBox(width: AppSpacing.px12),
                AppButton(
                  label: 'Create',
                  icon: Icons.add_rounded,
                  onPressed: (_name.isEmpty || _version == null || (_loader != 'Vanilla' && _loaderVersion == null)) 
                      ? null 
                      : _createInstance,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}
