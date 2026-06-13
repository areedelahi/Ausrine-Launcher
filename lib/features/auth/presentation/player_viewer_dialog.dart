import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../domain/user_account.dart';

class PlayerViewerDialog extends StatelessWidget {
  const PlayerViewerDialog({
    super.key,
    required this.account,
  });

  final UserAccount account;

  static Future<void> show(BuildContext context,
      {required UserAccount account}) {
    return showDialog(
      context: context,
      builder: (context) => PlayerViewerDialog(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    String imageUrl;
    if (account.skinUrl != null) {
      final uri = Uri.parse(account.skinUrl!);
      final textureId = uri.pathSegments.last;
      imageUrl = 'https://mc-heads.net/body/$textureId/256';
    } else {
      final cleanUuid = account.uuid.replaceAll('-', '');
      imageUrl = 'https://mc-heads.net/body/$cleanUuid/256';
    }

    return GlassDialog(
      width: 350,
      title: '${account.username}\'s Character',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 350,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: colors.divider),
            ),
            child: account.type == 'offline'
                ? Image.asset(
                    'assets/images/steve.png',
                    width: 256,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  )
                : Image.network(
                    imageUrl,
                    height: 300,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(color: colors.primary),
                      );
                    },
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.error_outline,
                          color: colors.danger, size: 48),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.px20),
        ],
      ),
    );
  }
}
