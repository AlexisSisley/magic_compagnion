// Fichier : lib/models/deck_model.dart

class DeckCard {
  final String scryfallId;
  final String name;
  int quantity;
  int proxyQuantity;
  bool isFoil; // <--- NOUVEAU

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    this.proxyQuantity = 0,
    this.isFoil = false, // Défaut false
  });

  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
        'proxyQuantity': proxyQuantity,
        'isFoil': isFoil, // <--- Sauvegarde
      };

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        scryfallId: json['scryfallId'],
        name: json['name'],
        quantity: json['quantity'],
        proxyQuantity: json['proxyQuantity'] ?? 0,
        isFoil: json['isFoil'] ?? false, // <--- Chargement (rétrocompatible)
      );
}

// ... (Le reste de la classe Deck reste inchangé)
class Deck {
  // ... Copiez le reste de la classe Deck telle quelle si besoin, 
  // mais seule la classe DeckCard change ici.
  String id;
  String name;
  List<DeckCard> mainboard;
  List<DeckCard> sideboard;
  String? commanderScryfallId;
  String? commanderSecondaryScryfallId;
  List<String> colors;
  String format;

  Deck({
    required this.id,
    required this.name,
    List<DeckCard>? mainboard,
    List<DeckCard>? sideboard,
    this.commanderScryfallId,
    this.commanderSecondaryScryfallId,
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
        'commanderSecondaryScryfallId': commanderSecondaryScryfallId,
        'colors': colors,
        'format': format,
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'],
        name: json['name'],
        mainboard: (json['mainboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        sideboard: (json['sideboard'] as List).map((i) => DeckCard.fromJson(i)).toList(),
        commanderScryfallId: json['commanderScryfallId'],
        commanderSecondaryScryfallId: json['commanderSecondaryScryfallId'],
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        format: json['format'] ?? 'Standard',
      );
}