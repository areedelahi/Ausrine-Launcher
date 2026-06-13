import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'instance_card.dart';
import 'create_instance_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../domain/providers/instance_provider.dart';
import '../data/instance_repository.dart';

Future<void> _openFolder(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', [path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  }
}

class InstancesScreen extends ConsumerStatefulWidget {
  const InstancesScreen({super.key});

  @override
  ConsumerState<InstancesScreen> createState() => _InstancesScreenState();
}

class _InstancesScreenState extends ConsumerState<InstancesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final instancesAsync = ref.watch(instancesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _Toolbar(
          onSearchChanged: (v) => setState(() => _search = v),
          onNewInstance: () => _showNewInstanceDialog(context),
          onSortAlphabetically: () {
            ref.read(instancesProvider.notifier).sortAlphabetically();
          },
          onRefresh: () {
            ref.read(instancesProvider.notifier).loadInstances();
          },
        ),

        Expanded(
          child: instancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (instances) {
              final filtered = instances
                  .where((i) =>
                      _search.isEmpty ||
                      i.name.toLowerCase().contains(_search.toLowerCase()) ||
                      i.minecraftVersion
                          .toLowerCase()
                          .contains(_search.toLowerCase()) ||
                      i.loader.name
                          .toLowerCase()
                          .contains(_search.toLowerCase()))
                  .toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                    onNew: () => _showNewInstanceDialog(context));
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.px16),
                child: ReorderableGridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: AppSpacing.instanceCardWidth + 20,
                    mainAxisSpacing: AppSpacing.px12,
                    crossAxisSpacing: AppSpacing.px12,
                    childAspectRatio: AppSpacing.instanceCardWidth / AppSpacing.instanceCardHeight,
                  ),
                  dragStartDelay: const Duration(milliseconds: 250),
                  onReorder: (oldIndex, newIndex) {
                    ref.read(instancesProvider.notifier).reorderInstances(oldIndex, newIndex);
                  },
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final inst = filtered[index];
                    return InstanceCard(
                      key: ValueKey(inst.id),
                      name: inst.name,
                      version: inst.minecraftVersion,
                      icon: inst.icon,
                      loader: inst.loader.displayName,
                      loaderVersion: inst.loaderVersion ?? '',
                      modsCount: 0, 
                      lastPlayed: inst.lastPlayed != null
                          ? '${inst.lastPlayed!.day}/${inst.lastPlayed!.month}/${inst.lastPlayed!.year}'
                          : 'Never played',
                      isRunning: false, 
                      iconColor: _getColorForLoader(inst.loader.name),
                      isSelected: ref.watch(selectedInstanceIdProvider) == inst.id,
                      onTap: () {
                        ref.read(selectedInstanceIdProvider.notifier).state = inst.id;
                      },
                      onPlay: () {},
                      onSettingsTap: () {
                        ref.read(selectedInstanceIdProvider.notifier).state = inst.id;
                        context.go('/instances/${inst.id}');
                      },
                      onOpenFolderTap: () async {
                        final repo =
                            ref.read(instanceRepositoryProvider);
                        final path =
                            await repo.getInstancePath(inst.id);
                        _openFolder(path);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getColorForLoader(String loaderName) {
    switch (loaderName.toLowerCase()) {
      case 'fabric':
        return const Color(0xFF4DFFB0);
      case 'forge':
        return const Color(0xFFE88C30);
      case 'neoforge':
        return const Color(0xFFFFA500);
      case 'quilt':
        return const Color(0xFF9B59B6);
      default:
        return const Color(0xFF4DFFB0);
    }
  }

  void _showNewInstanceDialog(BuildContext context) {
    CreateInstanceDialog.show(context);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onSearchChanged, required this.onNewInstance, required this.onSortAlphabetically, required this.onRefresh});
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNewInstance;
  final VoidCallback onSortAlphabetically;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/heading_logo.svg',
            height: 28,
          ),
          const SizedBox(width: AppSpacing.px12),
          Text(
            'Instances',
            style: AppTypography.titleLarge.copyWith(color: colors.textHigh),
          ),
          const SizedBox(width: AppSpacing.px24),

          SizedBox(
            width: 220,
            child: AppTextField(
              hint: 'Search instances…',
              prefixIcon: Icons.search_rounded,
              onChanged: onSearchChanged,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textMed),
            tooltip: 'Refresh Instances',
            onPressed: onRefresh,
          ),
          IconButton(
            icon: Icon(Icons.sort_by_alpha_rounded, color: colors.textMed),
            tooltip: 'Sort Alphabetically',
            onPressed: onSortAlphabetically,
          ),
          const SizedBox(width: AppSpacing.px8),
          AppButton(
            label: 'New Instance',
            icon: Icons.add_rounded,
            onPressed: onNewInstance,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 56,
            color: colors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.px16),
          Text(
            'No instances yet',
            style: AppTypography.headlineMedium.copyWith(
              color: colors.textMed,
            ),
          ),
          const SizedBox(height: AppSpacing.px8),
          Text(
            'Create your first instance to start playing.',
            style: AppTypography.bodyMedium.copyWith(color: colors.textLow),
          ),
          const SizedBox(height: AppSpacing.px24),
          AppButton(
            label: 'Create Instance',
            icon: Icons.add_rounded,
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

