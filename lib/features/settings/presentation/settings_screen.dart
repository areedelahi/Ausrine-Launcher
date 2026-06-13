import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/providers/settings_provider.dart';
import '../../../core/widgets/brand_icon.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedTab = 'General';

  static const _tabs = ['General', 'Java', 'About'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Container(
          width: 160,
          color: colors.sidebarBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.px16,
                    AppSpacing.px16, AppSpacing.px16, AppSpacing.px8),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/heading_logo.svg',
                      height: 24,
                    ),
                    const SizedBox(width: AppSpacing.px8),
                    Text('Settings',
                        style: AppTypography.titleSmall
                            .copyWith(color: colors.textMed)),
                  ],
                ),
              ),
              ..._tabs.map((t) => _TabItem(
                    label: t,
                    isSelected: _selectedTab == t,
                    onTap: () => setState(() => _selectedTab = t),
                  )),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: colors.divider),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.px24),
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    Widget content;
    switch (_selectedTab) {
      case 'General':
        content = _GeneralSettings(
          customDataDirectory: settings.customDataDirectory,
          onCustomDirChanged: (v) {
            settingsNotifier.updateCustomDataDirectory(v);
          },
          onSave: () async {
            bool dirChanged = await settingsNotifier.saveSettings(settings);
            if (mounted) {
              if (dirChanged) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: context.colors.surfaceElevated,
                    title: Text('Restart Required', style: AppTypography.titleMedium.copyWith(color: context.colors.textHigh)),
                    content: Text('The data directory has been changed. The application will now close so that the changes can take effect. Please manually move your old data to the new folder if needed.', style: AppTypography.bodyMedium.copyWith(color: context.colors.textMed)),
                    actions: [
                      AppButton(
                        label: 'Close App',
                        onPressed: () {
                          exit(0);
                        },
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Global settings saved!')),
                );
              }
            }
          },
        );
        break;
      case 'Java':
        content = _JavaSettings(
            memoryRange: RangeValues(
              settings.minMemoryMb.toDouble(),
              settings.maxMemoryMb.toDouble(),
            ),
            onMemChanged: (v) {
              settingsNotifier.updateMemory(v.start.toInt(), v.end.toInt());
            },
            javaExecutable: settings.javaExecutable,
            onJavaExecutableChanged: (v) {
              settingsNotifier.updateJavaExecutable(v);
            },
            jvmArgs: settings.jvmArgs,
            onJvmArgsChanged: (v) {
              settingsNotifier.updateJvmArgs(v);
            },
            onSave: () async {
              await settingsNotifier.saveSettings(settings);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Global Java settings saved!')),
                );
              }
            },
        );
        break;
      case 'About':
        content = const _AboutPanel();
        break;
      default:
        content = _JavaSettings(
            memoryRange: RangeValues(
              settings.minMemoryMb.toDouble(),
              settings.maxMemoryMb.toDouble(),
            ),
            onMemChanged: (v) {
              settingsNotifier.updateMemory(v.start.toInt(), v.end.toInt());
            },
            javaExecutable: settings.javaExecutable,
            onJavaExecutableChanged: (v) {
              settingsNotifier.updateJavaExecutable(v);
            },
            jvmArgs: settings.jvmArgs,
            onJvmArgsChanged: (v) {
              settingsNotifier.updateJvmArgs(v);
            },
            onSave: () async {
              await settingsNotifier.saveSettings(settings);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Global Java settings saved!')),
                );
              }
            },
        );
        break;
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
        if (child.key != ValueKey(_selectedTab)) {
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
        key: ValueKey(_selectedTab),
        child: content,
      ),
    );
  }
}

class _GeneralSettings extends StatelessWidget {
  const _GeneralSettings({
    required this.customDataDirectory,
    required this.onCustomDirChanged,
    required this.onSave,
  });
  final String? customDataDirectory;
  final ValueChanged<String?> onCustomDirChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Section(
      title: 'General',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_open_rounded, color: colors.textHigh, size: 20),
                  const SizedBox(width: AppSpacing.px8),
                  Text('Custom Data Directory',
                      style: AppTypography.titleSmall
                          .copyWith(color: colors.textHigh)),
                ],
              ),
              const SizedBox(height: AppSpacing.px8),
              Text(
                'Change where instances, assets, and libraries are saved. If you change this, you must manually move your old files or they won\'t show up!',
                style: AppTypography.bodySmall.copyWith(color: colors.danger),
              ),
              const SizedBox(height: AppSpacing.px12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.px12, vertical: AppSpacing.px12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.glassBorder),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        color: colors.glass,
                      ),
                      child: Text(
                        (customDataDirectory == null || customDataDirectory!.isEmpty) 
                          ? 'Default (App Support)' 
                          : customDataDirectory!,
                        style: AppTypography.bodyMedium.copyWith(color: colors.textHigh),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.px12),
                  AppButton(
                      label: 'Browse',
                      onPressed: () async {
                        final result = await getDirectoryPath(
                          confirmButtonText: 'Select',
                        );
                        if (result != null) {
                          onCustomDirChanged(result);
                        }
                      },
                      variant: AppButtonVariant.outline),
                ],
              ),
              if (customDataDirectory != null && customDataDirectory!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.px12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                        label: 'Reset to Default',
                        onPressed: () {
                          onCustomDirChanged(null);
                        },
                        variant: AppButtonVariant.ghost,
                        size: AppButtonSize.small),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.px16),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: 'Save Global Settings',
            icon: Icons.save_rounded,
            onPressed: onSave,
          ),
        ),
      ],
    );
  }
}

class _JavaSettings extends StatefulWidget {
  const _JavaSettings({
    required this.memoryRange,
    required this.onMemChanged,
    required this.javaExecutable,
    required this.onJavaExecutableChanged,
    required this.jvmArgs,
    required this.onJvmArgsChanged,
    required this.onSave,
  });
  final RangeValues memoryRange;
  final ValueChanged<RangeValues> onMemChanged;
  final String? javaExecutable;
  final ValueChanged<String?> onJavaExecutableChanged;
  final String? jvmArgs;
  final ValueChanged<String?> onJvmArgsChanged;
  final VoidCallback onSave;

  @override
  State<_JavaSettings> createState() => _JavaSettingsState();
}

class _JavaSettingsState extends State<_JavaSettings> {
  late final TextEditingController _jvmArgsController;

  @override
  void initState() {
    super.initState();
    _jvmArgsController = TextEditingController(text: widget.jvmArgs ?? '');
  }

  @override
  void didUpdateWidget(_JavaSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jvmArgs != oldWidget.jvmArgs && _jvmArgsController.text != widget.jvmArgs) {
      _jvmArgsController.text = widget.jvmArgs ?? '';
    }
  }

  @override
  void dispose() {
    _jvmArgsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Section(
      title: 'Java & Memory',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryMuted,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      '${(widget.memoryRange.start / 1024).toStringAsFixed(1)} GB - ${(widget.memoryRange.end / 1024).toStringAsFixed(1)} GB',
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
                  values: widget.memoryRange,
                  min: 512,
                  max: 32768,
                  divisions: 63,
                  labels: RangeLabels(
                    '${(widget.memoryRange.start).toInt()} MB',
                    '${(widget.memoryRange.end).toInt()} MB',
                  ),
                  onChanged: widget.onMemChanged,
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
                style: AppTypography.labelSmall.copyWith(color: colors.textLow, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('JVM Arguments',
                  style: AppTypography.titleSmall
                      .copyWith(color: colors.textHigh)),
              const SizedBox(height: AppSpacing.px8),
              Text('Custom flags to pass to the Java Virtual Machine.',
                  style:
                      AppTypography.bodySmall.copyWith(color: colors.textLow)),
              const SizedBox(height: AppSpacing.px12),
              TextField(
                controller: _jvmArgsController,
                maxLines: 3,
                style: TextStyle(color: colors.textHigh),
                onChanged: (val) {
                  widget.onJvmArgsChanged(val);
                },
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

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandIcon(type: BrandIconType.java, size: 20),
                  const SizedBox(width: AppSpacing.px8),
                  Text('Java Executable',
                      style: AppTypography.titleSmall
                          .copyWith(color: colors.textHigh)),
                ],
              ),
              const SizedBox(height: AppSpacing.px8),
              Text('Select an installed JRE or browse for a custom path.',
                  style:
                      AppTypography.bodySmall.copyWith(color: colors.textLow)),
              const SizedBox(height: AppSpacing.px12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.px12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.glassBorder),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        color: colors.glass,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: widget.javaExecutable ?? 'auto',
                          dropdownColor: colors.surface,
                          icon: Icon(Icons.arrow_drop_down,
                              color: colors.textMed),
                          style: AppTypography.bodyMedium
                              .copyWith(color: colors.textHigh),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: 'auto',
                                child: Text('System Default (Auto-detect)')),
                            if (widget.javaExecutable != null && widget.javaExecutable != 'auto')
                              DropdownMenuItem(
                                  value: widget.javaExecutable,
                                  child: Text('Custom: ${widget.javaExecutable}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            if (v == 'auto') {
                              widget.onJavaExecutableChanged(null);
                            } else {
                              widget.onJavaExecutableChanged(v);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.px12),
                  AppButton(
                      label: 'Browse',
                      onPressed: () async {
                        final typeGroup = const XTypeGroup(
                          label: 'executables',
                        );
                        final result = await openFile(
                          acceptedTypeGroups: [typeGroup],
                        );
                        if (result != null) {
                          widget.onJavaExecutableChanged(result.path);
                        }
                      },
                      variant: AppButtonVariant.outline),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.px16),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: 'Save Global Settings',
            icon: Icons.save_rounded,
            onPressed: widget.onSave,
          ),
        ),
      ],
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            children: [
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: 52,
                height: 52,
              ),
              const SizedBox(height: AppSpacing.px12),
              Text('Ausrine Launcher',
                  style: AppTypography.headlineLarge
                      .copyWith(color: colors.textHigh)),
              const SizedBox(height: 4),
              Text('Version 1.0.0',
                  style:
                      AppTypography.bodyMedium.copyWith(color: colors.textLow)),
              const SizedBox(height: 4),
              Text('Created by Areed Elahi',
                  style:
                      AppTypography.bodyMedium.copyWith(color: colors.primary)),
              const SizedBox(height: AppSpacing.px16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                      label: 'Check for Updates',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming Soon')),
                        );
                      },
                      size: AppButtonSize.small),
                  const SizedBox(width: AppSpacing.px8),
                  AppButton(
                      label: 'GitHub',
                      icon: Icons.open_in_new_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming Soon')),
                        );
                      },
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small),
                ],
              ),
              const SizedBox(height: AppSpacing.px16),
              Text(
                'NOT AN OFFICIAL MINECRAFT PRODUCT. NOT APPROVED BY OR ASSOCIATED WITH MOJANG OR MICROSOFT.',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.textLow,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                AppTypography.headlineMedium.copyWith(color: colors.textHigh)),
        const SizedBox(height: AppSpacing.px16),
        ...children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.px10),
              child: c,
            )),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.titleSmall
                        .copyWith(color: colors.textHigh)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: AppTypography.bodySmall
                        .copyWith(color: colors.textLow)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem(
      {required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.px8, vertical: 2),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.px10, vertical: AppSpacing.px8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colors.sidebarSelected
                : _hovered
                    ? colors.glass
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(widget.label,
              style: AppTypography.labelLarge.copyWith(
                  color: widget.isSelected ? colors.textHigh : colors.textMed,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }
}
