class Profile {
  final String id;
  String name;
  int colorValue;
  String? commanderScryfallId;
  String? commanderName;
  // NOUVEAUX CHAMPS
  String? secondaryCommanderScryfallId;
  String? secondaryCommanderName;

  Profile({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3,
    this.commanderScryfallId,
    this.commanderName,
    this.secondaryCommanderScryfallId,
    this.secondaryCommanderName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'commanderScryfallId': commanderScryfallId,
    'commanderName': commanderName,
    'secondaryCommanderScryfallId': secondaryCommanderScryfallId,
    'secondaryCommanderName': secondaryCommanderName,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'],
    name: json['name'],
    colorValue: json['colorValue'] ?? 0xFF2196F3,
    commanderScryfallId: json['commanderScryfallId'],
    commanderName: json['commanderName'],
    secondaryCommanderScryfallId: json['secondaryCommanderScryfallId'],
    secondaryCommanderName: json['secondaryCommanderName'],
  );
  
  String? get commanderImageUrl {
    if (commanderScryfallId == null) return null;
    return "https://api.scryfall.com/cards/$commanderScryfallId?format=image&version=art_crop";
  }

  String? get secondaryCommanderImageUrl {
    if (secondaryCommanderScryfallId == null) return null;
    return "https://api.scryfall.com/cards/$secondaryCommanderScryfallId?format=image&version=art_crop";
  }
}