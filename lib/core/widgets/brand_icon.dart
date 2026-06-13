import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../providers/vanilla_icon_provider.dart';

enum BrandIconType {
  minecraft,
  java,
  fabric,
  forge,
  neoforge,
  quilt;

  static BrandIconType fromName(String name) {
    switch (name.toLowerCase()) {
      case 'fabric':
        return BrandIconType.fabric;
      case 'forge':
        return BrandIconType.forge;
      case 'neoforge':
        return BrandIconType.neoforge;
      case 'quilt':
        return BrandIconType.quilt;
      case 'java':
        return BrandIconType.java;
      default:
        return BrandIconType.minecraft;
    }
  }
}

class BrandIcon extends ConsumerWidget {
  const BrandIcon({
    super.key,
    required this.type,
    this.url,
    this.size = 24.0,
  });

  final BrandIconType type;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (url != null && url!.isNotEmpty && url != 'grass_block') {
      return _buildImage(url!, colors);
    }

    switch (type) {
      case BrandIconType.minecraft:
        return _buildVanillaIcon(ref, colors);
      case BrandIconType.java:
        return Icon(Icons.coffee_rounded, size: size, color: colors.textMed);
      case BrandIconType.fabric:
        return _buildAsset('fabric', colors);
      case BrandIconType.forge:
        return _buildAsset('forge', colors);
      case BrandIconType.neoforge:
        return _buildAsset('neoforge', colors);
      case BrandIconType.quilt:
        return _buildAsset('quilt', colors);
    }
  }

  Widget _buildAsset(String name, AppColors colors) {
    return Image.asset(
      'assets/images/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.extension,
        size: size * 0.8,
        color: colors.textLow,
      ),
    );
  }

  Widget _buildVanillaIcon(WidgetRef ref, AppColors colors) {
    final vanillaAsync = ref.watch(vanillaIconUrlProvider);
    return vanillaAsync.when(
      data: (url) => _buildImage(url, colors),
      loading: () => _buildAsset('minecraft', colors),
      error: (_, __) => _buildAsset('minecraft', colors),
    );
  }

  Widget _buildImage(String url, AppColors colors) {
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: (context, url, error) => Icon(
        Icons.extension,
        size: size * 0.8,
        color: colors.textLow,
      ),
      placeholder: (context, url) => SizedBox(
        width: size,
        height: size,
      ),
    );
  }
}
