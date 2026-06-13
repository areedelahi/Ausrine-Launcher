import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../domain/user_account.dart';
import 'auth_provider.dart';

class SkinDialog extends ConsumerStatefulWidget {
  const SkinDialog({
    super.key,
    required this.account,
  });

  final UserAccount account;

  static Future<void> show(
    BuildContext context, {
    required UserAccount account,
  }) {
    return GlassDialog.show<void>(
      context: context,
      title: 'Change Appearance',
      icon: Icons.checkroom_rounded,
      child: SkinDialog(account: account),
      actions: const [], 
    );
  }

  @override
  ConsumerState<SkinDialog> createState() => _SkinDialogState();
}

class _SkinDialogState extends ConsumerState<SkinDialog> {
  String? _selectedPath;
  String _variant = 'classic'; 
  bool _uploading = false;
  String? _error;
  String? _selectedCapeId;

  @override
  void initState() {
    super.initState();
    _selectedCapeId = widget.account.activeCapeId;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedPath = result.files.single.path;
        _error = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_selectedPath == null) {
      setState(() => _error = 'Please select a PNG skin file first.');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).uploadSkin(
            uuid: widget.account.uuid,
            filePath: _selectedPath!,
            variant: _variant,
          );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Skin uploaded! It may take 1-2 minutes to show up.'),
            backgroundColor: context.colors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _updateCape(String? capeId) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).setCape(
            uuid: widget.account.uuid,
            capeId: capeId,
          );
      setState(() {
        _selectedCapeId = capeId;
        _uploading = false;
      });
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Cape updated! It may take 1-2 minutes to show up.'),
            backgroundColor: context.colors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Cape update failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasFile = _selectedPath != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Upload a custom 64×64 PNG skin file to change your Minecraft character appearance.',
                style: AppTypography.bodyMedium.copyWith(color: colors.textMed),
              ),
            ),
            if (widget.account.skinUrl != null) ...[
              const SizedBox(width: AppSpacing.px12),
              AppButton(
                label: 'Backup Current',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
                onPressed: () {
                  final secureUrl = widget.account.skinUrl!
                      .replaceFirst('http://', 'https://');
                  launchUrl(Uri.parse(secureUrl));
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.px16),

        Row(
          children: [
            AppButton(
              label: hasFile ? 'Change File' : 'Select PNG…',
              icon: Icons.upload_file_rounded,
              onPressed: _uploading ? null : _pickFile,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.small,
            ),
            const SizedBox(width: AppSpacing.px12),
            if (hasFile)
              Expanded(
                child: Text(
                  _selectedPath!.split(Platform.pathSeparator).last,
                  style:
                      AppTypography.bodySmall.copyWith(color: colors.textMed),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                'No file selected',
                style: AppTypography.bodySmall
                    .copyWith(color: colors.textDisabled),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.px16),

        if (hasFile) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Image.file(
              File(_selectedPath!),
              width: 96,
              height: 96,
              filterQuality: FilterQuality.none, 
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(Icons.broken_image_rounded,
                    color: colors.textDisabled, size: 32),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.px16),
        ],

        Text(
          'Skin Model',
          style: AppTypography.labelLarge.copyWith(color: colors.textMed),
        ),
        const SizedBox(height: AppSpacing.px8),
        Row(
          children: [
            _ModelChip(
              label: 'Classic',
              selected: _variant == 'classic',
              onTap: _uploading
                  ? null
                  : () => setState(() => _variant = 'classic'),
            ),
            const SizedBox(width: AppSpacing.px8),
            _ModelChip(
              label: 'Slim (Alex)',
              selected: _variant == 'slim',
              onTap:
                  _uploading ? null : () => setState(() => _variant = 'slim'),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.px24),
        Divider(color: colors.divider),
        const SizedBox(height: AppSpacing.px16),

        Text(
          'Active Cape',
          style: AppTypography.labelLarge.copyWith(color: colors.textMed),
        ),
        const SizedBox(height: AppSpacing.px8),
        if (widget.account.capes.isEmpty)
          Text(
            'You do not own any capes.',
            style: AppTypography.bodySmall.copyWith(color: colors.textDisabled),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: colors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedCapeId,
                isExpanded: true,
                dropdownColor: colors.surfaceElevated,
                icon: Icon(Icons.expand_more_rounded, color: colors.textMed),
                style:
                    AppTypography.bodyMedium.copyWith(color: colors.textHigh),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No Cape'),
                  ),
                  ...widget.account.capes.map((c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.alias),
                      )),
                ],
                onChanged: _uploading ? null : _updateCape,
              ),
            ),
          ),

        if (_error != null) ...[
          const SizedBox(height: AppSpacing.px12),
          Text(
            _error!,
            style: AppTypography.bodySmall.copyWith(color: colors.danger),
          ),
        ],

        const SizedBox(height: AppSpacing.px20),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onPressed: _uploading
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).pop(),
            ),
            const SizedBox(width: AppSpacing.px8),
            AppButton(
              label: _uploading ? 'Uploading…' : 'Upload Skin',
              icon: _uploading ? null : Icons.check_rounded,
              onPressed: _uploading ? null : _upload,
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.primary : colors.textLow;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.px12,
          vertical: AppSpacing.px8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: selected
                ? colors.primary.withValues(alpha: 0.6)
                : colors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(color: color),
        ),
      ),
    );
  }
}
