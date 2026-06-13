import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../instances/data/instance_repository.dart';
import '../../../instances/domain/models/instance.dart';
import '../../../instances/domain/providers/local_files_provider.dart';
import '../models/remote_mod.dart';
import 'curseforge_api_provider.dart';
import 'modrinth_api_provider.dart';

typedef RemoteSearchQuery = ({
  String source, 
  String query,
  String folderName,
  Instance? instance,
  bool showAllVersions,
});

class RemoteModsNotifier extends FamilyAsyncNotifier<List<RemoteMod>, RemoteSearchQuery> {
  late final ModrinthApiProvider _modrinth = ModrinthApiProvider();
  late final CurseForgeApiProvider _curseforge = CurseForgeApiProvider();

  @override
  Future<List<RemoteMod>> build(RemoteSearchQuery arg) async {
    if (arg.query.isEmpty) return [];

    final loader = arg.instance?.loader.displayName;
    final gameVersion = arg.instance?.minecraftVersion;

    if (arg.source == 'modrinth') {
      return _modrinth.search(
        query: arg.query,
        folderName: arg.folderName,
        gameVersion: gameVersion,
        loader: loader,
        showAllVersions: arg.showAllVersions,
      );
    } else {
      return _curseforge.search(
        query: arg.query,
        folderName: arg.folderName,
        gameVersion: gameVersion,
        loader: loader,
        showAllVersions: arg.showAllVersions,
      );
    }
  }

  Future<String> _getSaveDirectory() async {
    if (arg.instance == null) throw Exception('Cannot install to a null instance');
    final repo = ref.read(instanceRepositoryProvider);
    final instancePath = await repo.getInstancePath(arg.instance!.id);
    final targetDir = Directory(p.join(instancePath, arg.folderName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }

  Future<List<RemoteModVersion>> getVersions(RemoteMod mod) async {
    if (arg.source == 'modrinth') {
      return _modrinth.getVersions(
        mod.id,
        gameVersion: arg.instance?.minecraftVersion,
        loader: arg.instance?.loader.displayName,
        showAllVersions: arg.showAllVersions,
      );
    } else {
      return _curseforge.getVersions(
        mod.id,
        gameVersion: arg.instance?.minecraftVersion,
        loader: arg.instance?.loader.displayName,
        showAllVersions: arg.showAllVersions,
      );
    }
  }

  Future<void> installSpecificVersion(RemoteMod mod, RemoteModVersion version) async {
    final saveDir = await _getSaveDirectory();
    final fileUrl = version.downloadUrl;
    if (fileUrl.isEmpty) throw Exception('No download URL available for this version');

    final fileName = version.filename;
    final savePath = p.join(saveDir, fileName);

    if (arg.instance == null) throw Exception('Cannot install to a null instance');
    await Dio().download(fileUrl, savePath);
    ref.invalidate(localFilesProvider((instanceId: arg.instance!.id, folderName: arg.folderName)));
  }

  Future<void> installMod(RemoteMod mod) async {
    final loader = arg.instance?.loader.displayName;
    final gameVersion = arg.instance?.minecraftVersion;

    List<RemoteModVersion> versions;
    if (arg.source == 'modrinth') {
      versions = await _modrinth.getVersions(
        mod.id,
        gameVersion: gameVersion,
        loader: loader,
        showAllVersions: arg.showAllVersions,
      );
    } else {
      versions = await _curseforge.getVersions(
        mod.id,
        gameVersion: gameVersion,
        loader: loader,
        showAllVersions: arg.showAllVersions,
      );
    }

    if (versions.isEmpty) {
      throw Exception('No compatible versions found for this mod.');
    }

    final latest = versions.first;

    if (latest.downloadUrl.isEmpty) {
      throw Exception('Download URL is empty (Author disabled 3rd party downloads).');
    }

    if (arg.instance == null) throw Exception('Cannot install to a null instance');
    final repo = ref.read(instanceRepositoryProvider);
    final instancePath = await repo.getInstancePath(arg.instance!.id);
    final targetDir = Directory(p.join(instancePath, arg.folderName));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, latest.filename));

    final dio = Dio();
    await dio.download(latest.downloadUrl, targetFile.path);

    ref.read(localFilesProvider((instanceId: arg.instance!.id, folderName: arg.folderName)).notifier).refresh();
  }
}

final remoteModsProvider = AsyncNotifierProviderFamily<RemoteModsNotifier, List<RemoteMod>, RemoteSearchQuery>(
  () => RemoteModsNotifier(),
);
