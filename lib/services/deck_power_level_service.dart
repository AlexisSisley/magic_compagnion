// Fichier : lib/services/deck_power_level_service.dart
// Service d'estimation du power level d'un deck Commander (1-10).
// Extrait de DeckDetailController (Sprint 12, US-12.2).
// Fonctions pures sans etat, testables en isolation.

import '../models/deck_model.dart';
import '../models/edhrec_models.dart';
import '../models/scryfall_card_model.dart';
import 'deck_synergy_service.dart';

/// Service statique pour l'estimation du power level d'un deck Commander.
class DeckPowerLevelService {
  /// Estime le power level d'un deck Commander (1-10) a partir de 6 facteurs.
  /// Retourne null si [commanderScryfallId] est null (deck non-Commander).
  static DeckPowerLevel? estimatePowerLevel({
    required Deck deck,
    required List<ScryfallCard> fullCardData,
    required String? commanderScryfallId,
    EdhrecCommanderData? edhrecData,
  }) {
    if (commanderScryfallId == null) return null;

    if (fullCardData.isEmpty) {
      return const DeckPowerLevel(
        score: 5,
        label: 'Focused',
        factors: {
          'Mana Curve': 5.0,
          'Synergy': 5.0,
          'Combo Potential': 0.0,
          'Interactions': 5.0,
          'Mana Base': 5.0,
          'Card Quality': 5.0,
        },
      );
    }

    // Facteur 1 : Mana Curve (CMC moyen, hors terrains)
    final cmcScore = calculateCmcScore(fullCardData);

    // Facteur 2 : Synergy Score (depuis rapport EDHREC)
    final synergyScore = calculateSynergyScore(
      edhrecData: edhrecData,
      deck: deck,
      commanderScryfallId: commanderScryfallId,
    );

    // Facteur 3 : Combo Potential
    final comboScore = calculateComboScore(
      edhrecData: edhrecData,
      deck: deck,
    );

    // Facteur 4 : Interaction Count (removals, counterspells, protection)
    final interactionScore = calculateInteractionScore(fullCardData);

    // Facteur 5 : Mana Base Quality
    final manaBaseScore = calculateManaBaseScore(fullCardData);

    // Facteur 6 : Card Quality (inclusion EDHREC)
    final cardQualityScore = calculateCardQualityScore(
      edhrecData: edhrecData,
      deck: deck,
      commanderScryfallId: commanderScryfallId,
    );

    // Moyenne ponderee
    final weightedScore = (
      cmcScore * 0.15 +
      synergyScore * 0.15 +
      comboScore * 0.20 +
      interactionScore * 0.20 +
      manaBaseScore * 0.15 +
      cardQualityScore * 0.15
    ).clamp(1.0, 10.0);

    final roundedScore = weightedScore.round().clamp(1, 10);

    return DeckPowerLevel(
      score: roundedScore,
      label: DeckPowerLevel.labelForScore(roundedScore),
      factors: {
        'Mana Curve': cmcScore,
        'Synergy': synergyScore,
        'Combo Potential': comboScore,
        'Interactions': interactionScore,
        'Mana Base': manaBaseScore,
        'Card Quality': cardQualityScore,
      },
    );
  }

  /// Facteur 1 : Score base sur la courbe de mana.
  /// CMC moyen < 2.0 = score 10 (tres agressif), > 4.0 = score 1 (tres lent).
  static double calculateCmcScore(List<ScryfallCard> fullCards) {
    final nonLandCards = fullCards.where(
      (c) => !c.typeLine.toLowerCase().contains('land') && (c.cmc ?? 0) > 0,
    ).toList();
    if (nonLandCards.isEmpty) return 5.0;

    final totalCmc = nonLandCards.fold<double>(0.0, (sum, c) => sum + (c.cmc ?? 0));
    final avgCmc = totalCmc / nonLandCards.length;

    // Mapping lineaire : CMC 2.0 -> score 10, CMC 4.0 -> score 1
    return ((4.0 - avgCmc) / 2.0 * 9.0 + 1.0).clamp(1.0, 10.0);
  }

  /// Facteur 2 : Score de synergie global EDHREC.
  static double calculateSynergyScore({
    required EdhrecCommanderData? edhrecData,
    required Deck deck,
    required String? commanderScryfallId,
  }) {
    if (edhrecData == null) return 5.0;
    final report = DeckSynergyService.generateSynergyReport(
      edhrecData: edhrecData,
      deck: deck,
      commanderScryfallId: commanderScryfallId,
    );
    if (report == null) return 5.0;
    // globalScore est de 0 a 100, on le ramene a 1-10
    return (report.globalScore / 10.0).clamp(1.0, 10.0);
  }

  /// Facteur 3 : Potentiel de combo.
  static double calculateComboScore({
    required EdhrecCommanderData? edhrecData,
    required Deck deck,
  }) {
    if (edhrecData == null || edhrecData.topCombos.isEmpty) return 1.0;
    final combos = DeckSynergyService.detectCombos(
      combos: edhrecData.topCombos,
      deck: deck,
    );
    final completeCount = combos.where((c) => c.completeness == ComboCompleteness.complete).length;
    final partialCount = combos.where((c) => c.completeness == ComboCompleteness.partial).length;
    // Chaque combo complet = 2 points, partiel = 0.5 points
    return (completeCount * 2.0 + partialCount * 0.5).clamp(1.0, 10.0);
  }

  /// Facteur 4 : Score d'interaction (removals, counterspells, protection).
  static double calculateInteractionScore(List<ScryfallCard> fullCards) {
    int interactionCount = 0;
    final interactionPatterns = [
      'destroy target',
      'exile target',
      'counter target',
      'return target',
      'destroy all',
      'exile all',
      '-1/-1',
      '-x/-x',
      'sacrifice',
      'protection from',
      'hexproof',
      'indestructible',
      'deals damage',
      'each opponent',
    ];

    for (final card in fullCards) {
      final rulesLower = card.rulesText.toLowerCase();
      for (final pattern in interactionPatterns) {
        if (rulesLower.contains(pattern)) {
          interactionCount++;
          break; // Compter chaque carte une seule fois
        }
      }
    }

    // 0-5 interactions = score 1-3, 6-15 = score 4-7, 16+ = score 8-10
    if (interactionCount <= 5) return (interactionCount * 0.4 + 1.0).clamp(1.0, 3.0);
    if (interactionCount <= 15) return (interactionCount * 0.3 + 1.0).clamp(4.0, 7.0);
    return (interactionCount * 0.15 + 5.6).clamp(8.0, 10.0);
  }

  /// Facteur 5 : Qualite de la base de mana.
  static double calculateManaBaseScore(List<ScryfallCard> fullCards) {
    final lands = fullCards.where((c) => c.typeLine.toLowerCase().contains('land')).toList();
    if (lands.isEmpty) return 1.0;

    final nonBasicLands = lands.where(
      (c) => !c.typeLine.toLowerCase().contains('basic'),
    ).length;

    final manaRocks = fullCards.where(
      (c) => c.typeLine.toLowerCase().contains('artifact') &&
             c.rulesText.toLowerCase().contains('add') &&
             (c.rulesText.toLowerCase().contains('mana') ||
              c.rulesText.toLowerCase().contains('{') &&
              c.rulesText.toLowerCase().contains('}')),
    ).length;

    // Score base sur % de terrains non-basiques et nombre de mana rocks
    final nonBasicRatio = lands.isEmpty ? 0.0 : nonBasicLands / lands.length;
    final rockBonus = (manaRocks * 0.5).clamp(0.0, 3.0);

    return (nonBasicRatio * 7.0 + rockBonus + 1.0).clamp(1.0, 10.0);
  }

  /// Facteur 6 : Qualite des cartes (basee sur l'inclusion EDHREC).
  static double calculateCardQualityScore({
    required EdhrecCommanderData? edhrecData,
    required Deck deck,
    required String? commanderScryfallId,
  }) {
    if (edhrecData == null) return 5.0;
    final report = DeckSynergyService.generateSynergyReport(
      edhrecData: edhrecData,
      deck: deck,
      commanderScryfallId: commanderScryfallId,
    );
    if (report == null || report.cardScores.isEmpty) return 5.0;

    // Ratio de cartes avec inclusion EDHREC >= 50%
    final highInclusionCount = report.cardScores.where(
      (c) => c.inclusion >= 50,
    ).length;
    final ratio = highInclusionCount / report.cardScores.length;

    return (ratio * 10.0).clamp(1.0, 10.0);
  }
}
