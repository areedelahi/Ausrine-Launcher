import 'dart:io';

class DirectorySize {
  static Future<int> calculate(Directory dir) async {
    int totalSize = 0;
    try {
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {

    }
    return totalSize;
  }
}
