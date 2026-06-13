import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/providers/news_provider.dart';
import '../models/news_item.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final newsAsync = ref.watch(newsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.px24, vertical: AppSpacing.px8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/images/heading_logo.svg',
                height: 28,
              ),
              const SizedBox(width: AppSpacing.px12),
              Text('News', style: AppTypography.titleLarge.copyWith(color: colors.textHigh)),
              const Spacer(),
              if (newsAsync.isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),

        Expanded(
          child: newsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text('Failed to load news: \$err', style: TextStyle(color: colors.danger)),
            ),
            data: (news) {
              if (news.isEmpty) {
                return Center(
                  child: Text('No news available.', style: AppTypography.bodyMedium.copyWith(color: colors.textLow)),
                );
              }

              final featured = news.first;
              final gridNews = news.skip(1).toList();

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.px24),
                children: [

                  _FeaturedNewsCard(
                    title: featured.title,
                    subtitle: featured.text,
                    imageUrl: featured.imageUrl,
                    date: featured.date,
                    url: featured.readMoreLink,
                  ),
                  const SizedBox(height: AppSpacing.px24),

                  Text('More News', style: AppTypography.titleMedium.copyWith(color: colors.textHigh)),
                  const SizedBox(height: AppSpacing.px16),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.px16,
                      mainAxisSpacing: AppSpacing.px16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: gridNews.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = gridNews[index];
                      return _NewsGridCard(
                        title: item.title,
                        category: item.category,
                        imageUrl: item.imageUrl,
                        url: item.readMoreLink,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  const _FeaturedNewsCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.date,
    required this.url,
  });

  final String title, subtitle, imageUrl, date, url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: colors.primary.withValues(alpha: 0.2),
                  child: const Icon(Icons.broken_image_rounded, size: 80, color: Colors.white24),
                ),
              )
            else
              Container(
                color: colors.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.newspaper_rounded, size: 80, color: Colors.white24),
              ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.px32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(date.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: AppSpacing.px12),
                  Text(title, style: AppTypography.headlineLarge.copyWith(color: Colors.white, fontSize: 32)),
                  const SizedBox(height: AppSpacing.px8),
                  Text(subtitle, style: AppTypography.titleMedium.copyWith(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.px20),
                  AppButton(
                    label: 'Read More',
                    onPressed: () {
                      if (url.isNotEmpty) launchUrlString(url);
                    },
                    variant: AppButtonVariant.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsGridCard extends StatelessWidget {
  const _NewsGridCard({
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.url,
  });

  final String title, category, imageUrl, url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: EdgeInsets.zero,
      isHoverable: true,
      onTap: () {
        if (url.isNotEmpty) launchUrlString(url);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colors.glassBorder,
                      child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white24),
                    ),
                  )
                : Container(
                    color: colors.glassBorder,
                    child: const Icon(Icons.article_rounded, size: 40, color: Colors.white24),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.px12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.px4),
                  Text(title, style: AppTypography.titleSmall.copyWith(color: colors.textHigh), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
