
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../domain/user_account.dart';
import 'auth_provider.dart';
import 'skin_dialog.dart';
import 'player_viewer_dialog.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toolbar(isSigningIn: auth.isSigningIn),

        if (auth.errorMessage != null)
          _ErrorBanner(
            message: auth.errorMessage!,
            onDismiss: () => ref.read(authProvider.notifier).clearError(),
          ),

        if (auth.isSigningIn) const _SignInProgress(),

        Expanded(
          child: auth.accounts.isEmpty && !auth.isSigningIn
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.px16),
                  itemCount: auth.accounts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.px8),
                  itemBuilder: (ctx, i) =>
                      _AccountTile(account: auth.accounts[i]),
                ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.isSigningIn});
  final bool isSigningIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.px16,
        vertical: AppSpacing.px8,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/heading_logo.svg',
            height: 28,
          ),
          const SizedBox(width: AppSpacing.px12),
          Text(
            'Accounts',
            style: AppTypography.titleLarge.copyWith(color: colors.textHigh),
          ),
          const Spacer(),
          AppButton(
            label: 'Add Microsoft Account',
            icon: Icons.account_circle_rounded,
            onPressed: isSigningIn
                ? null
                : () => ref.read(authProvider.notifier).loginWithMicrosoft(context),
            size: AppButtonSize.small,
          ),
          const SizedBox(width: AppSpacing.px8),
          AppButton(
            label: 'Add Offline',
            icon: Icons.person_add_rounded,
            onPressed:
                (isSigningIn || !ref.watch(authProvider).hasMicrosoftAccount)
                    ? null
                    : () => _showAddOfflineDialog(context, ref),
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  void _showAddOfflineDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    GlassDialog.show<void>(
      context: context,
      title: 'Add Offline Account',
      icon: Icons.person_add_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offline profiles can play singleplayer and LAN worlds. '
            'They cannot join servers that require online authentication.',
            style: AppTypography.bodyMedium
                .copyWith(color: context.colors.textMed),
          ),
          const SizedBox(height: AppSpacing.px16),
          AppTextField(
            controller: controller,
            hint: 'Username (e.g. Steve)',
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
          ),
        ),
        Builder(
          builder: (ctx) => AppButton(
            label: 'Add Offline',
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              ref.read(authProvider.notifier).addOfflineAccount(name);
              Navigator.of(ctx, rootNavigator: true).pop();
            },
          ),
        ),
      ],
    );
  }
}

class _SignInProgress extends StatelessWidget {
  const _SignInProgress();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.px16, AppSpacing.px16, AppSpacing.px16, 0),
      padding: const EdgeInsets.all(AppSpacing.px16),
      decoration: BoxDecoration(
        color: colors.primaryMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.px12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for Microsoft login…',
                  style:
                      AppTypography.titleSmall.copyWith(color: colors.textHigh),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete sign-in in your browser, then return here.',
                  style:
                      AppTypography.bodySmall.copyWith(color: colors.textMed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.px16, AppSpacing.px16, AppSpacing.px16, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.px16, vertical: AppSpacing.px12),
      decoration: BoxDecoration(
        color: colors.dangerMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: colors.danger, size: AppSpacing.iconMd),
          const SizedBox(width: AppSpacing.px12),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall.copyWith(color: colors.textMed)),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textLow),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends ConsumerStatefulWidget {
  const _AccountTile({required this.account});
  final UserAccount account;

  @override
  ConsumerState<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends ConsumerState<_AccountTile> {
  bool _confirmRemove = false;

  Future<void> _refreshToken() async {
    final a = widget.account;
    try {
      await ref.read(authProvider.notifier).refreshAccount(a.uuid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Token refreshed successfully'),
            backgroundColor: context.colors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: ${e.toString()}'),
            backgroundColor: context.colors.danger,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = widget.account;
    final isMsa = a.type == 'microsoft';
    final authState = ref.watch(authProvider);
    final isRefreshing = authState.status == AuthStatus.refreshing &&
        authState.refreshingUuid == a.uuid;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [

              _Avatar(account: a),
              const SizedBox(width: AppSpacing.px12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.username,
                            style: AppTypography.titleSmall
                                .copyWith(color: colors.textHigh),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (a.isActive) ...[
                          const SizedBox(width: AppSpacing.px8),
                          _Pill(label: 'Active', color: colors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isMsa) ...[
                          _Pill(
                            label: a.isExpired ? 'Expired' : 'Valid',
                            color: a.isExpired ? colors.danger : colors.success,
                            small: true,
                          ),
                          const SizedBox(width: AppSpacing.px8),
                        ],
                        _Pill(
                          label: isMsa ? 'Microsoft' : 'Offline',
                          color: isMsa ? colors.primary : colors.textLow,
                          small: true,
                        ),
                        const SizedBox(width: AppSpacing.px8),
                        Flexible(
                          child: Text(
                            a.uuid,
                            style: AppTypography.labelSmall
                                .copyWith(color: colors.textDisabled),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isMsa && a.isExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '⚠ Token expired — will refresh on next launch',
                          style: AppTypography.labelSmall
                              .copyWith(color: colors.warn),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.px8),

              if (!a.isActive)
                AppButton(
                  label: 'Set Active',
                  onPressed: () =>
                      ref.read(authProvider.notifier).setActive(a.uuid),
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                ),
              const SizedBox(width: AppSpacing.px8),
              if (_confirmRemove)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Remove?',
                        style: AppTypography.labelSmall
                            .copyWith(color: colors.danger)),
                    const SizedBox(width: AppSpacing.px8),
                    AppButton(
                      label: 'Yes',
                      onPressed: () =>
                          ref.read(authProvider.notifier).removeAccount(a.uuid),
                      variant: AppButtonVariant.danger,
                      size: AppButtonSize.small,
                    ),
                    const SizedBox(width: AppSpacing.px4),
                    AppButton(
                      label: 'No',
                      onPressed: () => setState(() => _confirmRemove = false),
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.small,
                    ),
                  ],
                )
              else
                AppButton(
                  label: 'Remove',
                  onPressed: () => setState(() => _confirmRemove = true),
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.px12),
          Divider(color: colors.divider, height: 1),
          const SizedBox(height: AppSpacing.px12),
          Row(
            children: [
              if (isMsa) ...[
                AppButton(
                  label: 'Show Skin',
                  icon: Icons.person_rounded,
                  onPressed: () => PlayerViewerDialog.show(context, account: a),
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                ),
                const SizedBox(width: AppSpacing.px8),
                AppButton(
                  label: 'Change Appearance',
                  icon: Icons.checkroom_rounded,
                  onPressed: isRefreshing
                      ? null
                      : () => SkinDialog.show(
                            context,
                            account: a,
                          ),
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                ),
                const SizedBox(width: AppSpacing.px8),

                isRefreshing
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.px12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                      )
                    : AppButton(
                        label: 'Refresh Token',
                        icon: Icons.refresh_rounded,
                        onPressed: _refreshToken,
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.small,
                      ),
                const SizedBox(width: AppSpacing.px8),
                AppButton(
                  label: 'Security',
                  icon: Icons.security_rounded,
                  onPressed: () => launchUrl(
                    Uri.parse('https://account.microsoft.com/security'),
                  ),
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.small,
                ),
              ],
              const Spacer(),
              Tooltip(
                message: 'Copy UUID',
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  iconSize: 16,
                  color: colors.textDisabled,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 16,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: a.uuid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('UUID copied to clipboard'),
                        backgroundColor: colors.surfaceElevated,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.account});
  final UserAccount account;

  String get _avatarUrl {
    final cleanUuid = account.uuid.replaceAll('-', '');
    return 'https://mc-heads.net/avatar/$cleanUuid/44';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMsa = account.type == 'microsoft';
    final borderColor = isMsa ? colors.primary : colors.textMed;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
        child: isMsa ? _buildMsAvatar(colors) : _buildOfflineAvatar(colors),
      ),
    );
  }

  Widget _buildMsAvatar(dynamic colors) {
    if (account.skinUrl != null) {
      return Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: colors.surfaceElevated,
        ),
        child: Stack(
          children: [

            Positioned(
              left: -42,
              top: -42,
              child: Image.network(
                account.skinUrl!,
                width: 336, 
                height: 336,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none, 
              ),
            ),

            Positioned(
              left: -210, 
              top: -42,
              child: Image.network(
                account.skinUrl!,
                width: 336,
                height: 336,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ],
        ),
      );
    }

    return Image.network(
      _avatarUrl,
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: colors.primary.withValues(alpha: 0.12),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildOfflineAvatar(colors),
    );
  }

  Widget _buildOfflineAvatar(dynamic colors) {
    return Image.asset(
      'assets/images/steve.png',
      width: 44,
      height: 44,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Container(
        color: colors.textMed.withValues(alpha: 0.12),
        child: Center(
          child: Icon(
            Icons.person_outline_rounded,
            color: colors.textMed,
            size: AppSpacing.iconLg,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.small = false});
  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 7, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: (small ? AppTypography.labelSmall : AppTypography.labelLarge)
            .copyWith(color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 56, color: colors.textDisabled),
          const SizedBox(height: AppSpacing.px16),
          Text(
            'No accounts',
            style: AppTypography.headlineMedium.copyWith(color: colors.textMed),
          ),
          const SizedBox(height: AppSpacing.px8),
          Text(
            'Add a Microsoft account to get started. Offline profiles can be added once you have a valid Minecraft licence.',
            style: AppTypography.bodyMedium.copyWith(color: colors.textLow),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
