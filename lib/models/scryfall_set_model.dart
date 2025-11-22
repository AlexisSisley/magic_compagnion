// Fichier : lib/models/scryfall_set_model.dart

class ScryfallSet {
  final String id;
  final String code;
  final String name;
  final String setType;      // ex: expansion, core, commander...
  final String? releasedAt;  // ex: "2017-01-20"
  final int cardCount;
  final String? iconSvgUri;  // URL de l'icône SVG
  final String? parentSetCode;

  ScryfallSet({
    required this.id,
    required this.code,
    required this.name,
    required this.setType,
    this.releasedAt,
    required this.cardCount,
    this.iconSvgUri,
    this.parentSetCode,
  });

  factory ScryfallSet.fromJson(Map<String, dynamic> json) {
    return ScryfallSet(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      setType: json['set_type'] ?? 'unknown',
      releasedAt: json['released_at'],
      cardCount: json['card_count'] ?? 0,
      iconSvgUri: json['icon_svg_uri'],
      parentSetCode: json['parent_set_code'],
    );
  }
  
  // Helper pour avoir une date DateTime (utile pour le tri)
  DateTime? get releaseDate {
    if (releasedAt == null) return null;
    try {
      return DateTime.parse(releasedAt!);
    } catch (e) {
      return null;
    }
  }
}