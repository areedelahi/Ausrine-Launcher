import '../providers/local_mod_parser.dart';

class LocalFileItem {
  const LocalFileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isEnabled,
    required this.isDirectory,
    required this.lastModified,
    this.metadata,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final bool isEnabled;
  final bool isDirectory;
  final DateTime lastModified;
  final LocalModMetadata? metadata;
}
