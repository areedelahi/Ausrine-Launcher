
class UserAccount {
  const UserAccount({
    required this.uuid,
    required this.username,
    required this.type,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.isActive,
    this.skinUrl,
    this.capes = const [],
    this.activeCapeId,
  });

  final String uuid;

  final String username;

  final String type;

  final String accessToken;

  final String refreshToken;

  final DateTime expiresAt;

  final bool isActive;

  final String? skinUrl;

  final List<MinecraftCape> capes;
  final String? activeCapeId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  UserAccount copyWith({
    String? uuid,
    String? username,
    String? type,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool? isActive,
    String? skinUrl,
    List<MinecraftCape>? capes,
    String? activeCapeId,
  }) {
    return UserAccount(
      uuid: uuid ?? this.uuid,
      username: username ?? this.username,
      type: type ?? this.type,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      skinUrl: skinUrl ?? this.skinUrl,
      capes: capes ?? this.capes,
      activeCapeId: activeCapeId ?? this.activeCapeId,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'username': username,
        'type': type,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'isActive': isActive,
        if (skinUrl != null) 'skinUrl': skinUrl,
        if (capes.isNotEmpty) 'capes': capes.map((e) => e.toJson()).toList(),
        if (activeCapeId != null) 'activeCapeId': activeCapeId,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        uuid: json['uuid'] as String,
        username: json['username'] as String,
        type: json['type'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        isActive: json['isActive'] as bool,
        skinUrl: json['skinUrl'] as String?,
        capes: json['capes'] == null
            ? const []
            : (json['capes'] as List)
                .map((e) => MinecraftCape.fromJson(e as Map<String, dynamic>))
                .toList(),
        activeCapeId: json['activeCapeId'] as String?,
      );
}

class MinecraftCape {
  final String id;
  final String alias;
  final String url;

  const MinecraftCape({
    required this.id,
    required this.alias,
    required this.url,
  });

  factory MinecraftCape.fromJson(Map<String, dynamic> json) => MinecraftCape(
        id: json['id'] as String,
        alias: json['alias'] as String,
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alias': alias,
        'url': url,
      };
}
