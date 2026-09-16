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

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final rawPlayers = (json['players'] as List)
        .map((p) => PlayerState.fromJson(p as Map<String, dynamic>))
        .toList();
    final rawPlayerOrder = (json['playerOrder'] as List?)?.cast<int>() ?? [];
    final (players, playerOrder) = rawPlayerOrder.length == rawPlayers.length
        ? _migrateLegacyOrder(rawPlayers, rawPlayerOrder)
        : (rawPlayers, rawPlayerOrder);

    return GameSession(
      id: json['id'] as String,
      format: GameFormat.fromJson(json['format'] as Map<String, dynamic>),
      players: players,
      activeCounterIds: (json['activeCounterIds'] as List?)?.cast<String>() ?? [],
      customCounterIds: (json['customCounterIds'] as List?)?.cast<String>() ?? [],
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      isActive: json['isActive'] as bool? ?? false,
      eliminationOrder: (json['eliminationOrder'] as List?)?.cast<int>() ?? [],
      playerOrder: playerOrder,
      tag: json['tag'] as String?,
    );
  }

  /// Migration silencieuse d'un ancien snapshot (M-3).
  ///
  /// Avant que `playerOrder` ne devienne la seule source de vérité de la
  /// disposition d'affichage (§3.1 du design), les versions installées
  /// permutaient physiquement la liste `players` pour représenter l'ordre
  /// choisi par le joueur, et laissaient `playerOrder` à l'identité (le
  /// champ n'existait pas encore, ou n'était pas encore consommé). Le code
  /// actuel suppose l'inverse : `players` toujours trié par `playerId`,
  /// `playerOrder` seul porteur de la disposition. Sans cette migration, un
  /// tel snapshot chargerait `_orderedPlayers` sur un `playerOrder` identité
  /// — la disposition choisie par le joueur serait perdue au premier
  /// lancement après mise à jour.
  ///
  /// Heuristique : si `playerOrder` est l'identité alors que `players` ne
  /// l'est pas (par `playerId`), c'est un ancien snapshot — on dérive
  /// `playerOrder` de l'ordre physique observé, et on retrie `players` en
  /// ordre canonique. Un snapshot déjà écrit par le code actuel ne déclenche
  /// jamais cette branche : soit `players` est déjà canonique (rien à
  /// migrer), soit `playerOrder` porte un vrai reorder (donc pas l'identité).
  static (List<PlayerState>, List<int>) _migrateLegacyOrder(
    List<PlayerState> players,
    List<int> playerOrder,
  ) {
    final identity = List<int>.generate(players.length, (i) => i);
    final physicalOrder = players.map((p) => p.playerId).toList();
    final playerOrderIsIdentity = _intListEquals(playerOrder, identity);
    final playersArePhysicallyPermuted = !_intListEquals(physicalOrder, identity);

    if (playerOrderIsIdentity && playersArePhysicallyPermuted) {
      final canonicalPlayers = [...players]
        ..sort((a, b) => a.playerId.compareTo(b.playerId));
      return (canonicalPlayers, physicalOrder);
    }
    return (players, playerOrder);
  }

  static bool _intListEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
