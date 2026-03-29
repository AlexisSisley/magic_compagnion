// Fichier : lib/models/game_history_model.dart

class GameHistoryItem {
  final String id;
  final DateTime date;
  final int durationSeconds; // <--- NOUVEAU : Durée en secondes
  final String winnerName;
  final String format; // Commander, Standard...
  final String winMethod; // 'normal', 'commander', 'poison', 'concede'

  // Liste des états finaux des joueurs
  final List<PlayerHistorySnapshot> playerStates;

  GameHistoryItem({
    required this.id,
    required this.date,
    required this.durationSeconds,
    required this.winnerName,
    this.format = 'Standard',
    this.winMethod = 'normal',
    required this.playerStates,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
    'winnerName': winnerName,
    'format': format,
    'winMethod': winMethod,
    'playerStates': playerStates.map((p) => p.toJson()).toList(),
  };

  factory GameHistoryItem.fromJson(Map<String, dynamic> json) => GameHistoryItem(
    id: json['id'],
    date: DateTime.parse(json['date']),
    durationSeconds: json['durationSeconds'] ?? 0,
    winnerName: json['winnerName'],
    format: json['format'] ?? 'Standard',
    winMethod: json['winMethod'] ?? 'normal',
    playerStates: (json['playerStates'] as List?)
        ?.map((e) => PlayerHistorySnapshot.fromJson(e))
        .toList() ?? [],
  );
}

// Sous-classe pour stocker l'état d'un joueur à la fin
class PlayerHistorySnapshot {
  final String name;
  final String? imageUrl;
  final int life;
  final int poison;
  final int commanderDamageTaken; // Total des dégâts de commandant reçus

  // New enriched fields (backward-compatible, all nullable or with defaults)
  final String? type; // 'owner' | 'guest'
  final String? deckName;
  final List<String> commanderNames;
  final int energy;
  final int commanderTax;
  final bool isEliminated;
  final int? eliminatedAtSeconds;
  final int? eliminationRank;

  PlayerHistorySnapshot({
    required this.name,
    this.imageUrl,
    required this.life,
    required this.poison,
    required this.commanderDamageTaken,
    this.type,
    this.deckName,
    List<String>? commanderNames,
    this.energy = 0,
    this.commanderTax = 0,
    this.isEliminated = false,
    this.eliminatedAtSeconds,
    this.eliminationRank,
  }) : commanderNames = commanderNames ?? [];

  Map<String, dynamic> toJson() => {
    'name': name,
    'imageUrl': imageUrl,
    'life': life,
    'poison': poison,
    'commanderDamageTaken': commanderDamageTaken,
    'type': type,
    'deckName': deckName,
    'commanderNames': commanderNames,
    'energy': energy,
    'commanderTax': commanderTax,
    'isEliminated': isEliminated,
    'eliminatedAtSeconds': eliminatedAtSeconds,
    'eliminationRank': eliminationRank,
  };

  factory PlayerHistorySnapshot.fromJson(Map<String, dynamic> json) => PlayerHistorySnapshot(
    name: json['name'],
    imageUrl: json['imageUrl'],
    life: json['life'] ?? 0,
    poison: json['poison'] ?? 0,
    commanderDamageTaken: json['commanderDamageTaken'] ?? 0,
    type: json['type'],
    deckName: json['deckName'],
    commanderNames: (json['commanderNames'] as List?)
        ?.map((e) => e as String)
        .toList() ?? [],
    energy: json['energy'] ?? 0,
    commanderTax: json['commanderTax'] ?? 0,
    isEliminated: json['isEliminated'] ?? false,
    eliminatedAtSeconds: json['eliminatedAtSeconds'],
    eliminationRank: json['eliminationRank'],
  );
}
