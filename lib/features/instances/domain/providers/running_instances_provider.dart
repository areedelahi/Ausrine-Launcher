import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../src/rust/api/launcher.dart';

final runningInstancesProvider = StateNotifierProvider<RunningInstancesNotifier, Map<String, int>>((ref) {
  return RunningInstancesNotifier();
});

class RunningInstancesNotifier extends StateNotifier<Map<String, int>> {
  RunningInstancesNotifier() : super({});

  void setRunning(String instanceId, int pid) {
    state = {...state, instanceId: pid};
  }

  void setExited(String instanceId) {
    final newState = Map<String, int>.from(state);
    newState.remove(instanceId);
    state = newState;
  }

  void kill(String instanceId) {
    final pid = state[instanceId];
    if (pid != null) {
      killProcess(pid: pid);
    }
  }
}
