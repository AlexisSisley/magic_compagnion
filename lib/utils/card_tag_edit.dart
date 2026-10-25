// Fichier : lib/utils/card_tag_edit.dart
// Opérations pures sur la liste de tags d'une carte (le premier est le
// principal). La feuille d'édition les enchaîne, le contrôleur écrit le résultat.

import '../models/card_tag.dart';
import '../models/deck_model.dart';

/// Ajoute [name] en fin de liste. Un nom du catalogue prend son orthographe ;
/// un doublon (casse près) ou un nom invalide ne change rien.
List<String> addTag(List<String> tags, String name, List<CardTagDef> catalog) {
  final normalized = normalizeTagName(name);
  if (normalized == null) return tags;
  if (tags.any((t) => sameTag(t, normalized))) return tags;
  final known = catalog.where((d) => sameTag(d.name, normalized)).firstOrNull;
  return [...tags, known?.name ?? normalized];
}

List<String> removeTag(List<String> tags, String name) => [
  for (final t in tags)
    if (!sameTag(t, name)) t,
];

/// Déplace [name] en tête : il devient le tag principal.
List<String> makePrimary(List<String> tags, String name) {
  final target = tags.where((t) => sameTag(t, name)).firstOrNull;
  if (target == null) return tags;
  return [target, ...tags.where((t) => !sameTag(t, name))];
}

/// Tags portés par les cartes du deck (les quatre boards) et absents du
/// catalogue, sans doublon à la casse près, triés.
List<String> deckOnlyTags(Deck deck, List<CardTagDef> catalog) {
  final seen = <String>{};
  final out = <String>[];
  for (final board in [
    deck.mainboard,
    deck.sideboard,
    deck.considering,
    deck.wishlist,
  ]) {
    for (final card in board) {
      for (final tag in card.tags) {
        if (catalog.any((d) => sameTag(d.name, tag))) continue;
        if (seen.add(tag.toLowerCase())) out.add(tag);
      }
    }
  }
  out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return out;
}
