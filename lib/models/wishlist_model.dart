// Fichier : lib/models/wishlist_model.dart

import 'deck_model.dart';

class Wishlist {
  String id;
  String name;
  List<DeckCard> cards;
  DateTime dateCreated;
  String? iconScryfallId; // <--- NOUVEAU : ID de la carte de couverture

  Wishlist({
    required this.id,
    required this.name,
    required this.cards,
    required this.dateCreated,
    this.iconScryfallId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cards': cards.map((c) => c.toJson()).toList(),
    'dateCreated': dateCreated.toIso8601String(),
    'iconScryfallId': iconScryfallId, // <--- Sauvegarde
  };

  factory Wishlist.fromJson(Map<String, dynamic> json) => Wishlist(
    id: json['id'],
    name: json['name'],
    cards: (json['cards'] as List).map((i) => DeckCard.fromJson(i)).toList(),
    dateCreated: DateTime.parse(json['dateCreated'] ?? DateTime.now().toIso8601String()),
    iconScryfallId: json['iconScryfallId'], // <--- Chargement (peut être null)
  );
  
  int get totalCards => cards.fold(0, (sum, item) => sum + item.quantity);
}