import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../instances/domain/models/instance.dart';
import '../../../instances/data/instance_repository.dart';
import '../../../instances/domain/providers/instance_provider.dart';
import '../../../remote_mods/domain/models/remote_mod.dart';

class ModpackInstallerService {
  final Ref ref;

  ModpackInstallerService(this.ref);

  Future<Instance> extractAndInstall({
    required RemoteMod mod,
    required RemoteModVersion version,
    required void Function(String subtitle, double progress) onProgress,
    CancelToken? cancelToken,
    Instance? updateInstance,
    bool overwriteConfig = false,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
    final url = version.downloadUrl;

    final tempDir = await Directory.systemTemp.createTemp('mrpack_');
    final zipFile = File(p.join(tempDir.path, 'modpack.mrpack'));

    onProgress('Downloading Modpack', 0.1);
    await dio.download(url, zipFile.path, onReceiveProgress: (count, total) {
      if (total > 0) {
        onProgress('Downloading Modpack', 0.1 + (count / total) * 0.2);
      }
    });

    onProgress('Extracting Archive', 0.3);
    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final extractDir = Directory(p.join(tempDir.path, 'extracted'));
    await extractDir.create();

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(extractDir.path, filename));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(p.join(extractDir.path, filename)).create(recursive: true);
      }
    }

    onProgress('Parsing Index', 0.4);
    final indexFile = File(p.join(extractDir.path, 'modrinth.index.json'));
    if (!await indexFile.exists()) {
      throw Exception('Not a valid Modrinth modpack (no modrinth.index.json)');
    }

    final indexJson = jsonDecode(await indexFile.readAsString());
    final deps = indexJson['dependencies'] as Map<String, dynamic>? ?? {};
    final mcVersion = deps['minecraft'] as String?;
    if (mcVersion == null) throw Exception('Minecraft version not specified in modpack');

    var loaderType = ModLoader.vanilla;
    String? loaderVersion;
    if (deps.containsKey('fabric-loader')) {
      loaderType = ModLoader.fabric;
      loaderVersion = deps['fabric-loader'];
    } else if (deps.containsKey('forge')) {
      loaderType = ModLoader.forge;
      loaderVersion = deps['forge'];
    } else if (deps.containsKey('quilt-loader')) {
      loaderType = ModLoader.quilt;
      loaderVersion = deps['quilt-loader'];
    }

    final String slug = mod.slug.replaceAll('-', '_');
    final instanceId = updateInstance?.id ?? (slug + '_' + DateTime.now().millisecondsSinceEpoch.toString());
    final newInstance = (updateInstance ?? Instance(
      id: instanceId,
      name: mod.title,
      minecraftVersion: mcVersion,
      loader: loaderType,
      loaderVersion: loaderVersion,
      icon: mod.iconUrl ?? 'grass_block',
      playTimeMs: 0,
    )).copyWith(
      minecraftVersion: mcVersion,
      loader: loaderType,
      loaderVersion: loaderVersion,
      sourceModpackId: mod.slug,
      sourceModpackVersionId: version.id,
    );

    final repo = ref.read(instanceRepositoryProvider);
    final instanceDir = Directory(await repo.getInstancePath(instanceId));
    if (!await instanceDir.exists()) await instanceDir.create(recursive: true);

    if (updateInstance != null) {
      final modsDir = Directory(p.join(instanceDir.path, 'mods'));
      if (await modsDir.exists()) {
        await modsDir.delete(recursive: true);
      }
    }

    final files = indexJson['files'] as List<dynamic>? ?? [];
    int downloaded = 0;

    onProgress('Downloading Mods (0/${files.length})', 0.4);

    const int concurrency = 5;
    for (var i = 0; i < files.length; i += concurrency) {
      if (cancelToken?.isCancelled == true) throw Exception('Installation was cancelled by user');

      final chunk = files.sublist(i, (i + concurrency > files.length) ? files.length : i + concurrency);

      await Future.wait(chunk.map((f) async {
        if (cancelToken?.isCancelled == true) return;

        final downloads = f['downloads'] as List<dynamic>? ?? [];
        final path = f['path'] as String?;
        if (downloads.isNotEmpty && path != null) {
          final targetPath = p.join(instanceDir.path, path);
          final targetFile = File(targetPath);
          await targetFile.create(recursive: true);

          final dlUrl = downloads.first as String;
          try {
            await dio.download(dlUrl, targetFile.path, cancelToken: cancelToken);
          } catch (e) {

          }
        }

        downloaded++;
        onProgress('Downloading Mods ($downloaded/${files.length})', 0.4 + (downloaded / files.length) * 0.5);
      }));
    }

    onProgress('Applying Overrides', 0.9);
    final skipConfigs = updateInstance != null && !overwriteConfig;

    final overridesDir = Directory(p.join(extractDir.path, 'overrides'));
    if (await overridesDir.exists()) {
      await _copyDirectory(overridesDir, instanceDir, skipConfigs: skipConfigs);
    }

    final clientOverridesDir = Directory(p.join(extractDir.path, 'client-overrides'));
    if (await clientOverridesDir.exists()) {
      await _copyDirectory(clientOverridesDir, instanceDir, skipConfigs: skipConfigs);
    }

    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    if (updateInstance != null) {
      await ref.read(instancesProvider.notifier).updateInstance(newInstance);
    } else {
      await ref.read(instancesProvider.notifier).addInstance(newInstance);
    }

    return newInstance;
  }

  Future<Instance> extractAndInstallLocal({
    required File mrpackFile,
    required void Function(String subtitle, double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));

    final tempDir = await Directory.systemTemp.createTemp('mrpack_local_');

    onProgress('Extracting Archive', 0.1);
    final archive = ZipDecoder().decodeBytes(await mrpackFile.readAsBytes());
    final extractDir = Directory(p.join(tempDir.path, 'extracted'));
    await extractDir.create();

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(extractDir.path, filename));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(p.join(extractDir.path, filename)).create(recursive: true);
      }
    }

    onProgress('Parsing Index', 0.2);
    final indexFile = File(p.join(extractDir.path, 'modrinth.index.json'));
    if (!await indexFile.exists()) {
      throw Exception('Not a valid Modrinth modpack (no modrinth.index.json)');
    }

    final indexJson = jsonDecode(await indexFile.readAsString());
    final deps = indexJson['dependencies'] as Map<String, dynamic>? ?? {};
    final mcVersion = deps['minecraft'] as String?;
    if (mcVersion == null) throw Exception('Minecraft version not specified in modpack');

    var loaderType = ModLoader.vanilla;
    String? loaderVersion;
    if (deps.containsKey('fabric-loader')) {
      loaderType = ModLoader.fabric;
      loaderVersion = deps['fabric-loader'];
    } else if (deps.containsKey('forge')) {
      loaderType = ModLoader.forge;
      loaderVersion = deps['forge'];
    } else if (deps.containsKey('quilt-loader')) {
      loaderType = ModLoader.quilt;
      loaderVersion = deps['quilt-loader'];
    }

    final String baseName = p.basenameWithoutExtension(mrpackFile.path);
    final String slug = baseName.replaceAll(' ', '_').replaceAll('-', '_');
    final instanceId = slug + '_' + DateTime.now().millisecondsSinceEpoch.toString();

    final String packName = indexJson['name'] as String? ?? baseName;

    final newInstance = Instance(
      id: instanceId,
      name: packName,
      minecraftVersion: mcVersion,
      loader: loaderType,
      loaderVersion: loaderVersion,
      icon: 'grass_block',
      playTimeMs: 0,
    );

    final repo = ref.read(instanceRepositoryProvider);
    final instanceDir = Directory(await repo.getInstancePath(instanceId));
    if (!await instanceDir.exists()) await instanceDir.create(recursive: true);

    final files = indexJson['files'] as List<dynamic>? ?? [];
    int downloaded = 0;

    onProgress('Downloading Mods (0/${files.length})', 0.2);

    const int concurrency = 5;
    for (var i = 0; i < files.length; i += concurrency) {
      if (cancelToken?.isCancelled == true) throw Exception('Installation was cancelled by user');

      final chunk = files.sublist(i, (i + concurrency > files.length) ? files.length : i + concurrency);

      await Future.wait(chunk.map((f) async {
        if (cancelToken?.isCancelled == true) return;

        final downloads = f['downloads'] as List<dynamic>? ?? [];
        final path = f['path'] as String?;
        if (downloads.isNotEmpty && path != null) {
          final targetPath = p.join(instanceDir.path, path);
          final targetFile = File(targetPath);
          await targetFile.create(recursive: true);

          final dlUrl = downloads.first as String;
          try {
            await dio.download(dlUrl, targetFile.path, cancelToken: cancelToken);
          } catch (e) {

          }
        }

        downloaded++;
        onProgress('Downloading Mods ($downloaded/${files.length})', 0.2 + (downloaded / files.length) * 0.7);
      }));
    }

    onProgress('Applying Overrides', 0.95);
    final overridesDir = Directory(p.join(extractDir.path, 'overrides'));
    if (await overridesDir.exists()) {
      await _copyDirectory(overridesDir, instanceDir);
    }

    final clientOverridesDir = Directory(p.join(extractDir.path, 'client-overrides'));
    if (await clientOverridesDir.exists()) {
      await _copyDirectory(clientOverridesDir, instanceDir);
    }

    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}

    await ref.read(instancesProvider.notifier).addInstance(newInstance);

    return newInstance;
  }

  Future<void> _copyDirectory(Directory source, Directory destination, {bool skipConfigs = false}) async {
    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: source.path);

        if (skipConfigs) {
          if (relative.startsWith('config/') || relative.startsWith('config\\') || relative == 'options.txt') {
            continue;
          }
        }

        final destFile = File(p.join(destination.path, relative));
        await destFile.create(recursive: true);
        await entity.copy(destFile.path);
      }
    }
  }
}

final modpackInstallerServiceProvider = Provider((ref) => ModpackInstallerService(ref));
