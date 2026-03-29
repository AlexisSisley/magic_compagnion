// lib/models/player_config.dart

enum PlayerType { owner, guest }

class CommanderInfo {
  final String name;
  final String? scryfallId;
  final String? artCropUrl;

  const CommanderInfo({
    required this.name,
    this.scryfallId,
    this.artCropUrl,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'scryfallId': scryfallId,
        'artCropUrl': artCropUrl,
      };

  factory CommanderInfo.fromJson(Map<String, dynamic> json) => CommanderInfo(
        name: json['name'] as String,
        scryfallId: json['scryfallId'] as String?,
        artCropUrl: json['artCropUrl'] as String?,
      );
}

class PlayerConfig {
  final String id;
  final String name;
  final PlayerType type;
  final int colorValue;
  final String? avatarPath;
  final String? linkedDeckId;
  final List<CommanderInfo> commanders;

  const PlayerConfig({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF2196F3,
    this.avatarPath,
    this.linkedDeckId,
    this.commanders = const [],
  });

  bool get isOwner => type == PlayerType.owner;
  bool get isGuest => type == PlayerType.guest;

  PlayerConfig copyWith({
    String? id,
    String? name,
    PlayerType? type,
    int? colorValue,
    String? avatarPath,
    String? linkedDeckId,
    List<CommanderInfo>? commanders,
  }) {
    return PlayerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      avatarPath: avatarPath ?? this.avatarPath,
      linkedDeckId: linkedDeckId ?? this.linkedDeckId,
      commanders: commanders ?? this.commanders,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'colorValue': colorValue,
        'avatarPath': avatarPath,
        'linkedDeckId': linkedDeckId,
        'commanders': commanders.map((c) => c.toJson()).toList(),
      };

  factory PlayerConfig.fromJson(Map<String, dynamic> json) => PlayerConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        type: PlayerType.values.where((t) => t.name == json['type']).firstOrNull ?? PlayerType.guest,
        colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
        avatarPath: json['avatarPath'] as String?,
        linkedDeckId: json['linkedDeckId'] as String?,
        commanders: (json['commanders'] as List?)
                ?.map((c) => CommanderInfo.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
