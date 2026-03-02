// Fichier : lib/models/deck_model.dart

class DeckCard {
  final String scryfallId;
  final String name;
  int quantity;
  int proxyQuantity;
  bool isFoil;
  List<String> tags; // <--- NOUVEAU : Liste des tags (ex: "Ramp", "Commander", "Trade")

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    this.proxyQuantity = 0,
    this.isFoil = false,
    this.tags = const [], // Défaut vide
  });

  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
        'proxyQuantity': proxyQuantity,
        'isFoil': isFoil,
        'tags': tags, // <--- Sauvegarde
      };

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        scryfallId: json['scryfallId'],
        name: json['name'],
        quantity: json['quantity'],
        proxyQuantity: json['proxyQuantity'] ?? 0,
        isFoil: json['isFoil'] ?? false,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [], // <--- Chargement sécurisé
      );
}

// La classe Deck reste inchangée, elle utilise DeckCard qui est maintenant mis à jour.
class Deck {
  String id;
  String name;
  List<DeckCard> mainboard;
  List<DeckCard> sideboard;
  List<DeckCard> considering; // <--- NOUVEAU
  List<DeckCard> wishlist;    // <--- NOUVEAU (Cartes trop chères)
  
  String? commanderScryfallId;
  String? commanderSecondaryScryfallId;
  List<String> colors;
  String format;

  Deck({
    required this.id,
    required this.name,
    List<DeckCard>? mainboard,
    List<DeckCard>? sideboard,
    List<DeckCard>? considering,
    List<DeckCard>? wishlist,
    this.commanderScryfallId,
    this.commanderSecondaryScryfallId,
    List<String>? colors,
    this.format = 'Standard',
  })  : mainboard = mainboard ?? [],
        sideboard = sideboard ?? [],
        considering = considering ?? [],
        wishlist = wishlist ?? [],
        colors = colors ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mainboard': mainboard.map((c) => c.toJson()).toList(),
        'sideboard': sideboard.map((c) => c.toJson()).toList(),
        'considering': considering.map((c) => c.toJson()).toList(),
        'wishlist': wishlist.map((c) => c.toJson()).toList(),
        'commanderScryfallId': commanderScryfallId,
        'commanderSecondaryScryfallId': commanderSecondaryScryfallId,
        'colors': colors,
        'format': format,
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'],
        name: json['name'],
        mainboard: (json['mainboard'] as List? ?? []).map((i) => DeckCard.fromJson(i)).toList(),
        sideboard: (json['sideboard'] as List? ?? []).map((i) => DeckCard.fromJson(i)).toList(),
        considering: (json['considering'] as List? ?? []).map((i) => DeckCard.fromJson(i)).toList(),
        wishlist: (json['wishlist'] as List? ?? []).map((i) => DeckCard.fromJson(i)).toList(),
        commanderScryfallId: json['commanderScryfallId'],
        commanderSecondaryScryfallId: json['commanderSecondaryScryfallId'],
        colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
        format: json['format'] ?? 'Standard',
      );
}