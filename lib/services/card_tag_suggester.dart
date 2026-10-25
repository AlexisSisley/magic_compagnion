// Fichier : lib/services/card_tag_suggester.dart

const _protectionWords = [
  'hexproof',
  'shroud',
  'indestructible',
  'protection from',
  'phase out',
  'phases out',
  "can't be countered",
];

bool _hasAny(String text, List<String> patterns) => patterns.any(text.contains);

// Verbes qui font DONNER la protection ; mots entiers pour ne pas matcher
// « has » dans un autre mot.
final RegExp _grantsVerb = RegExp(r'\b(gain|gains|have|has)\b');

// Dégâts chiffrés sur une cible : l'éclair est du removal même sans le motif
// littéral « deals damage to target creature ».
final RegExp _damageToTarget = RegExp(
  r'deals (\d+|x) damage to (any target|target creature|target creature or planeswalker|target permanent|target player or planeswalker)',
);

// « each creature » sans « you control » : « each creature you control » est un
// effet de soutien (Cathars' Crusade), pas un balayage.
final RegExp _eachCreatureAny = RegExp(r'each creature(?! you control)');

// Le sort rend la carte exilée : c'est du clignotement, pas du removal.
final RegExp _blink = RegExp(
  r'return (it|that card|them)[^.\n]*to the battlefield',
);

/// Vrai si une même phrase porte le mot-clé ET le verbe donneur. Le verbe
/// ailleurs dans le texte (« you gain 2 life » à côté d'« Indestructible »)
/// ne suffit pas. Un « ~ has hexproof as long as ... » conditionnel compte
/// comme protection : la carte sert bien à se protéger.
bool _grantsProtection(String text) => text
    .split(RegExp(r'[.\n]'))
    .any(
      (sentence) =>
          _hasAny(sentence, _protectionWords) && _grantsVerb.hasMatch(sentence),
    );

/// Déduit les clés de tags du catalogue par défaut qui conviennent à une carte,
/// depuis sa ligne de type et son texte oracle anglais. Fonction pure.
///
/// Chaque rôle est évalué indépendamment : une carte cumule toutes les clés qui
/// lui correspondent, sans doublon, dans l'ordre de priorité `wipe, removal,
/// blink, ramp, tutor, draw, protection, wincon`. Le premier élément est le
/// futur tag principal. Terrain en face avant : aucune suggestion.
List<String> suggestTagKeys({
  required String typeLine,
  required String oracleText,
}) {
  final type = typeLine.toLowerCase();
  final text = oracleText.toLowerCase();
  // Le type de la face avant décide : un MDFC « Sorcery // Land » est un sort.
  final faces = type.split(' // ');
  final frontType = faces.first;
  // Face arrière terrain d'un sort : son « {T}: Add » ne fait pas du sort du
  // ramp.
  final spellWithLandBack =
      !frontType.contains('land') &&
      faces.skip(1).any((f) => f.contains('land'));

  // Un terrain (créature-terrain comprise) ne reçoit aucune suggestion : son
  // « {T}: Add » ne fait pas du ramp.
  if (frontType.contains('land')) return const [];

  final isBlink =
      _blink.hasMatch(text) &&
      (text.contains('exile target') || text.contains('exile up to'));

  final isWipe =
      _eachCreatureAny.hasMatch(text) ||
      _hasAny(text, const [
        'destroy all',
        'exile all',
        'all creatures get -',
        'return all',
        'deals x damage to each creature',
      ]);

  final isRemoval =
      _hasAny(text, const [
        'destroy target',
        'counter target',
        'return target nonland permanent',
        'deals damage to target creature',
        'deals x damage to target',
        'fights target',
        'target creature gets -',
        'target player sacrifices',
        'each opponent sacrifices',
      ]) ||
      _damageToTarget.hasMatch(text) ||
      (text.contains('exile target') && !_blink.hasMatch(text));

  final isLandSearchRamp =
      text.contains('search your library for') &&
      text.contains('land') &&
      text.contains('onto the battlefield');

  final isRamp =
      (!spellWithLandBack &&
          _hasAny(text, const [
            'add {',
            'add one mana',
            'add two mana',
            'mana of any color',
          ])) ||
      text.contains('additional land') ||
      text.contains('put a land card from your hand onto the battlefield') ||
      isLandSearchRamp;

  // La recherche d'un terrain sur le champ de bataille est du ramp, pas un
  // tuteur.
  final isTutor =
      text.contains('search your library for a') && !isLandSearchRamp;

  final isDraw = _hasAny(text, const [
    'draw a card',
    'draw two cards',
    'draw three cards',
    'draws a card',
    'draw cards',
    'draw x cards',
    'draw that many cards',
  ]);

  // Le mot-clé seul sur une créature ne suffit pas : le sort doit le donner.
  final isProtection = _grantsProtection(text);

  final isWincon = _hasAny(text, const [
    'you win the game',
    'loses the game',
    'each opponent loses',
    'extra combat',
    'infinite',
  ]);

  return [
    if (isWipe) 'wipe',
    if (isRemoval) 'removal',
    if (isBlink) 'blink',
    if (isRamp) 'ramp',
    if (isTutor) 'tutor',
    if (isDraw) 'draw',
    if (isProtection) 'protection',
    if (isWincon) 'wincon',
  ];
}
