import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../src/rust/api/launcher.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../settings/domain/providers/settings_provider.dart';
import '../../data/instance_repository.dart';
import '../models/instance.dart';
import 'running_instances_provider.dart';

import 'java_runtime_provider.dart';
import 'instance_provider.dart';

class LaunchService {
  LaunchService(this.ref);
  final Ref ref;

  Future<void> launch(Instance instance) async {
    final repo = ref.read(instanceRepositoryProvider);
    final authState = ref.read(authProvider);
    final settings = ref.read(settingsProvider);

    if (authState.activeAccount == null) {
      throw Exception('Please select an account in Settings first.');
    }

    final acc = authState.activeAccount!;
    final isOffline = acc.type == 'offline';

    // Instance overrides, fallback to global settings
    String? javaExe = instance.javaPath ?? settings.javaExecutable;
    
    // Auto-download Java if the user hasn't explicitly set a custom path!
    if (javaExe == null || javaExe.trim().isEmpty) {
      final javaService = ref.read(javaRuntimeProvider);
      final targetVersion = instance.profileId ?? instance.minecraftVersion;
      javaExe = await javaService.getOrDownloadJavaExecutable(targetVersion);
    }
    
    final userJvmArgs = instance.jvmArgs ?? settings.jvmArgs ?? '';
    
    String ramArgs = '';
    if (!userJvmArgs.contains('-Xms')) {
      final minRam = instance.minAllocatedRamMb ?? settings.minMemoryMb;
      ramArgs += '-Xms${minRam}M ';
    }
    if (!userJvmArgs.contains('-Xmx')) {
      final maxRam = instance.allocatedRamMb ?? settings.maxMemoryMb;
      ramArgs += '-Xmx${maxRam}M';
    }
    ramArgs = ramArgs.trim();

    final finalJvmArgs = userJvmArgs.trim().isNotEmpty 
        ? (ramArgs.isNotEmpty ? '$ramArgs $userJvmArgs' : userJvmArgs)
        : ramArgs;

    final stream = launchInstance(
      minecraftDir: await repo.getLauncherRoot(),
      instanceDir: await repo.getInstancePath(instance.id),
      versionId: instance.profileId ?? instance.minecraftVersion,
      javaExecutable: javaExe,
      jvmArgs: finalJvmArgs,
      ramMb: null, // We handle RAM manually via jvmArgs to support min/max correctly
      isOffline: isOffline,
      accountName: acc.username,
      accountUuid: acc.uuid,
      accountToken: acc.accessToken,
    );

    DateTime? startTime;

    stream.listen((event) {
      event.when(
        started: (pid) {
          startTime = DateTime.now();
          ref.read(runningInstancesProvider.notifier).setRunning(instance.id, pid);
          
          final currentInstances = ref.read(instancesProvider).value ?? [];
          final currentInstance = currentInstances.firstWhere((e) => e.id == instance.id, orElse: () => instance);
          ref.read(instancesProvider.notifier).updateInstance(
            currentInstance.copyWith(lastPlayed: startTime)
          );
        },
        exited: (code) {
          ref.read(runningInstancesProvider.notifier).setExited(instance.id);
          
          if (startTime != null) {
            final duration = DateTime.now().difference(startTime!);
            final currentInstances = ref.read(instancesProvider).value ?? [];
            final currentInstance = currentInstances.firstWhere((e) => e.id == instance.id, orElse: () => instance);
            ref.read(instancesProvider.notifier).updateInstance(
              currentInstance.copyWith(
                playTimeMs: currentInstance.playTimeMs + duration.inMilliseconds,
              )
            );
          }
        },
      );
    }, onError: (error) {
      // If there's an error launching (like missing Java, bad version), handle it
      ref.read(runningInstancesProvider.notifier).setExited(instance.id);
      print("Error launching instance: $error");
    });
  }
}

final launchServiceProvider = Provider<LaunchService>((ref) {
  return LaunchService(ref);
});
