import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/instance_repository.dart';
import '../models/instance.dart';

final instancesProvider =
    StateNotifierProvider<InstancesNotifier, AsyncValue<List<Instance>>>((ref) {
  final repository = ref.watch(instanceRepositoryProvider);
  return InstancesNotifier(repository);
});

final selectedInstanceIdProvider = StateProvider<String?>((ref) => null);

final selectedInstanceProvider = Provider<Instance?>((ref) {
  final id = ref.watch(selectedInstanceIdProvider);
  if (id == null) return null;
  final instances = ref.watch(instancesProvider);
  return instances.whenOrNull(
    data: (list) => list.cast<Instance?>().firstWhere((i) => i?.id == id, orElse: () => null),
  );
});

class InstancesNotifier extends StateNotifier<AsyncValue<List<Instance>>> {
  InstancesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInstances();
  }

  final InstanceRepository _repository;

  Future<void> loadInstances() async {
    try {
      state = const AsyncValue.loading();
      final instances = await _repository.getInstances();

      instances.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      state = AsyncValue.data(instances);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addInstance(Instance instance) async {
    try {
      int nextIndex = 0;
      if (state is AsyncData) {
        nextIndex = state.value!.length;
      } else {
        final instances = await _repository.getInstances();
        nextIndex = instances.length;
      }
      final newInstance = instance.copyWith(sortIndex: nextIndex);
      await _repository.saveInstance(newInstance);
      await loadInstances();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateInstance(Instance instance) async {
    try {
      await _repository.saveInstance(instance);
      if (state is AsyncData) {
        final currentList = state.value!;
        final index = currentList.indexWhere((i) => i.id == instance.id);
        if (index != -1) {
          final newList = List<Instance>.from(currentList);
          newList[index] = instance;
          newList.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
          state = AsyncValue.data(newList);
        }
      } else {
        await loadInstances();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteInstance(String id) async {
    try {
      await _repository.deleteInstance(id);
      if (state is AsyncData) {
        final currentList = state.value!;
        final newList = currentList.where((i) => i.id != id).toList();
        state = AsyncValue.data(newList);
      } else {
        await loadInstances();
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reorderInstances(int oldIndex, int newIndex) async {
    if (state is! AsyncData) return;
    final currentList = List<Instance>.from(state.value!);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, item);

    for (int i = 0; i < currentList.length; i++) {
      currentList[i] = currentList[i].copyWith(sortIndex: i);
      await _repository.saveInstance(currentList[i]);
    }

    state = AsyncValue.data(currentList);
  }

  Future<void> sortAlphabetically() async {
    if (state is! AsyncData) return;
    final currentList = List<Instance>.from(state.value!);

    currentList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (int i = 0; i < currentList.length; i++) {
      currentList[i] = currentList[i].copyWith(sortIndex: i);
      await _repository.saveInstance(currentList[i]);
    }

    state = AsyncValue.data(currentList);
  }
}
