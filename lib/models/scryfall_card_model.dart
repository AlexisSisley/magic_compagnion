// Fichier : lib/models/scryfall_card_model.dart
// VERSION CORRIGÉE (Gère les terrains de base et les nulls)

class ScryfallCard {
  final String id;
  final String name;
  final String? printedName;
  final String? manaCost;
  final String imageUrl; // Sera une chaîne vide si non trouvée
  final String rulesText;
  final String typeLine;
  final Map<String, String> legalities;
  final Map<String, dynamic> prices;
  final String lang;
  final List<String> colorIdentity;

  ScryfallCard({
    required this.id,
    required this.name,
    this.printedName,
    this.manaCost,
    required this.imageUrl,
    required this.rulesText,
    required this.typeLine,
    required this.legalities,
    required this.prices,
    required this.lang,
    required this.colorIdentity,
  });

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    String rulesText = '';
    String? manaCost;
    String? printedName;

    if (json['card_faces'] != null &&
        json['card_faces'][0]['image_uris'] != null) {
      final face = json['card_faces'][0];
      imageUrl = face['image_uris']['normal'] ?? ''; // Ajout de ?? ''
      rulesText = face['printed_text'] ?? face['oracle_text'] ?? '';
      manaCost = face['mana_cost'];
      printedName = face['printed_name'];
    } else {
      // --- CORRECTION CLÉ ---
      // Vérifie si 'image_uris' existe ET n'est pas null
      if (json['image_uris'] != null) { 
        // Accède à 'normal' seulement si 'image_uris' n'est pas null
        imageUrl = json['image_uris']['normal'] ?? ''; 
      }
      // S'il n'y a pas d'image_uris, imageUrl reste '' (sans crash)
      // ---
      
      rulesText = json['printed_text'] ?? json['oracle_text'] ?? '';
      manaCost = json['mana_cost'];
      printedName = json['printed_name'];
    }

    final List<String> identity = (json['color_identity'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return ScryfallCard(
      id: json['id'],
      name: json['name'] ?? 'Nom inconnu', // Sécurité
      printedName: printedName,
      manaCost: manaCost,
      imageUrl: imageUrl,
      rulesText: rulesText,
      typeLine: json['type_line'] ?? 'Type inconnu', // Sécurité
      legalities: Map<String, String>.from(json['legalities'] ?? {}), // Sécurité
      prices: Map<String, dynamic>.from(json['prices'] ?? {}), // Sécurité
      lang: json['lang'] ?? 'en',
      colorIdentity: identity,
    );
  }
}