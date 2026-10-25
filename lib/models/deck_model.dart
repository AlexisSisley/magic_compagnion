// Fichier : lib/models/deck_model.dart

import 'card_tag.dart';

class DeckCard {
  final String scryfallId;
  final String name;
  int quantity;
  int proxyQuantity;
  bool isFoil;
  List<String> tags; // <--- NOUVEAU : Liste des tags (ex: "Ramp", "Commander", "Trade")

  /// Vrai dès que l'utilisateur a touché aux tags de la carte, même pour les
  /// vider : aucune suggestion ne doit alors les réécrire.
  bool tagsEdited;

  DeckCard({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    this.proxyQuantity = 0,
    this.isFoil = false,
    this.tags = const [], // Défaut vide
    this.tagsEdited = false,
  });

  /// Tag principal, celui qui fait la section : le premier ; nul sans tag.
  String? get primaryTag => tags.isEmpty ? null : tags.first;

  Map<String, dynamic> toJson() => {
        'scryfallId': scryfallId,
        'name': name,
        'quantity': quantity,
        'proxyQuantity': proxyQuantity,
        'isFoil': isFoil,
        'tags': tags, // <--- Sauvegarde
        'tagsEdited': tagsEdited,
      };

  /// Un JSON d'avant la 1.13 porte `category` / `categoryLocked` : ils
  /// deviennent tags et `tagsEdited` par la même règle que la migration v7.
  factory DeckCard.fromJson(Map<String, dynamic> json) {
    final locked = json['categoryLocked'] as bool? ?? false;
    return DeckCard(
      scryfallId: json['scryfallId'],
      name: json['name'],
      quantity: json['quantity'],
      proxyQuantity: json['proxyQuantity'] ?? 0,
      isFoil: json['isFoil'] ?? false,
      tags: legacyCategoryTags(
        json['category'] as String?,
        locked,
        (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      ),
      tagsEdited: json['tagsEdited'] as bool? ?? locked,
    );
  }
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

  /// Etiquettes libres du deck (ex. « Casual », « cEDH »), distinctes de celles des cartes.
  List<String> tags;

  /// Derniere modification ; nul pour un deck anterieur au suivi de cette date.
  DateTime? updatedAt;

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
    List<String>? tags,
    this.updatedAt,
  })  : mainboard = mainboard ?? [],
        sideboard = sideboard ?? [],
        considering = considering ?? [],
        wishlist = wishlist ?? [],
        colors = colors ?? [],
        tags = tags ?? [];

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
        'tags': tags,
        'updatedAt': updatedAt?.toIso8601String(),
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
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'].toString()),
      );
}