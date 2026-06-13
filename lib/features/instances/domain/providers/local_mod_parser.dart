import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:archive/archive_io.dart';

class LocalModMetadata {
  const LocalModMetadata({
    required this.id,
    required this.name,
    required this.version,
    this.author,
    this.description,
  });

  final String id;
  final String name;
  final String version;
  final String? author;
  final String? description;
}

class LocalModParser {
  static Future<LocalModMetadata?> parse(File file) async {
    try {

      if (await file.stat().then((s) => s.type == FileSystemEntityType.directory)) {
        final levelDat = File('${file.path}/level.dat');
        if (await levelDat.exists()) {
          final bytes = await levelDat.readAsBytes();

          final unzipped = GZipDecoder().decodeBytes(bytes);

          final searchPattern = [0x08, 0x00, 0x09, 0x4C, 0x65, 0x76, 0x65, 0x6C, 0x4E, 0x61, 0x6D, 0x65];

          String? worldName;
          for (int i = 0; i < unzipped.length - searchPattern.length - 2; i++) {
            bool match = true;
            for (int j = 0; j < searchPattern.length; j++) {
              if (unzipped[i + j] != searchPattern[j]) {
                match = false;
                break;
              }
            }
            if (match) {

              final strLen = (unzipped[i + searchPattern.length] << 8) | unzipped[i + searchPattern.length + 1];
              final strStart = i + searchPattern.length + 2;
              if (strStart + strLen <= unzipped.length) {
                worldName = utf8.decode(unzipped.sublist(strStart, strStart + strLen));
              }
              break;
            }
          }

          return LocalModMetadata(
            id: file.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
            name: worldName ?? file.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
            version: '',
          );
        }
        return null;
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fabricJson = archive.findFile('fabric.mod.json');
      if (fabricJson != null) {
        final content = utf8.decode(fabricJson.content as List<int>);
        final map = jsonDecode(content) as Map<String, dynamic>;

        final authors = map['authors'];
        String? authorStr;
        if (authors is List && authors.isNotEmpty) {
          authorStr = authors.first is String ? authors.first : (authors.first['name'] as String?);
        }

        return LocalModMetadata(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? map['id']?.toString() ?? '',
          version: map['version']?.toString() ?? '',
          description: map['description']?.toString(),
          author: authorStr,
        );
      }

      final forgeToml = archive.findFile('META-INF/mods.toml') ?? archive.findFile('META-INF/neoforge.mods.toml');
      if (forgeToml != null) {
        final content = utf8.decode(forgeToml.content as List<int>);

        String extract(String key) {
          final match = RegExp('$key\\s*=\\s*"([^"]+)"').firstMatch(content);
          return match?.group(1) ?? '';
        }

        final modId = extract('modId');
        return LocalModMetadata(
          id: modId,
          name: extract('displayName').isEmpty ? modId : extract('displayName'),
          version: extract('version'),
          description: extract('description'),
          author: extract('authors'),
        );
      }

      final packMcmeta = archive.findFile('pack.mcmeta');
      if (packMcmeta != null) {
        final content = utf8.decode(packMcmeta.content as List<int>);
        final map = jsonDecode(content) as Map<String, dynamic>;
        final pack = map['pack'] as Map<String, dynamic>?;

        return LocalModMetadata(
          id: file.uri.pathSegments.last,
          name: file.uri.pathSegments.last,
          version: pack?['pack_format']?.toString() ?? '',
          description: pack?['description']?.toString(),
        );
      }
    } catch (e, stack) {
      print('LocalModParser error: \$e\\n\$stack');

    }
    return null;
  }
}
