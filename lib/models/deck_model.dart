// Fichier : lib/models/deck_model.dart

class DeckCard {
  final String scryfallId;
  final String name;
  int quantity;

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
      };

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        scryfallId: json['scryfallId'],
        name: json['name'],
        quantity: json['quantity'],
      );
}

class Deck {
  String id;
  String name;
  List<DeckCard> mainboard;
  List<DeckCard> sideboard;
  String? commanderScryfallId;
  
  // --- NOUVEAUX CHAMPS ---
  List<String> colors; // Ex: ["W", "U", "B"]
  String format;       // Ex: "Commander", "Standard"

  Deck({
    required this.id,
    required this.name,
    List<DeckCard>? mainboard,
    List<DeckCard>? sideboard,
    this.commanderScryfallId,
    List<String>? colors,
    this.format = 'Standard',
  })  : this.mainboard = mainboard ?? [],
        this.sideboard = sideboard ?? [],
        this.colors = colors ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mainboard': mainboard.map((c) => c.toJson()).toList(),
        'sideboard': sideboard.map((c) => c.toJson()).toList(),
        'commanderScryfallId': commanderScryfallId,
        'colors': colors, // Sauvegarde
        'format': format,
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'],
        name: json['name'],
        mainboard: (json['mainboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        sideboard: (json['sideboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        commanderScryfallId: json['commanderScryfallId'],
        // Chargement (avec fallback)
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        format: json['format'] ?? 'Standard',
      );
}