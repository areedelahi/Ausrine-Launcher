import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../src/rust/api/launcher.dart';
import '../../../../src/rust/api/installer.dart';
import '../../../../src/rust/api/discord.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../settings/domain/providers/settings_provider.dart';
import '../../data/instance_repository.dart';
import '../models/instance.dart';
import 'running_instances_provider.dart';

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

    final initialAcc = authState.activeAccount!;
    if (initialAcc.type == 'microsoft') {
      await ref.read(authProvider.notifier).refreshIfNeeded(initialAcc.uuid);
    }
    
    final acc = ref.read(authProvider).activeAccount!;
    final isOffline = acc.type == 'offline';

    String? javaExe = instance.javaPath ?? settings.javaExecutable;

    if (javaExe == null || javaExe.trim().isEmpty) {
      final targetVersion = instance.minecraftVersion;
      final root = await repo.getLauncherRoot();
      javaExe = await getJavaExecutablePath(minecraftDir: root, versionId: targetVersion);

      if (javaExe == null) {
        throw Exception("Failed to resolve official Mojang Java path for version $targetVersion!");
      }
    }

    final userJvmArgs = instance.jvmArgs ?? settings.jvmArgs ?? '';

    // Avoid duplicating memory args if user already specified them
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

    // Prepend calculated RAM args before user args so user can override
    final finalJvmArgs = userJvmArgs.trim().isNotEmpty 
        ? (ramArgs.isNotEmpty ? '$ramArgs $userJvmArgs' : userJvmArgs)
        : ramArgs;

    try {
      print("Launching game...");
      final stream = launchInstance(
        minecraftDir: await repo.getLauncherRoot(),
        instanceDir: await repo.getInstancePath(instance.id),
        versionId: instance.profileId ?? instance.minecraftVersion,
        javaExecutable: javaExe,
        jvmArgs: finalJvmArgs,
        ramMb: null, 
        isOffline: isOffline,
        accountName: acc.username,
        accountUuid: acc.uuid,
        accountToken: acc.accessToken,
      );

      DateTime? startTime;

      // Track start time for play duration calculation
      final subscription = stream.listen((event) {
        event.when(
          started: (pid) {
            print("Received started event from Rust! PID: $pid");
            startTime = DateTime.now();
            ref.read(runningInstancesProvider.notifier).setRunning(instance.id, pid);

            final currentInstances = ref.read(instancesProvider).value ?? [];
            final currentInstance = currentInstances.firstWhere((e) => e.id == instance.id, orElse: () => instance);
            ref.read(instancesProvider.notifier).updateInstance(
              currentInstance.copyWith(lastPlayed: startTime)
            );

            try {
              final unixSeconds = startTime!.millisecondsSinceEpoch ~/ 1000;
              final state = instance.profileId != null ? 'Modded ${instance.profileId}' : 'Vanilla ${instance.minecraftVersion}';
              final details = 'Playing ${instance.name}';
              setDiscordPresence(state: state, details: details, startTimestamp: unixSeconds);
            } catch (e) {
              print('Failed to set discord presence: $e');
            }
          },
          exited: (code) {
            print("Received exited event from Rust! Code: $code");
            ref.read(runningInstancesProvider.notifier).setExited(instance.id);

            // Accumulate total playtime when instance closes
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
            try {
              clearDiscordPresence();
            } catch (e) {
              print('Failed to clear discord presence: $e');
            }
          },
        );
      }, onError: (error) {
        ref.read(runningInstancesProvider.notifier).setExited(instance.id);
        print("Error during active launch stream: $error");
      }, onDone: () {
        print("Launch stream closed by Rust.");
      });

      // Keep subscription alive in provider state to prevent GC
      _subscriptions[instance.id] = subscription;
    } catch (e) {
      ref.read(runningInstancesProvider.notifier).setExited(instance.id);
      print("Failed to start launch process: $e");
      rethrow; 
    }
  }
}

final launchServiceProvider = Provider<LaunchService>((ref) {
  return LaunchService(ref);
});

// Store active subscriptions to prevent GC
final Map<String, dynamic> _subscriptions = {};
