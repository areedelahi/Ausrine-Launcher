import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  try {
    final key = enc.Key(Uint8List.fromList('Ausrine LauncherV1SecretKey!XMCLS1'.codeUnits));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt("hello world", iv: iv);
    print("Success!");
  } catch (e) {
    print("Error: $e");
  }
}
