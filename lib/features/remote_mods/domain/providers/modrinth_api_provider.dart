import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/remote_mod.dart';

class ModrinthApiProvider {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.modrinth.com/v2',
    headers: {
      'User-Agent': 'Ausrine Launcher/1.0.0 (areedelahi@gmail.com)',
    },
  ));

  String _mapProjectType(String folderName) {
    if (folderName == 'modpacks') return 'modpack';
    if (folderName == 'resourcepacks') return 'resourcepack';
    if (folderName == 'shaderpacks') return 'shader';
    return 'mod';
  }

  Future<List<RemoteMod>> search({
    required String query,
    required String folderName,
    String? gameVersion,
    String? loader,
    bool showAllVersions = false,
  }) async {
    final projectType = _mapProjectType(folderName);

    final facets = <List<String>>[
      ['project_type:$projectType']
    ];

    if (!showAllVersions) {
      if (gameVersion != null && gameVersion.isNotEmpty) {
        facets.add(['versions:$gameVersion']);
      }
      if (loader != null && loader.isNotEmpty && projectType == 'mod') {
        facets.add(['categories:${loader.toLowerCase()}']);
      }
    }

    final response = await _dio.get('/search', queryParameters: {
      'query': query,
      'limit': 20,
      'facets': jsonEncode(facets),
    });

    final hits = response.data['hits'] as List;
    return hits.map((hit) {
      return RemoteMod(
        id: hit['project_id'],
        slug: hit['slug'],
        title: hit['title'],
        author: hit['author'],
        description: hit['description'],
        iconUrl: hit['icon_url'],
        downloadCount: hit['downloads'] ?? 0,
        categories: List<String>.from(hit['categories'] ?? []),
        source: 'modrinth',
      );
    }).toList();
  }

  Future<List<RemoteModVersion>> getVersions(String projectId, {
    String? gameVersion,
    String? loader,
    bool showAllVersions = false,
  }) async {
    final Map<String, dynamic> queryParams = {};

    if (!showAllVersions) {
      if (gameVersion != null && gameVersion.isNotEmpty) {
        queryParams['game_versions'] = jsonEncode([gameVersion]);
      }
      if (loader != null && loader.isNotEmpty) {
        queryParams['loaders'] = jsonEncode([loader.toLowerCase()]);
      }
    }

    final response = await _dio.get('/project/$projectId/version', queryParameters: queryParams);

    final versions = response.data as List;
    return versions.map((v) {
      final files = v['files'] as List;
      final primaryFile = files.firstWhere((f) => f['primary'] == true, orElse: () => files.first);

      return RemoteModVersion(
        id: v['id'],
        versionNumber: v['version_number'],
        name: v['name'],
        releaseType: v['version_type'], 
        datePublished: DateTime.parse(v['date_published']),
        downloadUrl: primaryFile['url'],
        filename: primaryFile['filename'],
        gameVersions: List<String>.from(v['game_versions'] ?? []),
        loaders: List<String>.from(v['loaders'] ?? []),
      );
    }).toList();
  }
}
