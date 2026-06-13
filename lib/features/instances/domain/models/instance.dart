import 'package:equatable/equatable.dart';

enum ModLoader {
  vanilla,
  fabric,
  forge,
  neoforge,
  quilt;

  String get displayName {
    switch (this) {
      case ModLoader.vanilla:
        return 'Vanilla';
      case ModLoader.fabric:
        return 'Fabric';
      case ModLoader.forge:
        return 'Forge';
      case ModLoader.neoforge:
        return 'NeoForge';
      case ModLoader.quilt:
        return 'Quilt';
    }
  }

  static ModLoader fromString(String value) {
    return ModLoader.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ModLoader.vanilla,
    );
  }
}

class Instance extends Equatable {
  const Instance({
    required this.id,
    required this.name,
    required this.minecraftVersion,
    required this.loader,
    this.loaderVersion,
    this.profileId,
    required this.icon,
    this.playTimeMs = 0,
    this.lastPlayed,
    this.javaPath,
    this.minAllocatedRamMb,
    this.allocatedRamMb,
    this.jvmArgs,
    this.sortIndex = 0,
    this.sourceModpackId,
    this.sourceModpackVersionId,
  });

  final String id;

  final String name;

  final String minecraftVersion;

  final ModLoader loader;

  final String? loaderVersion;

  final String? profileId;

  final String icon;

  final int playTimeMs;

  final DateTime? lastPlayed;

  final String? javaPath;

  final int? minAllocatedRamMb;

  final int? allocatedRamMb;

  final String? jvmArgs;

  final int sortIndex;

  final String? sourceModpackId;

  final String? sourceModpackVersionId;

  factory Instance.fromJson(Map<String, dynamic> json) {
    return Instance(
      id: json['id'] as String,
      name: json['name'] as String,
      minecraftVersion: json['minecraftVersion'] as String,
      loader: ModLoader.fromString(json['loader'] as String? ?? 'vanilla'),
      loaderVersion: json['loaderVersion'] as String?,
      profileId: json['profileId'] as String?,
      icon: json['icon'] as String? ?? 'grass_block',
      playTimeMs: json['playTimeMs'] as int? ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'] as String)
          : null,
      javaPath: json['javaPath'] as String?,
      minAllocatedRamMb: json['minAllocatedRamMb'] as int?,
      allocatedRamMb: json['allocatedRamMb'] as int?,
      jvmArgs: json['jvmArgs'] as String?,
      sortIndex: json['sortIndex'] as int? ?? 0,
      sourceModpackId: json['sourceModpackId'] as String?,
      sourceModpackVersionId: json['sourceModpackVersionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minecraftVersion': minecraftVersion,
      'loader': loader.name,
      if (loaderVersion != null) 'loaderVersion': loaderVersion,
      if (profileId != null) 'profileId': profileId,
      'icon': icon,
      'playTimeMs': playTimeMs,
      if (lastPlayed != null) 'lastPlayed': lastPlayed!.toIso8601String(),
      if (javaPath != null) 'javaPath': javaPath,
      if (minAllocatedRamMb != null) 'minAllocatedRamMb': minAllocatedRamMb,
      if (allocatedRamMb != null) 'allocatedRamMb': allocatedRamMb,
      if (jvmArgs != null) 'jvmArgs': jvmArgs,
      'sortIndex': sortIndex,
      if (sourceModpackId != null) 'sourceModpackId': sourceModpackId,
      if (sourceModpackVersionId != null) 'sourceModpackVersionId': sourceModpackVersionId,
    };
  }

  Instance copyWith({
    String? name,
    String? minecraftVersion,
    ModLoader? loader,
    String? loaderVersion,
    String? profileId,
    String? icon,
    int? playTimeMs,
    DateTime? lastPlayed,
    bool clearJavaPath = false,
    String? javaPath,
    bool clearMinAllocatedRamMb = false,
    int? minAllocatedRamMb,
    bool clearAllocatedRamMb = false,
    int? allocatedRamMb,
    bool clearJvmArgs = false,
    String? jvmArgs,
    int? sortIndex,
    String? sourceModpackId,
    String? sourceModpackVersionId,
  }) {
    return Instance(
      id: this.id,
      name: name ?? this.name,
      minecraftVersion: minecraftVersion ?? this.minecraftVersion,
      loader: loader ?? this.loader,
      loaderVersion: loaderVersion ?? this.loaderVersion,
      profileId: profileId ?? this.profileId,
      icon: icon ?? this.icon,
      playTimeMs: playTimeMs ?? this.playTimeMs,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      javaPath: clearJavaPath ? null : (javaPath ?? this.javaPath),
      minAllocatedRamMb: clearMinAllocatedRamMb ? null : (minAllocatedRamMb ?? this.minAllocatedRamMb),
      allocatedRamMb: clearAllocatedRamMb ? null : (allocatedRamMb ?? this.allocatedRamMb),
      jvmArgs: clearJvmArgs ? null : (jvmArgs ?? this.jvmArgs),
      sortIndex: sortIndex ?? this.sortIndex,
      sourceModpackId: sourceModpackId ?? this.sourceModpackId,
      sourceModpackVersionId: sourceModpackVersionId ?? this.sourceModpackVersionId,
    );
  }

  Instance clearOverrides() {
    return Instance(
      id: id,
      name: name,
      minecraftVersion: minecraftVersion,
      loader: loader,
      loaderVersion: loaderVersion,
      profileId: profileId,
      icon: icon,
      playTimeMs: playTimeMs,
      lastPlayed: lastPlayed,
      javaPath: null,
      minAllocatedRamMb: null,
      allocatedRamMb: null,
      jvmArgs: null,
      sortIndex: sortIndex,
      sourceModpackId: sourceModpackId,
      sourceModpackVersionId: sourceModpackVersionId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        minecraftVersion,
        loader,
        loaderVersion,
        profileId,
        icon,
        playTimeMs,
        lastPlayed,
        javaPath,
        minAllocatedRamMb,
        allocatedRamMb,
        jvmArgs,
        sortIndex,
        sourceModpackId,
        sourceModpackVersionId,
      ];
}
