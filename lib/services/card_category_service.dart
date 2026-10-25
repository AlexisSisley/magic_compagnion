// Fichier : lib/services/card_category_service.dart

import '../models/card_category.dart';

bool _hasAny(String text, List<String> patterns) => patterns.any(text.contains);

// Verbes qui font DONNER la protection ; mots entiers pour ne pas matcher
// « has » dans un autre mot.
final RegExp _grantsVerb = RegExp(r'\b(gain|gains|have|has)\b');

/// Déduit la catégorie de jeu d'une carte depuis sa ligne de type et son texte
/// oracle anglais. Fonction pure. Les règles sont ordonnées : la première qui
/// correspond gagne.
CardCategory classifyCard({
  required String typeLine,
  required String oracleText,
}) {
  final type = typeLine.toLowerCase();
  final text = oracleText.toLowerCase();
  final isCreature = type.contains('creature');

  // Terrain d'abord : un terrain qui produit du mana n'est pas du ramp. Un
  // terrain-créature part directement en créatures, sinon son rappel
  // « {T}: Add {G} » le ferait passer pour du ramp.
  if (type.contains('land')) {
    return isCreature ? CardCategory.creatures : CardCategory.lands;
  }

  if (_hasAny(text, const [
    'destroy all',
    'exile all',
    'each creature',
    'all creatures get -',
    'return all',
    'deals x damage to each creature',
  ])) {
    return CardCategory.wipe;
  }

  if (_hasAny(text, const [
    'destroy target',
    'exile target',
    'counter target',
    'return target nonland permanent',
    'deals damage to target creature',
    'deals x damage to target',
    'fights target',
    'target creature gets -',
    'target player sacrifices',
    'each opponent sacrifices',
  ])) {
    return CardCategory.removal;
  }

  final isRamp =
      _hasAny(text, const [
        'add {',
        'add one mana',
        'add two mana',
        'mana of any color',
      ]) ||
      (text.contains('search your library for') &&
          text.contains('land') &&
          text.contains('onto the battlefield'));
  if (isRamp) return CardCategory.ramp;

  if (text.contains('search your library for a')) return CardCategory.tutor;

  if (_hasAny(text, const [
    'draw a card',
    'draw two cards',
    'draw three cards',
    'draws a card',
    'draw cards',
    'draw x cards',
  ])) {
    return CardCategory.draw;
  }

  // Le mot-clé seul sur une créature ne suffit pas : le sort doit le donner.
  if (_hasAny(text, const [
        'hexproof',
        'indestructible',
        'protection from',
        'phase out',
        'phases out',
        "can't be countered",
      ]) &&
      _grantsVerb.hasMatch(text)) {
    return CardCategory.protection;
  }

  if (_hasAny(text, const [
    'you win the game',
    'loses the game',
    'each opponent loses',
    'extra combat',
    'infinite',
  ])) {
    return CardCategory.wincon;
  }

  if (isCreature) return CardCategory.creatures;
  return CardCategory.other;
}
