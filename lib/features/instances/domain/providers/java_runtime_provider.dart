import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../data/instance_repository.dart';

final javaRuntimeProvider = Provider<JavaRuntimeService>((ref) {
  return JavaRuntimeService(ref);
});

class JavaRuntimeService {
  final Ref ref;

  JavaRuntimeService(this.ref);

  /// Analyzes the Minecraft version string and downloads/caches the required JRE.
  /// Returns the absolute path to the java executable.
  Future<String> getOrDownloadJavaExecutable(String minecraftVersion) async {
    final majorJavaVersion = _determineJavaVersion(minecraftVersion);
    final repo = ref.read(instanceRepositoryProvider);
    final launcherRoot = await repo.getLauncherRoot();

    final os = Platform.isWindows ? 'windows' : (Platform.isMacOS ? 'mac' : 'linux');
    // For simplicity, we assume x64, though aarch64 could be checked via SysInfo or just attempting aarch64 first on mac
    // Platform.version or other libs can check arch, but x64 runs via Rosetta on Mac M1 anyway.
    // For true native:
    final isArm = Platform.version.contains('arm64') || Platform.version.contains('aarch64');
    final arch = isArm ? 'aarch64' : 'x64';

    final runtimeDir = Directory(p.join(launcherRoot, 'runtime', 'java-$majorJavaVersion', '$os-$arch'));
    
    if (await _isJavaInstalled(runtimeDir)) {
      return await _findJavaExecutable(runtimeDir);
    }

    // Java not found, let's download it
    await runtimeDir.create(recursive: true);

    // Endpoint for Adoptium JRE
    final apiUrl = 'https://api.adoptium.net/v3/binary/latest/$majorJavaVersion/ga/$os/$arch/jre/hotspot/normal/eclipse?project=jdk';
    
    final archiveExt = Platform.isWindows ? '.zip' : '.tar.gz';
    final archiveFile = File(p.join(runtimeDir.parent.path, 'download$archiveExt'));

    try {
      final dio = Dio();
      // 1. Download
      await dio.download(
        apiUrl,
        archiveFile.path,
        options: Options(followRedirects: true),
      );

      // 2. Extract natively
      final result = await Process.run('tar', ['-xf', archiveFile.path, '-C', runtimeDir.path]);
      if (result.exitCode != 0) {
        throw Exception('Failed to extract Java: ${result.stderr}');
      }

      // 3. Cleanup archive
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }

      // 4. Find the extracted executable
      return await _findJavaExecutable(runtimeDir);

    } catch (e) {
      // Clean up the broken directory if it failed
      if (await runtimeDir.exists()) {
        await runtimeDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  int _determineJavaVersion(String mcVersion) {
    // Expected formats: "1.20.1", "1.16.5", "1.8.9", "26.1.2"
    final parts = mcVersion.split('.');
    if (parts.isEmpty) return 17; // fallback

    final major = int.tryParse(parts[0]) ?? 1;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    // Handle future 26.x.y requirement requested by user
    if (major >= 26) {
      return 25;
    }

    // Modern mapping
    if (major == 1) {
      if (minor >= 20 && patch >= 5) return 21;
      if (minor >= 21) return 21;
      if (minor >= 17) return 17;
      if (minor <= 16) return 8;
    }

    // Default safe fallback for unknowns
    return 17;
  }

  Future<bool> _isJavaInstalled(Directory runtimeDir) async {
    if (!await runtimeDir.exists()) return false;
    try {
      await _findJavaExecutable(runtimeDir);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _findJavaExecutable(Directory dir) async {
    final javaName = Platform.isWindows ? 'java.exe' : 'java';
    
    // Perform a recursive search because the zip extracts to a subfolder like `jdk-17.0.8+7-jre/bin/java.exe`
    final entities = dir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File && p.basename(entity.path) == javaName) {
        // On macOS/Linux, ensure it has execute permissions
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', entity.path]);
        }
        return entity.path;
      }
    }
    throw Exception('Could not find $javaName inside ${dir.path}');
  }
}
