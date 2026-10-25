// Fichier : lib/models/card_tag.dart
// Définition d'un tag de carte et catalogue universel par défaut.

/// Un tag du catalogue universel. [key] vaut nul pour un tag créé par
/// l'utilisateur ; les tags par défaut gardent leur clé même renommés.
class CardTagDef {
  final String? key;
  final String name;
  final int color;

  const CardTagDef({this.key, required this.name, required this.color});

  CardTagDef copyWith({String? name, int? color}) =>
      CardTagDef(key: key, name: name ?? this.name, color: color ?? this.color);

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'color': color};

  factory CardTagDef.fromJson(Map<String, dynamic> json) => CardTagDef(
    key: json['key'] as String?,
    name: json['name'] as String,
    color: json['color'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is CardTagDef &&
      other.key == key &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(key, name, color);

  @override
  String toString() => 'CardTagDef($key, $name, $color)';
}

/// Palette des tags (ARGB) : les huit couleurs des tags par défaut, plus deux.
const List<int> kCardTagPalette = [
  0xFF4CAF50, // vert
  0xFF42A5F5, // bleu
  0xFFEF5350, // rouge
  0xFFAB47BC, // violet
  0xFF26C6DA, // cyan
  0xFFFFCA28, // ambre
  0xFFFF7043, // orange
  0xFFEC407A, // rose
  0xFF8D6E63, // brun
  0xFF9CCC65, // citron vert
];

const List<CardTagDef> kDefaultCardTags = [
  CardTagDef(key: 'ramp', name: 'Ramp', color: 0xFF4CAF50),
  CardTagDef(key: 'draw', name: 'Pioche', color: 0xFF42A5F5),
  CardTagDef(key: 'removal', name: 'Removal', color: 0xFFEF5350),
  CardTagDef(key: 'wipe', name: 'Wipe', color: 0xFFAB47BC),
  CardTagDef(key: 'blink', name: 'Blink', color: 0xFF26C6DA),
  CardTagDef(key: 'protection', name: 'Protection', color: 0xFFFFCA28),
  CardTagDef(key: 'tutor', name: 'Tuteur', color: 0xFFFF7043),
  CardTagDef(key: 'wincon', name: 'Win-con', color: 0xFFEC407A),
];

const int kMaxTagNameLength = 24;

/// Nom normalisé : trim, espaces internes réduits à un. Nul si vide ou de plus
/// de 24 caractères.
String? normalizeTagName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > kMaxTagNameLength) return null;
  return name;
}

/// Égalité de deux noms de tag, insensible à la casse.
bool sameTag(String a, String b) => a.toLowerCase() == b.toLowerCase();

/// Catégories du chantier D qui deviennent un tag par défaut. `lands`,
/// `creatures` et `other` ne disaient pas de rôle : elles ne donnent rien.
const Set<String> _legacyCategoryKeys = {
  'ramp',
  'draw',
  'removal',
  'wipe',
  'protection',
  'tutor',
  'wincon',
};

/// Tags d'une carte d'avant la 1.13, depuis son ancienne catégorie : le libellé
/// par défaut du rôle passe en tête (tag principal), sauf si la carte le porte
/// déjà à la casse près. [locked] ne change pas les tags : il devient
/// `tagsEdited`, que l'appelant pose lui-même.
List<String> legacyCategoryTags(
  String? category,
  bool locked,
  List<String> tags,
) {
  if (category == null || !_legacyCategoryKeys.contains(category)) return tags;
  final label = kDefaultCardTags.firstWhere((t) => t.key == category).name;
  if (tags.any((t) => sameTag(t, label))) return tags;
  return [label, ...tags];
}
