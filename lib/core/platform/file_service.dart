import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

abstract class FileService {

  Future<Directory> get launcherDir;

  Future<Directory> get instancesDir;

  Future<Directory> get assetsDir;

  Future<Directory> get librariesDir;

  Future<Directory> get jreDir;

  Future<Directory> nativesDir(String instanceId);

  Future<Directory> crashReportsDir(String instanceId);

  Future<Directory> instanceGameDir(String instanceId);

  Future<Directory> ensure(Directory dir);
}

class DesktopFileService implements FileService {
  Directory? _launcherDirCache;

  // Cache launcher directory to avoid repeated preference lookups
  @override
  Future<Directory> get launcherDir async {
    if (_launcherDirCache != null) return _launcherDirCache!;

    // Allow user to override default data directory via settings
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString('customDataDirectory');
    if (customDir != null && customDir.isNotEmpty) {
      _launcherDirCache = await ensure(Directory(customDir));
      return _launcherDirCache!;
    }

    final appSupport = await getAusrineSupportDirectory();
    _launcherDirCache = await ensure(appSupport);
    return _launcherDirCache!;
  }

  @override
  Future<Directory> get instancesDir async {
    final root = await launcherDir;
    return ensure(Directory(p.join(root.path, 'instances')));
  }

  @override
  Future<Directory> get assetsDir async {
    final root = await launcherDir;
    return ensure(Directory(p.join(root.path, 'assets')));
  }

  @override
  Future<Directory> get librariesDir async {
    final root = await launcherDir;
    return ensure(Directory(p.join(root.path, 'libraries')));
  }

  @override
  Future<Directory> get jreDir async {
    final root = await launcherDir;
    return ensure(Directory(p.join(root.path, 'jre')));
  }

  @override
  Future<Directory> nativesDir(String instanceId) async {
    final temp = await getTemporaryDirectory();
    return ensure(Directory(p.join(temp.path, 'ausrine_natives', instanceId)));
  }

  @override
  Future<Directory> crashReportsDir(String instanceId) async {
    final gameDir = await instanceGameDir(instanceId);
    return ensure(Directory(p.join(gameDir.path, 'crash-reports')));
  }

  @override
  Future<Directory> instanceGameDir(String instanceId) async {
    final instances = await instancesDir;
    return ensure(Directory(p.join(instances.path, instanceId, '.minecraft')));
  }

  @override
  Future<Directory> ensure(Directory dir) async {
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String get nativesClassifier {
    if (Platform.isWindows) return 'natives-windows';
    if (Platform.isMacOS) return 'natives-osx';
    return 'natives-linux';
  }

  static String get mojangOs {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'osx';
    return 'linux';
  }

  static String get arch {
    final machine = Platform.version;
    if (machine.contains('arm64') || machine.contains('aarch64'))
      return 'aarch64';
    return 'x64';
  }
}

Future<Directory> getAusrineSupportDirectory() async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final dir = Directory(p.join(home, 'Library', 'Application Support', 'Ausrine Launcher'));
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir;
    }
  } else if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      final dir = Directory(p.join(appData, 'Ausrine Launcher'));
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir;
    }
  } else if (Platform.isLinux) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final dir = Directory(p.join(home, '.config', 'Ausrine Launcher'));
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir;
    }
  }

  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'Ausrine Launcher'));
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}
