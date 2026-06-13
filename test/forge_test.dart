import 'package:flutter_test/flutter_test.dart';
import 'package:ausrine_launcher/src/rust/api/metadata.dart';
import 'package:ausrine_launcher/src/rust/frb_generated.dart';

void main() {
  test('fetch forge versions', () async {
    await RustLib.init();
    try {
      final versions = await getForgeVersions();
      print("Forge versions: ${versions.length}");
    } catch (e) {
      print("Forge Error: $e");
    }
  });
}
