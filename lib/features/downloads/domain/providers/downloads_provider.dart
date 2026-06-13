import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../src/rust/api/installer.dart';
import '../../../instances/data/instance_repository.dart';
import '../../../instances/domain/models/instance.dart';
import '../../../instances/domain/providers/instance_provider.dart';
import '../../../remote_mods/domain/models/remote_mod.dart';
import '../../../mods/domain/services/modpack_installer_service.dart';

class DownloadTaskInfo {
  DownloadTaskInfo({
    required this.instanceId,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String instanceId;
  final String title;
  final String subtitle;
  final double progress;

  DownloadTaskInfo copyWith({
    String? title,
    String? subtitle,
    double? progress,
  }) {
    return DownloadTaskInfo(
      instanceId: instanceId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? this.progress,
    );
  }
}

class DownloadsNotifier extends StateNotifier<List<DownloadTaskInfo>> {
  DownloadsNotifier(this.ref) : super([]);
  final Ref ref;

  // Store cancel callbacks for each download to allow mid-flight cancellation
  final Map<String, VoidCallback> _cancelHooks = {};

  void removeTask(String id) {
    // Execute cancel hook if task supports cancellation
    _cancelHooks[id]?.call();
    _cancelHooks.remove(id);
    state = state.where((t) => t.instanceId != id).toList();
  }

  void registerCancelHook(String id, VoidCallback onCancel) {
    _cancelHooks[id] = onCancel;
  }

  Future<String?> startDownload(Instance instance) async {
    final repo = ref.read(instanceRepositoryProvider);
    final root = await repo.getLauncherRoot();

    final dartLoader = _mapLoader(instance);

    final taskId = instance.id;

    if (!state.any((t) => t.instanceId == taskId)) {
      state = [
        ...state,
        DownloadTaskInfo(
          instanceId: taskId,
          title: 'Installing ${instance.name}',
          subtitle: 'Preparing...',
          progress: 0.0,
        )
      ];
    }

    try {
      final stream = installInstance(
        minecraftDir: root,
        version: instance.minecraftVersion,
        loader: dartLoader,
      );

      final completer = Completer<String?>();

      final sub = stream.listen((event) {
        event.when(
          stageStarted: (stage) {
            updateTask(taskId, subtitle: 'Stage: $stage', progress: 0.1);
          },
          taskStarted: (label, path) {
            updateTask(taskId, subtitle: label);
          },
          taskSkipped: (label, reason) {
            updateTask(taskId, subtitle: 'Skipped $label');
          },
          taskFinished: (label) {
            updateTask(taskId, subtitle: 'Finished $label');
          },
          bytesReceived: (label, received, total) {
            updateTask(taskId, subtitle: 'Downloading $label');
          },
          planProgress: (completedBytes, totalBytes) {
            if (totalBytes > BigInt.zero) {
              final pct = (completedBytes.toDouble() / totalBytes.toDouble()).clamp(0.1, 0.99);
              updateTask(taskId, progress: pct);
            }
          },
          installComplete: (versionId) {

            final notifier = ref.read(instancesProvider.notifier);
            final currentList = ref.read(instancesProvider).value ?? [];
            final currentInstance = currentList.firstWhere((i) => i.id == instance.id, orElse: () => instance);
            notifier.updateInstance(currentInstance.copyWith(profileId: versionId));

            updateTask(taskId, subtitle: 'Complete!', progress: 1.0);
            if (!completer.isCompleted) completer.complete(versionId);
          },
        );
      }, onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }, onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      });

      registerCancelHook(taskId, () {
        sub.cancel();
        if (!completer.isCompleted) completer.completeError('Installation was cancelled by user');
      });

      return await completer.future;
    } catch (e) {
      updateTask(taskId, subtitle: 'Error: $e', progress: 0.0);
      throw Exception('Installation failed: $e');
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          state = state.where((t) => t.instanceId != taskId).toList();
        }
      });
    }
  }

  Future<void> installModpack(RemoteMod mod, RemoteModVersion version, {Instance? updateInstance, bool overwriteConfig = false}) async {
    final installer = ref.read(modpackInstallerServiceProvider);

    final taskId = updateInstance?.id ?? ('modpack_' + DateTime.now().millisecondsSinceEpoch.toString());

    state = [
      ...state,
      DownloadTaskInfo(
        instanceId: taskId,
        title: updateInstance != null ? 'Updating ' + mod.title : 'Installing ' + mod.title,
        subtitle: 'Starting download...',
        progress: 0.0,
      )
    ];

    try {
      final cancelToken = CancelToken();
      registerCancelHook(taskId, () {
        cancelToken.cancel();
      });

      final newInstance = await installer.extractAndInstall(
        mod: mod,
        version: version,
        onProgress: (subtitle, progress) {
          updateTask(taskId, subtitle: subtitle, progress: progress);
        },
        cancelToken: cancelToken,
        updateInstance: updateInstance,
        overwriteConfig: overwriteConfig,
      );

      state = state.map((t) {
        if (t.instanceId == taskId) {
          return DownloadTaskInfo(
            instanceId: newInstance.id,
            title: 'Finalizing ' + newInstance.name,
            subtitle: 'Bootstrapping Vanilla/Loader...',
            progress: 1.0, 
          );
        }
        return t;
      }).toList();

      await startDownload(newInstance);

    } catch (e) {
      updateTask(taskId, subtitle: 'Error: ' + e.toString(), progress: 0.0);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) removeTask(taskId);
      });
    }
  }

  Future<void> installLocalModpack(File mrpackFile) async {
    final installer = ref.read(modpackInstallerServiceProvider);

    final taskId = 'modpack_local_' + DateTime.now().millisecondsSinceEpoch.toString();

    state = [
      ...state,
      DownloadTaskInfo(
        instanceId: taskId,
        title: 'Installing Local Modpack',
        subtitle: 'Starting extraction...',
        progress: 0.0,
      )
    ];

    try {
      final cancelToken = CancelToken();
      registerCancelHook(taskId, () {
        cancelToken.cancel();
      });

      final newInstance = await installer.extractAndInstallLocal(
        mrpackFile: mrpackFile,
        onProgress: (subtitle, progress) {
          updateTask(taskId, subtitle: subtitle, progress: progress);
        },
        cancelToken: cancelToken,
      );

      state = state.map((t) {
        if (t.instanceId == taskId) {
          return DownloadTaskInfo(
            instanceId: newInstance.id,
            title: 'Finalizing ' + newInstance.name,
            subtitle: 'Bootstrapping Vanilla/Loader...',
            progress: 1.0,
          );
        }
        return t;
      }).toList();

      await startDownload(newInstance);

    } catch (e) {
      updateTask(taskId, subtitle: 'Error: ' + e.toString(), progress: 0.0);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) removeTask(taskId);
      });
    }
  }

  void updateTask(String id, {String? title, String? subtitle, double? progress}) {
    state = state.map((task) {
      if (task.instanceId == id) {
        return task.copyWith(title: title, subtitle: subtitle, progress: progress);
      }
      return task;
    }).toList();
  }

  void addTask(DownloadTaskInfo task) {
    if (!state.any((t) => t.instanceId == task.instanceId)) {
      state = [...state, task];
    }
  }

  DartLoaderSpec _mapLoader(Instance instance) {
    final version = instance.loaderVersion ?? 'latest';
    switch (instance.loader) {
      case ModLoader.vanilla:
        return const DartLoaderSpec.vanilla();
      case ModLoader.fabric:
        return DartLoaderSpec.fabric(version: version);
      case ModLoader.forge:
        return DartLoaderSpec.forge(version: version);
      case ModLoader.quilt:
        return DartLoaderSpec.quilt(version: version);
      case ModLoader.neoforge:
        return DartLoaderSpec.neoForge(version: version);
    }
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, List<DownloadTaskInfo>>((ref) {
  return DownloadsNotifier(ref);
});
