// Fichier : lib/models/profile_model.dart

class Profile {
  final String id;
  String name;
  int colorValue; // Couleur préférée
  String? commanderScryfallId; // ID Scryfall du commandant
  String? commanderName; // Nom du commandant (pour affichage rapide)

  Profile({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3, // Bleu par défaut
    this.commanderScryfallId,
    this.commanderName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'commanderScryfallId': commanderScryfallId,
    'commanderName': commanderName,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'],
    name: json['name'],
    colorValue: json['colorValue'] ?? 0xFF2196F3,
    commanderScryfallId: json['commanderScryfallId'],
    commanderName: json['commanderName'],
  );
  
  // URL de l'image (Art Crop)
  String? get commanderImageUrl {
    if (commanderScryfallId == null) return null;
    return "https://api.scryfall.com/cards/$commanderScryfallId?format=image&version=art_crop";
  }
}