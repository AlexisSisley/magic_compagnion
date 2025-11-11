// Fichier : lib/models/deck_model.dart

// Représente UNE ligne dans le deck, ex: "4x Sol Ring"
class DeckCard {
  final String scryfallId; // L'ID Scryfall unique, pour l'API
  final String name;       // Le nom, pour l'affichage
  int quantity;            // Le nombre d'exemplaires

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
  });

  // Méthodes pour convertir notre objet en JSON (pour la sauvegarde)
  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
      };

  // Méthode pour créer notre objet depuis un JSON (pour le chargement)
  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
        scryfallId: json['scryfallId'],
        name: json['name'],
        quantity: json['quantity'],
      );
}

// Représente le deck complet
class Deck {
  String id; // Un ID unique pour identifier le deck
  String name; // Ex: "Mon Deck Commander"
  List<DeckCard> mainboard;
  List<DeckCard> sideboard;
  String? commanderScryfallId;

  Deck({
    required this.id,
    required this.name,
    List<DeckCard>? mainboard,
    List<DeckCard>? sideboard,
    this.commanderScryfallId,
  })  : this.mainboard = mainboard ?? [],
        this.sideboard = sideboard ?? [];

  // Méthodes toJson/fromJson pour la sauvegarde
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mainboard': mainboard.map((c) => c.toJson()).toList(),
        'sideboard': sideboard.map((c) => c.toJson()).toList(),
        'commanderScryfallId': commanderScryfallId,
      };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
        id: json['id'],
        name: json['name'],
        mainboard: (json['mainboard'] as List)
            .map((i) => DeckCard.fromJson(i))
            .toList(),
        sideboard: (json['sideboard'] as List)
            .map((i) => DeckCard.fromJson(i))
            .toList(),
        commanderScryfallId: json['commanderScryfallId'],
      );
}