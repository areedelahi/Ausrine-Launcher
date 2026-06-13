import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

final vanillaIconUrlProvider = FutureProvider<String>((ref) async {
  final dio = Dio();

  try {

    final manifestResp = await dio.get('https://launchermeta.mojang.com/mc/game/version_manifest_v2.json');
    final versions = manifestResp.data['versions'] as List;

    final latestReleaseId = manifestResp.data['latest']['release'] as String;
    final latestRelease = versions.firstWhere((v) => v['id'] == latestReleaseId);

    final versionResp = await dio.get(latestRelease['url'] as String);
    final assetIndexUrl = versionResp.data['assetIndex']['url'] as String;

    final assetsResp = await dio.get(assetIndexUrl);
    final objects = assetsResp.data['objects'] as Map<String, dynamic>;

    final iconObject = objects['icons/icon_128x128.png'] ?? objects['icons/icon_256x256.png'] ?? objects['minecraft/icons/minecraft.icns'];
    if (iconObject == null) {
      throw Exception('Could not find icon in asset index');
    }

    final hash = iconObject['hash'] as String;
    final prefix = hash.substring(0, 2);

    return 'https://resources.download.minecraft.net/$prefix/$hash';
  } catch (e) {

    return 'https://upload.wikimedia.org/wikipedia/en/5/51/Minecraft_cover.png';
  }
});
