class GameHistoryItem {
  final String id;
  final DateTime date;
  final List<String> playerNames; // Ex: ["Moi", "Adversaire"]
  final String winnerName;        // Ex: "Moi"
  final String format;            // Ex: "Commander"

  GameHistoryItem({
    required this.id,
    required this.date,
    required this.playerNames,
    required this.winnerName,
    this.format = 'Standard',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'playerNames': playerNames,
    'winnerName': winnerName,
    'format': format,
  };

  factory GameHistoryItem.fromJson(Map<String, dynamic> json) => GameHistoryItem(
    id: json['id'],
    date: DateTime.parse(json['date']),
    playerNames: List<String>.from(json['playerNames']),
    winnerName: json['winnerName'],
    format: json['format'] ?? 'Standard',
  );
}