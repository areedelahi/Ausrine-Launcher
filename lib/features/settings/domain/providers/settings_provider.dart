import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/platform/file_service.dart';
import 'package:path/path.dart' as p;
import '../models/app_settings.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    // Load persisted preferences from SharedPreferences on init
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      minMemoryMb: prefs.getInt('minMemoryMb') ?? 512,
      maxMemoryMb: prefs.getInt('maxMemoryMb') ?? 4096,
      javaExecutable: prefs.getString('javaExecutable'),
      jvmArgs: prefs.getString('jvmArgs'),
      closeOnLaunch: prefs.getBool('closeOnLaunch') ?? false,
      customDataDirectory: prefs.getString('customDataDirectory'),
    );
  }

  void updateMemory(int min, int max) {
    state = state.copyWith(minMemoryMb: min, maxMemoryMb: max);
  }

  void updateJavaExecutable(String? path) {
    if (path == null) {
      state = state.copyWith(clearJavaExecutable: true);
    } else {
      state = state.copyWith(javaExecutable: path);
    }
  }

  void updateCloseOnLaunch(bool close) {
    state = state.copyWith(closeOnLaunch: close);
  }

  void updateJvmArgs(String? args) {
    if (args == null || args.trim().isEmpty) {
      state = state.copyWith(clearJvmArgs: true);
    } else {
      state = state.copyWith(jvmArgs: args);
    }
  }

  void updateCustomDataDirectory(String? path) {
    if (path == null || path.isEmpty) {
      state = state.copyWith(clearCustomDataDirectory: true);
    } else {
      state = state.copyWith(customDataDirectory: path);
    }
  }

  Future<bool> saveSettings(AppSettings newSettings) async {
    final prefs = await SharedPreferences.getInstance();
    final oldDir = prefs.getString('customDataDirectory');
    // Detect if data directory changed for migration handling
    bool directoryChanged = oldDir != newSettings.customDataDirectory;

    await prefs.setInt('minMemoryMb', newSettings.minMemoryMb);
    await prefs.setInt('maxMemoryMb', newSettings.maxMemoryMb);

    if (newSettings.javaExecutable != null && newSettings.javaExecutable!.isNotEmpty) {
      await prefs.setString('javaExecutable', newSettings.javaExecutable!);
    } else {
      await prefs.remove('javaExecutable');
    }

    if (newSettings.jvmArgs != null && newSettings.jvmArgs!.isNotEmpty) {
      await prefs.setString('jvmArgs', newSettings.jvmArgs!);
    } else {
      await prefs.remove('jvmArgs');
    }

    if (newSettings.customDataDirectory != null && newSettings.customDataDirectory!.isNotEmpty) {
      await prefs.setString('customDataDirectory', newSettings.customDataDirectory!);
    } else {
      await prefs.remove('customDataDirectory');
    }

    await prefs.setBool('closeOnLaunch', newSettings.closeOnLaunch);
    state = newSettings;
    try {
      final baseDir = await getAusrineSupportDirectory();
      final logDir = Directory(p.join(baseDir.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final logFile = File(p.join(logDir.path, 'save_log.txt'));
      await logFile.writeAsString('Global Save: min=${newSettings.minMemoryMb}, max=${newSettings.maxMemoryMb}, jvmArgs=${newSettings.jvmArgs}\n', mode: FileMode.append);
    } catch (_) {}

    return directoryChanged;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
