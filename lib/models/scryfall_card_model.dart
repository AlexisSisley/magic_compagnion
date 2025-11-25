// Fichier : lib/models/scryfall_card_model.dart
// VERSION MISE À JOUR : Ajout du champ 'rarity'

class ScryfallCard {
  final String id;
  final String oracleId;
  final String name;
  final String? printedName;
  final String? manaCost;
  final double? cmc;
  final String imageUrl;
  final String? smallImageUrl;
  final String rulesText;
  final String typeLine;
  final Map<String, String> legalities;
  final Map<String, dynamic> prices;
  final String lang;
  final List<String> colorIdentity;
  
  final String setName;
  final String setCode;
  final String collectorNumber;
  
  // --- NOUVEAU CHAMP ---
  final String rarity; // common, uncommon, rare, mythic, special...

  ScryfallCard({
    required this.id,
    required this.oracleId,
    required this.name,
    this.printedName,
    this.manaCost,
    this.cmc,
    required this.imageUrl,
    this.smallImageUrl,
    required this.rulesText,
    required this.typeLine,
    required this.legalities,
    required this.prices,
    required this.lang,
    required this.colorIdentity,
    required this.setName,
    required this.setCode,
    required this.collectorNumber,
    required this.rarity, // Ajouté au constructeur
  });

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    String? smallImageUrl;
    String rulesText = '';
    String? manaCost;
    String? printedName;
    double? cmc;

    if (json['card_faces'] != null && json['card_faces'][0]['image_uris'] != null) {
      final face = json['card_faces'][0];
      imageUrl = face['image_uris']['normal'] ?? '';
      smallImageUrl = face['image_uris']['small'] ?? '';
      rulesText = face['printed_text'] ?? face['oracle_text'] ?? '';
      manaCost = face['mana_cost'];
      printedName = face['printed_name'];
      cmc = (json['cmc'] as num?)?.toDouble();
    } else {
      if (json['image_uris'] != null) {
        imageUrl = json['image_uris']['normal'] ?? '';
        smallImageUrl = json['image_uris']['small'] ?? '';
      }
      rulesText = json['printed_text'] ?? json['oracle_text'] ?? '';
      manaCost = json['mana_cost'];
      printedName = json['printed_name'];
      cmc = (json['cmc'] as num?)?.toDouble();
    }

    final List<String> identity = (json['color_identity'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return ScryfallCard(
      id: json['id'],
      oracleId: json['oracle_id'] ?? '',
      name: json['name'] ?? 'Nom inconnu',
      printedName: printedName,
      manaCost: manaCost,
      cmc: cmc,
      imageUrl: imageUrl,
      smallImageUrl: smallImageUrl,
      rulesText: rulesText,
      typeLine: json['type_line'] ?? 'Type inconnu',
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      prices: Map<String, dynamic>.from(json['prices'] ?? {}),
      lang: json['lang'] ?? 'en',
      colorIdentity: identity,
      setName: json['set_name'] ?? 'Unknown Set',
      setCode: json['set'] ?? '',
      collectorNumber: json['collector_number'] ?? '',
      // Récupération de la rareté avec valeur par défaut
      rarity: json['rarity'] ?? 'common', 
    );
  }
}