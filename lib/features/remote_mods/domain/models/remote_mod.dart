class RemoteMod {
  const RemoteMod({
    required this.id,
    required this.slug,
    required this.title,
    required this.author,
    required this.description,
    required this.iconUrl,
    required this.downloadCount,
    required this.categories,
    required this.source,
  });

  final String id;
  final String slug;
  final String title;
  final String author;
  final String description;
  final String? iconUrl;
  final int downloadCount;
  final List<String> categories;
  final String source; 
}

class RemoteModVersion {
  const RemoteModVersion({
    required this.id,
    required this.versionNumber,
    required this.name,
    required this.releaseType, 
    required this.datePublished,
    required this.downloadUrl,
    required this.filename,
    required this.gameVersions,
    required this.loaders,
  });

  final String id;
  final String versionNumber;
  final String name;
  final String releaseType;
  final DateTime datePublished;
  final String downloadUrl;
  final String filename;
  final List<String> gameVersions;
  final List<String> loaders;
}
