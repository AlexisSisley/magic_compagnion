// lib/models/game_format.dart

class GameFormat {
  final String id;
  final String name;
  final int startingLife;
  final int minPlayers;
  final int maxPlayers;
  final int maxCommanders; // -1 = unlimited
  final List<String> enabledCounterIds;
  final bool isBuiltIn;

  /// Max poison counters before a player loses (0 = disabled). Default: 10.
  final int maxPoison;

  /// Max commander damage from a single source before a player loses (0 = disabled). Default: 21.
  final int maxCommanderDamage;

  /// Whether a player loses when their life reaches 0 or below.
  final bool lethalAtZeroLife;

  const GameFormat({
    required this.id,
    required this.name,
    required this.startingLife,
    required this.minPlayers,
    required this.maxPlayers,
    required this.maxCommanders,
    required this.enabledCounterIds,
    this.isBuiltIn = false,
    this.maxPoison = 10,
    this.maxCommanderDamage = 21,
    this.lethalAtZeroLife = true,
  });

  GameFormat copyWith({
    String? id,
    String? name,
    int? startingLife,
    int? minPlayers,
    int? maxPlayers,
    int? maxCommanders,
    List<String>? enabledCounterIds,
    bool? isBuiltIn,
    int? maxPoison,
    int? maxCommanderDamage,
    bool? lethalAtZeroLife,
  }) {
    return GameFormat(
      id: id ?? this.id,
      name: name ?? this.name,
      startingLife: startingLife ?? this.startingLife,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      maxCommanders: maxCommanders ?? this.maxCommanders,
      enabledCounterIds: enabledCounterIds ?? this.enabledCounterIds,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      maxPoison: maxPoison ?? this.maxPoison,
      maxCommanderDamage: maxCommanderDamage ?? this.maxCommanderDamage,
      lethalAtZeroLife: lethalAtZeroLife ?? this.lethalAtZeroLife,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startingLife': startingLife,
        'minPlayers': minPlayers,
        'maxPlayers': maxPlayers,
        'maxCommanders': maxCommanders,
        'enabledCounterIds': enabledCounterIds,
        'isBuiltIn': isBuiltIn,
        'maxPoison': maxPoison,
        'maxCommanderDamage': maxCommanderDamage,
        'lethalAtZeroLife': lethalAtZeroLife,
      };

  factory GameFormat.fromJson(Map<String, dynamic> json) => GameFormat(
        id: json['id'] as String,
        name: json['name'] as String,
        startingLife: json['startingLife'] as int,
        minPlayers: json['minPlayers'] as int,
        maxPlayers: json['maxPlayers'] as int,
        maxCommanders: json['maxCommanders'] as int,
        enabledCounterIds: (json['enabledCounterIds'] as List? ?? []).cast<String>(),
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        maxPoison: json['maxPoison'] as int? ?? 10,
        maxCommanderDamage: json['maxCommanderDamage'] as int? ?? 21,
        lethalAtZeroLife: json['lethalAtZeroLife'] as bool? ?? true,
      );

  /// All built-in format presets
  static const List<GameFormat> builtInFormats = [
    GameFormat(
      id: 'commander',
      name: 'Commander',
      startingLife: 40,
      minPlayers: 2,
      maxPlayers: 8,
      maxCommanders: 2,
      enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'duel_commander',
      name: 'Duel Commander',
      startingLife: 30,
      minPlayers: 2,
      maxPlayers: 2,
      maxCommanders: 2,
      enabledCounterIds: ['poison', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'standard',
      name: 'Standard',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 2,
      maxCommanders: 0,
      enabledCounterIds: ['poison', 'energy'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'oathbreaker',
      name: 'Oathbreaker',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 6,
      maxCommanders: 1,
      enabledCounterIds: ['poison', 'energy'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'brawl',
      name: 'Brawl',
      startingLife: 25,
      minPlayers: 2,
      maxPlayers: 4,
      maxCommanders: 1,
      enabledCounterIds: ['poison', 'energy', 'commander_damage'],
      isBuiltIn: true,
    ),
    GameFormat(
      id: 'custom',
      name: 'Custom',
      startingLife: 20,
      minPlayers: 2,
      maxPlayers: 8,
      maxCommanders: -1,
      enabledCounterIds: ['poison', 'energy', 'commander_tax', 'commander_damage'],
      isBuiltIn: true,
    ),
  ];
}
