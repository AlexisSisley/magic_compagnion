// lib/models/game_session.dart
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';

class LifeEvent {
  final int delta;
  final String? source;
  final Duration timestamp;

  const LifeEvent({
    required this.delta,
    this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'delta': delta,
    'source': source,
    'timestampMs': timestamp.inMilliseconds,
  };

  factory LifeEvent.fromJson(Map<String, dynamic> json) => LifeEvent(
    delta: json['delta'] as int,
    source: json['source'] as String?,
    timestamp: Duration(milliseconds: json['timestampMs'] as int),
  );
}

class PlayerState {
  final int playerId;
  final PlayerConfig config;
  final int life;
  final Map<String, int> counters;
  final Map<int, int> commanderDamageReceived;
  final bool isEliminated;
  final Duration? eliminatedAt;
  final bool isMonarch;
  final int quarterTurns;
  final List<LifeEvent> lifeHistory;

  const PlayerState({
    required this.playerId,
    required this.config,
    required this.life,
    this.counters = const {},
    this.commanderDamageReceived = const {},
    this.isEliminated = false,
    this.eliminatedAt,
    this.isMonarch = false,
    this.quarterTurns = 0,
    this.lifeHistory = const [],
  });

  PlayerState copyWith({
    int? playerId,
    PlayerConfig? config,
    int? life,
    Map<String, int>? counters,
    Map<int, int>? commanderDamageReceived,
    bool? isEliminated,
    Duration? eliminatedAt,
    bool? isMonarch,
    int? quarterTurns,
    List<LifeEvent>? lifeHistory,
  }) {
    return PlayerState(
      playerId: playerId ?? this.playerId,
      config: config ?? this.config,
      life: life ?? this.life,
      counters: counters ?? this.counters,
      commanderDamageReceived: commanderDamageReceived ?? this.commanderDamageReceived,
      isEliminated: isEliminated ?? this.isEliminated,
      eliminatedAt: eliminatedAt ?? this.eliminatedAt,
      isMonarch: isMonarch ?? this.isMonarch,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      lifeHistory: lifeHistory ?? this.lifeHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'config': config.toJson(),
    'life': life,
    'counters': counters,
    'commanderDamageReceived': commanderDamageReceived.map((k, v) => MapEntry(k.toString(), v)),
    'isEliminated': isEliminated,
    'eliminatedAtMs': eliminatedAt?.inMilliseconds,
    'isMonarch': isMonarch,
    'quarterTurns': quarterTurns,
    'lifeHistory': lifeHistory.map((e) => e.toJson()).toList(),
  };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
    playerId: json['playerId'] as int,
    config: PlayerConfig.fromJson(json['config'] as Map<String, dynamic>),
    life: json['life'] as int,
    counters: (json['counters'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as int)) ?? {},
    commanderDamageReceived: (json['commanderDamageReceived'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(int.parse(k), v as int)) ?? {},
    isEliminated: json['isEliminated'] as bool? ?? false,
    eliminatedAt: json['eliminatedAtMs'] != null
        ? Duration(milliseconds: json['eliminatedAtMs'] as int) : null,
    isMonarch: json['isMonarch'] as bool? ?? false,
    quarterTurns: json['quarterTurns'] as int? ?? 0,
    lifeHistory: (json['lifeHistory'] as List?)
        ?.map((e) => LifeEvent.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class GameSession {
  final String id;
  final GameFormat format;
  final List<PlayerState> players;
  final List<String> activeCounterIds;
  final List<String> customCounterIds;
  final DateTime? startedAt;
  final Duration duration;
  final bool isActive;
  final List<int> eliminationOrder;
  final List<int> playerOrder;
  final String? tag;

  const GameSession({
    required this.id,
    required this.format,
    required this.players,
    this.activeCounterIds = const [],
    this.customCounterIds = const [],
    this.startedAt,
    this.duration = Duration.zero,
    this.isActive = false,
    this.eliminationOrder = const [],
    this.playerOrder = const [],
    this.tag,
  });

  factory GameSession.newGame({
    required GameFormat format,
    required List<PlayerConfig> playerConfigs,
    List<String>? extraCounterIds,
    String? tag,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final players = List.generate(playerConfigs.length, (i) {
      return PlayerState(
        playerId: i,
        config: playerConfigs[i],
        life: format.startingLife,
      );
    });
    return GameSession(
      id: id,
      format: format,
      players: players,
      activeCounterIds: [...format.enabledCounterIds, ...?extraCounterIds],
      customCounterIds: extraCounterIds ?? [],
      playerOrder: List.generate(playerConfigs.length, (i) => i),
      tag: tag,
    );
  }

  GameSession copyWith({
    String? id,
    GameFormat? format,
    List<PlayerState>? players,
    List<String>? activeCounterIds,
    List<String>? customCounterIds,
    DateTime? startedAt,
    Duration? duration,
    bool? isActive,
    List<int>? eliminationOrder,
    List<int>? playerOrder,
    String? tag,
  }) {
    return GameSession(
      id: id ?? this.id,
      format: format ?? this.format,
      players: players ?? this.players,
      activeCounterIds: activeCounterIds ?? this.activeCounterIds,
      customCounterIds: customCounterIds ?? this.customCounterIds,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      eliminationOrder: eliminationOrder ?? this.eliminationOrder,
      playerOrder: playerOrder ?? this.playerOrder,
      tag: tag ?? this.tag,
    );
  }

  GameSession eliminatePlayer(int playerId, {required Duration atDuration}) {
    final updatedPlayers = players.map((p) {
      if (p.playerId == playerId) {
        return p.copyWith(isEliminated: true, eliminatedAt: atDuration);
      }
      return p;
    }).toList();
    return copyWith(
      players: updatedPlayers,
      eliminationOrder: [...eliminationOrder, playerId],
    );
  }

  GameSession reorderPlayers(List<int> newOrder) {
    return copyWith(playerOrder: newOrder);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'format': format.toJson(),
    'players': players.map((p) => p.toJson()).toList(),
    'activeCounterIds': activeCounterIds,
    'customCounterIds': customCounterIds,
    'startedAt': startedAt?.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'isActive': isActive,
    'eliminationOrder': eliminationOrder,
    'playerOrder': playerOrder,
    'tag': tag,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    id: json['id'] as String,
    format: GameFormat.fromJson(json['format'] as Map<String, dynamic>),
    players: (json['players'] as List)
        .map((p) => PlayerState.fromJson(p as Map<String, dynamic>))
        .toList(),
    activeCounterIds: (json['activeCounterIds'] as List?)?.cast<String>() ?? [],
    customCounterIds: (json['customCounterIds'] as List?)?.cast<String>() ?? [],
    startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    isActive: json['isActive'] as bool? ?? false,
    eliminationOrder: (json['eliminationOrder'] as List?)?.cast<int>() ?? [],
    playerOrder: (json['playerOrder'] as List?)?.cast<int>() ?? [],
    tag: json['tag'] as String?,
  );
}
