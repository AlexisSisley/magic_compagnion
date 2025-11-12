// Fichier : lib/models/scryfall_card_model.dart
// VERSION CORRIGÉE (Avec 'cmc')

class ScryfallCard {
  final String id;
  final String name;
  final String? printedName;
  final String? manaCost;
  final double? cmc; // <-- CHAMP AJOUTÉ
  final String imageUrl;
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
    this.cmc, // <-- CHAMP AJOUTÉ
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
    double? cmc; // <-- CHAMP AJOUTÉ

    if (json['card_faces'] != null &&
        json['card_faces'][0]['image_uris'] != null) {
      final face = json['card_faces'][0];
      imageUrl = face['image_uris']['normal'] ?? '';
      rulesText = face['printed_text'] ?? face['oracle_text'] ?? '';
      manaCost = face['mana_cost'];
      printedName = face['printed_name'];
      // Le CMC est généralement sur l'objet principal, même pour les recto-verso
      cmc = (json['cmc'] as num?)?.toDouble(); 
    } else {
      if (json['image_uris'] != null) { 
        imageUrl = json['image_uris']['normal'] ?? ''; 
      }
      rulesText = json['printed_text'] ?? json['oracle_text'] ?? '';
      manaCost = json['mana_cost'];
      printedName = json['printed_name'];
      cmc = (json['cmc'] as num?)?.toDouble(); // <-- CHAMP AJOUTÉ
    }

    final List<String> identity = (json['color_identity'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return ScryfallCard(
      id: json['id'],
      name: json['name'] ?? 'Nom inconnu',
      printedName: printedName,
      manaCost: manaCost,
      cmc: cmc, // <-- CHAMP AJOUTÉ
      imageUrl: imageUrl,
      rulesText: rulesText,
      typeLine: json['type_line'] ?? 'Type inconnu',
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      prices: Map<String, dynamic>.from(json['prices'] ?? {}),
      lang: json['lang'] ?? 'en',
      colorIdentity: identity,
    );
  }
}