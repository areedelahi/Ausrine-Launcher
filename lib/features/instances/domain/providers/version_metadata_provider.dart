import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ausrine_launcher/src/rust/api/metadata.dart';
import 'package:dio/dio.dart';

final vanillaVersionsProvider = FutureProvider<List<VanillaVersion>>((ref) async {
  return await getVanillaVersions();
});

final fabricLoadersProvider = FutureProvider<List<String>>((ref) async {
  return await getFabricLoaders();
});

final forgeLoadersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await getForgeVersions();
  } catch (e) {
    print("Rust forge fetch failed, falling back to Dart: $e");
    final dio = Dio();

    final response = await dio.get("https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml");
    final xml = response.data as String;
    final regex = RegExp(r"<version>(.*?)</version>");
    final versions = regex.allMatches(xml).map((m) => m.group(1)!).toList();
    return versions.reversed.toList(); 
  }
});

final neoForgeLoadersProvider = FutureProvider<List<String>>((ref) async {
  return await getNeoforgeVersions();
});

final quiltLoadersProvider = FutureProvider<List<String>>((ref) async {
  return await getQuiltLoaders();
});
