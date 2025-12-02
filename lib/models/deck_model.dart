// Fichier : lib/models/deck_model.dart

class DeckCard {
  final String scryfallId;
  final String name;
  int quantity;
  int proxyQuantity;

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    this.proxyQuantity = 0,
  });

  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
        'proxyQuantity': proxyQuantity,
      };

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        scryfallId: json['scryfallId'],
        name: json['name'],
        quantity: json['quantity'],
        proxyQuantity: json['proxyQuantity'] ?? 0,
      );
}

class Deck {
  String id;
  String name;
  List<DeckCard> mainboard;
  List<DeckCard> sideboard;
  String? commanderScryfallId;
  String? commanderSecondaryScryfallId; // <--- NOUVEAU : Pour les Partenaires / Backgrounds
  List<String> colors;
  String format;

  Deck({
    required this.id,
    required this.name,
    List<DeckCard>? mainboard,
    List<DeckCard>? sideboard,
    this.commanderScryfallId,
    this.commanderSecondaryScryfallId, // <--- NOUVEAU
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
        'commanderSecondaryScryfallId': commanderSecondaryScryfallId, // <--- NOUVEAU
        'colors': colors,
        'format': format,
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'],
        name: json['name'],
        mainboard: (json['mainboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        sideboard: (json['sideboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        commanderScryfallId: json['commanderScryfallId'],
        commanderSecondaryScryfallId: json['commanderSecondaryScryfallId'], // <--- NOUVEAU
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        format: json['format'] ?? 'Standard',
      );
}