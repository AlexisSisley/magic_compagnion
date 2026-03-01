// Fichier : lib/models/scryfall_card_model.dart

/// Carte reliee (token, embleme, meld part) depuis le champ `all_parts` de Scryfall.
class RelatedCard {
  final String id;
  final String component; // "token", "meld_part", "meld_result", "combo_piece"
  final String name;
  final String typeLine;
  final String uri;

  const RelatedCard({
    required this.id,
    required this.component,
    required this.name,
    required this.typeLine,
    required this.uri,
  });

  factory RelatedCard.fromJson(Map<String, dynamic> json) {
    return RelatedCard(
      id: json['id'] ?? '',
      component: json['component'] ?? '',
      name: json['name'] ?? '',
      typeLine: json['type_line'] ?? '',
      uri: json['uri'] ?? '',
    );
  }

  bool get isToken => component == 'token';
}

class ScryfallCard {
  final String id;
  final String oracleId;
  final String name;
  final String? printedName;
  final String? manaCost;
  final double? cmc;
  final String imageUrl;
  final String? smallImageUrl;
  final String? artCropUrl;
  final String rulesText;
  final String typeLine;
  final Map<String, String> legalities;
  final Map<String, dynamic> prices;
  final String lang;
  final List<String> colorIdentity;
  
  final String setName;
  final String setCode;
  final String collectorNumber;
  final String rarity; 
  
  // --- NOUVEAU : Liens d'achat ---
  final Map<String, String> purchaseUris;

  // --- NOUVEAU Sprint 9 : Parties liees (tokens, meld, etc.) ---
  final List<RelatedCard> allParts;

  ScryfallCard({
    required this.id,
    required this.oracleId,
    required this.name,
    this.printedName,
    this.manaCost,
    this.cmc,
    required this.imageUrl,
    this.smallImageUrl,
    this.artCropUrl,
    required this.rulesText,
    required this.typeLine,
    required this.legalities,
    required this.prices,
    required this.lang,
    required this.colorIdentity,
    required this.setName,
    required this.setCode,
    required this.collectorNumber,
    required this.rarity, 
    required this.purchaseUris,
    this.allParts = const [],
  });

  factory ScryfallCard.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    String? smallImageUrl;
    String? artCropUrl;
    String rulesText = '';
    String? manaCost;
    String? printedName;
    double? cmc;

    if (json['card_faces'] != null && json['card_faces'][0]['image_uris'] != null) {
      final face = json['card_faces'][0];
      imageUrl = face['image_uris']['normal'] ?? '';
      smallImageUrl = face['image_uris']['small'] ?? '';
      artCropUrl = face['image_uris']['art_crop'] as String?;
      rulesText = face['printed_text'] ?? face['oracle_text'] ?? '';
      manaCost = face['mana_cost'];
      printedName = face['printed_name'];
      cmc = (json['cmc'] as num?)?.toDouble();
    } else {
      if (json['image_uris'] != null) {
        imageUrl = json['image_uris']['normal'] ?? '';
        smallImageUrl = json['image_uris']['small'] ?? '';
        artCropUrl = json['image_uris']['art_crop'] as String?;
      }
      rulesText = json['printed_text'] ?? json['oracle_text'] ?? '';
      manaCost = json['mana_cost'];
      printedName = json['printed_name'];
      cmc = (json['cmc'] as num?)?.toDouble();
    }

    final List<String> identity = (json['color_identity'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
        
    // --- Extraction des liens ---
    final Map<String, String> uris = Map<String, String>.from(json['purchase_uris'] ?? {});

    // --- Extraction des parties liees (tokens, meld, etc.) ---
    final List<RelatedCard> parts = [];
    if (json['all_parts'] != null) {
      for (final part in json['all_parts'] as List) {
        parts.add(RelatedCard.fromJson(part as Map<String, dynamic>));
      }
    }

    return ScryfallCard(
      id: json['id'],
      oracleId: json['oracle_id'] ?? '',
      name: json['name'] ?? 'Nom inconnu',
      printedName: printedName,
      manaCost: manaCost,
      cmc: cmc,
      imageUrl: imageUrl,
      smallImageUrl: smallImageUrl,
      artCropUrl: artCropUrl,
      rulesText: rulesText,
      typeLine: json['type_line'] ?? 'Type inconnu',
      legalities: Map<String, String>.from(json['legalities'] ?? {}),
      prices: Map<String, dynamic>.from(json['prices'] ?? {}),
      lang: json['lang'] ?? 'en',
      colorIdentity: identity,
      setName: json['set_name'] ?? 'Unknown Set',
      setCode: json['set'] ?? '',
      collectorNumber: json['collector_number'] ?? '',
      rarity: json['rarity'] ?? 'common', 
      purchaseUris: uris,
      allParts: parts,
    );
  }
}