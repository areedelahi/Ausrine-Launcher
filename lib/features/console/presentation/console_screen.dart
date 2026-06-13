import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../instances/domain/providers/instance_provider.dart';
import '../../instances/data/instance_repository.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConsoleScreen extends ConsumerStatefulWidget {
  const ConsoleScreen({super.key});
  @override
  ConsumerState<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends ConsumerState<ConsoleScreen> {
  String? _selectedInstanceId;
  String? _logContent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultInstance();
    });
  }

  void _initDefaultInstance() {
    final instances = ref.read(instancesProvider).value ?? [];
    if (instances.isNotEmpty) {
      setState(() {
        _selectedInstanceId = instances.first.id;
      });
      _loadLog(instances.first.id);
    }
  }

  Future<void> _loadLog(String instanceId) async {
    setState(() {
      _isLoading = true;
      _logContent = null;
    });

    try {
      final repo = ref.read(instanceRepositoryProvider);
      final path = await repo.getInstancePath(instanceId);
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

  Future<void> _openLogsFolder() async {
    if (_selectedInstanceId == null) return;
    final repo = ref.read(instanceRepositoryProvider);
    final path = await repo.getInstancePath(_selectedInstanceId!);
    final logsPath = '$path/logs';

    final dir = Directory(logsPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final uri = Uri.directory(logsPath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallbackUri = Uri.parse('file://$logsPath');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final instances = ref.watch(instancesProvider).value ?? [];

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
              SvgPicture.asset(
                'assets/images/heading_logo.svg',
                height: 28,
              ),
              const SizedBox(width: AppSpacing.px12),
              Text('Logs',
                  style: AppTypography.titleLarge
                      .copyWith(color: colors.textHigh)),
              const SizedBox(width: AppSpacing.px24),
              if (instances.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.glassBorder),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    color: colors.glass,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedInstanceId,
                      dropdownColor: colors.surface,
                      icon: Icon(Icons.arrow_drop_down, color: colors.textMed),
                      style: AppTypography.bodyMedium.copyWith(color: colors.textHigh),
                      items: instances.map((inst) {
                        return DropdownMenuItem(
                          value: inst.id,
                          child: Text(inst.name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedInstanceId = v;
                          });
                          _loadLog(v);
                        }
                      },
                    ),
                  ),
                ),
              const Spacer(),
              AppButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: () {
                  if (_selectedInstanceId != null) {
                    _loadLog(_selectedInstanceId!);
                  }
                },
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.small,
              ),
              const SizedBox(width: AppSpacing.px8),
              AppButton(
                label: 'Open Logs Folder',
                icon: Icons.folder_open_rounded,
                onPressed: _openLogsFolder,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: const Color(0xFF090B0F),
            padding: const EdgeInsets.all(AppSpacing.px12),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : SingleChildScrollView(
                    child: SelectableText(
                      _logContent ?? 'Select an instance to view logs.',
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
