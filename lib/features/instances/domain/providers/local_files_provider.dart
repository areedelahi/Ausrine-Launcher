import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../data/instance_repository.dart';
import '../models/local_file_item.dart';
import 'local_mod_parser.dart';
import '../../../../core/utils/directory_size.dart';

typedef LocalFolderQuery = ({String instanceId, String folderName});

class LocalFilesNotifier extends FamilyAsyncNotifier<List<LocalFileItem>, LocalFolderQuery> {
  @override
  Future<List<LocalFileItem>> build(LocalFolderQuery arg) async {
    return _scanFolder();
  }

  Future<List<LocalFileItem>> _scanFolder() async {
    final repo = ref.read(instanceRepositoryProvider);
    final instancePath = await repo.getInstancePath(arg.instanceId);
    final folderPath = p.join(instancePath, arg.folderName);
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      return [];
    }

    final items = <LocalFileItem>[];
    await for (final entity in dir.list()) {
      final stat = await entity.stat();
      final name = p.basename(entity.path);

      if (name.startsWith('.')) continue;

      LocalModMetadata? metadata;
      int size = stat.size;

      if (entity is Directory) {
        size = await DirectorySize.calculate(entity);
        if (arg.folderName == 'saves') {
          metadata = await LocalModParser.parse(File(entity.path));
        }
      } else if (name.endsWith('.jar') || name.endsWith('.zip') || name.endsWith('.jar.disabled') || name.endsWith('.zip.disabled')) {
        metadata = await LocalModParser.parse(File(entity.path));
      }

      items.add(LocalFileItem(
        path: entity.path,
        name: name,
        sizeBytes: size,
        isEnabled: !name.endsWith('.disabled'),
        isDirectory: entity is Directory,
        lastModified: stat.modified,
        metadata: metadata,
      ));
    }

    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      if (a.isEnabled != b.isEnabled) {
        return a.isEnabled ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  Future<void> toggleFile(LocalFileItem item) async {
    final file = File(item.path);
    if (!await file.exists()) return;

    final dir = p.dirname(item.path);
    String newName;

    if (item.isEnabled) {
      newName = '${item.name}.disabled';
    } else {
      newName = item.name.replaceAll('.disabled', '');
    }

    final newPath = p.join(dir, newName);
    await file.rename(newPath);
    ref.invalidateSelf();
  }

  Future<void> deleteFile(LocalFileItem item) async {
    if (item.isDirectory) {
      final dir = Directory(item.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } else {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final localFilesProvider = AsyncNotifierProviderFamily<LocalFilesNotifier, List<LocalFileItem>, LocalFolderQuery>(
  () => LocalFilesNotifier(),
);
