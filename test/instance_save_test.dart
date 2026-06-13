import 'package:flutter_test/flutter_test.dart';
import 'package:ausrine_launcher/features/instances/domain/models/instance.dart';

void main() {
  test('Instance clearOverrides', () {
    var inst = Instance(
      id: 'test',
      name: 'test',
      minecraftVersion: '1.20',
      loader: ModLoader.vanilla,
      icon: 'grass',
      jvmArgs: 'hello',
      allocatedRamMb: 1024,
      javaPath: '/bin/java',
    );
    inst = inst.clearOverrides();
    print(inst.toJson());
  });
}
