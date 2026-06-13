import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import '../../../core/platform/file_service.dart';
import '../domain/models/instance.dart';

final instanceRepositoryProvider = Provider<InstanceRepository>((ref) {
  return InstanceRepository();
});

class InstanceRepository {
  // Check custom directory first in case user moved launcher data
  Future<Directory> get _instancesDir async {
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString('customDataDirectory');
    Directory baseDir;
    if (customDir != null && customDir.isNotEmpty) {
      baseDir = Directory(customDir);
    } else {
      baseDir = await getAusrineSupportDirectory();
    }

    final dir = Directory(p.join(baseDir.path, 'instances'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> getInstancePath(String id) async {
    final dir = await _instancesDir;
    return p.join(dir.path, id);
  }

  Future<String> getLauncherRoot() async {
    final dir = await _instancesDir;
    return dir.parent.path;
  }

  Future<List<Instance>> getInstances() async {
    final dir = await _instancesDir;
    final List<Instance> instances = [];

    // Scan directory for instance.json metadata files
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final instanceFile = File(p.join(entity.path, 'instance.json'));
        if (await instanceFile.exists()) {
          try {
            final content = await instanceFile.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            instances.add(Instance.fromJson(json));
          } catch (e) {
            print('Failed to read instance at ${entity.path}: $e');
          }
        }
      }
    }
    return instances;
  }

  Future<void> saveInstance(Instance instance) async {
    final dir = await _instancesDir;
    final instanceDir = Directory(p.join(dir.path, instance.id));
    if (!await instanceDir.exists()) {
      await instanceDir.create(recursive: true);

      await Directory(p.join(instanceDir.path, 'mods')).create();
      await Directory(p.join(instanceDir.path, 'resourcepacks')).create();
      await Directory(p.join(instanceDir.path, 'shaderpacks')).create();
      await Directory(p.join(instanceDir.path, 'saves')).create();
      await Directory(p.join(instanceDir.path, 'screenshots')).create();
    }

    final instanceFile = File(p.join(instanceDir.path, 'instance.json'));

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(instance.toJson());
    await instanceFile.writeAsString(jsonString);
  }

  Future<void> deleteInstance(String id) async {
    final dir = await _instancesDir;
    final instanceDir = Directory(p.join(dir.path, id));
    if (await instanceDir.exists()) {
      await instanceDir.delete(recursive: true);
    }
  }
}
