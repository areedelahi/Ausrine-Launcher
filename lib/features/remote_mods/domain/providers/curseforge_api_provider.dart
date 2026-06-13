import 'package:dio/dio.dart';
import '../models/remote_mod.dart';

class CurseForgeApiProvider {
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.curseforge.com/v1',
    headers: {
      'Accept': 'application/json',
      'x-api-key': '\$2a\$10\$bL4bIL5pUWqfcO7KQ0PhOwQ3cRxZE8DML2kR3h.sC6lZOhH2tFUSC',
      'User-Agent': 'Ausrine Launcher/1.0.0 (areedelahi@gmail.com)',
    },
  ));

  int _mapClassId(String folderName) {
    if (folderName == 'resourcepacks') return 12;
    if (folderName == 'shaderpacks') return 6552;
    return 6; 
  }

  int? _mapLoader(String? loader) {
    if (loader == null) return null;
    switch (loader.toLowerCase()) {
      case 'forge': return 1;
      case 'fabric': return 4;
      case 'quilt': return 5;
      case 'neoforge': return 6;
      default: return 0;
    }
  }

  Future<List<RemoteMod>> search({
    required String query,
    required String folderName,
    String? gameVersion,
    String? loader,
    bool showAllVersions = false,
  }) async {
    final classId = _mapClassId(folderName);

    final Map<String, dynamic> queryParams = {
      'gameId': 432,
      'classId': classId,
      'searchFilter': query,
      'pageSize': 20,
    };

    if (!showAllVersions) {
      if (gameVersion != null && gameVersion.isNotEmpty) {
        queryParams['gameVersion'] = gameVersion;
      }
      if (loader != null && loader.isNotEmpty && classId == 6) {
        final loaderType = _mapLoader(loader);
        if (loaderType != null && loaderType > 0) {
          queryParams['modLoaderType'] = loaderType;
        }
      }
    }

    final response = await _dio.get('/mods/search', queryParameters: queryParams);

    final data = response.data['data'] as List;
    return data.map((mod) {
      return RemoteMod(
        id: mod['id'].toString(),
        slug: mod['slug'],
        title: mod['name'],
        author: mod['authors'] != null && (mod['authors'] as List).isNotEmpty ? mod['authors'][0]['name'] : 'Unknown',
        description: mod['summary'],
        iconUrl: mod['logo'] != null ? mod['logo']['thumbnailUrl'] : null,
        downloadCount: (mod['downloadCount'] as num).toInt(),
        categories: (mod['categories'] as List).map((c) => c['name'] as String).toList(),
        source: 'curseforge',
      );
    }).toList();
  }

  Future<List<RemoteModVersion>> getVersions(String modId, {
    String? gameVersion,
    String? loader,
    bool showAllVersions = false,
  }) async {
    final Map<String, dynamic> queryParams = {
      'pageSize': 20,
    };

    if (!showAllVersions) {
      if (gameVersion != null && gameVersion.isNotEmpty) {
        queryParams['gameVersion'] = gameVersion;
      }
      if (loader != null && loader.isNotEmpty) {
        final loaderType = _mapLoader(loader);
        if (loaderType != null && loaderType > 0) {
          queryParams['modLoaderType'] = loaderType;
        }
      }
    }

    final response = await _dio.get('/mods/$modId/files', queryParameters: queryParams);

    final data = response.data['data'] as List;
    return data.map((f) {
      final releaseTypeInt = f['releaseType'] as int;
      final releaseType = releaseTypeInt == 1 ? 'release' : (releaseTypeInt == 2 ? 'beta' : 'alpha');

      return RemoteModVersion(
        id: f['id'].toString(),
        versionNumber: f['displayName'],
        name: f['displayName'],
        releaseType: releaseType,
        datePublished: DateTime.parse(f['fileDate']),
        downloadUrl: f['downloadUrl'] ?? '', 
        filename: f['fileName'],
        gameVersions: List<String>.from(f['gameVersions'] ?? []),
        loaders: [], 
      );
    }).toList();
  }
}
