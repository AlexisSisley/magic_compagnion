// Fichier : lib/services/deck_synergy_service.dart
// Service de calcul de synergie et detection de combos EDHREC.
// Extrait de DeckDetailController (Sprint 11/12).
// Fonctions pures sans etat, testables en isolation.

import '../models/deck_model.dart';
import '../models/edhrec_models.dart';

/// Service statique pour l'analyse de synergie et la detection de combos.
class DeckSynergyService {
  /// Genere le rapport de synergie du deck en cross-referencant les cartes
  /// du deck avec les donnees EDHREC.
  /// Retourne null si [commanderScryfallId] est null (deck non-Commander).
  static DeckSynergyReport? generateSynergyReport({
    required EdhrecCommanderData edhrecData,
    required Deck deck,
    required String? commanderScryfallId,
  }) {
    if (commanderScryfallId == null) return null;

    final allDeckCards = [...deck.mainboard, ...deck.sideboard];

    // Construire la map nom -> suggestion depuis toutes les categories EDHREC
    final Map<String, EdhrecCardSuggestion> edhrecByName = {};
    for (final cards in edhrecData.categorizedSuggestions.values) {
      for (final card in cards) {
        edhrecByName[card.name.toLowerCase()] = card;
      }
    }

    // Cross-reference
    final List<CardSynergyEntry> entries = [];
    double totalSalt = 0.0;
    int saltCount = 0;
    for (final deckCard in allDeckCards) {
      final match = edhrecByName[deckCard.name.toLowerCase()];
      if (match != null) {
        entries.add(CardSynergyEntry(
          cardName: deckCard.name,
          scryfallId: deckCard.scryfallId,
          synergy: match.synergy,
          inclusion: match.inclusion,
          categoryLabel: match.categoryLabel,
          salt: match.salt,
        ));
        if (match.salt != 0.0) {
          totalSalt += match.salt;
          saltCount++;
        }
      }
    }

    // Score global : moyenne des synergies normalisee en 0-100
    // synergy de -1 -> 0, synergy de 0 -> 50, synergy de +1 -> 100
    double totalSynergy = 0.0;
    for (final entry in entries) {
      totalSynergy += entry.synergy;
    }
    final avgSynergy = entries.isEmpty ? 0.0 : totalSynergy / entries.length;
    final globalScore = ((avgSynergy + 1.0) / 2.0 * 100).clamp(0.0, 100.0);

    // Salt score moyen (Sprint 12)
    final averageSalt = saltCount > 0 ? totalSalt / saltCount : 0.0;

    // Trier les entries par synergie decroissante
    entries.sort((a, b) => b.synergy.compareTo(a.synergy));

    return DeckSynergyReport(
      globalScore: globalScore,
      cardsWithSynergyData: entries.length,
      totalDeckCards: allDeckCards.length,
      cardScores: entries,
      averageSalt: averageSalt,
    );
  }

  /// Analyse les combos EDHREC et detecte leur presence dans le deck.
  /// Retourne la liste des combos avec leur statut (complete, partial, none),
  /// triee : complets en premier, puis partiels, puis absents.
  static List<DeckComboStatus> detectCombos({
    required List<EdhrecCombo> combos,
    required Deck deck,
  }) {
    final deckCardNames = <String>{
      ...deck.mainboard.map((c) => c.name.toLowerCase()),
      ...deck.sideboard.map((c) => c.name.toLowerCase()),
    };

    final List<DeckComboStatus> results = [];
    for (final combo in combos) {
      final inDeck = <String>[];
      final missing = <String>[];

      for (final cardName in combo.cardNames) {
        if (deckCardNames.contains(cardName.toLowerCase())) {
          inDeck.add(cardName);
        } else {
          missing.add(cardName);
        }
      }

      final completeness = missing.isEmpty
          ? ComboCompleteness.complete
          : inDeck.isNotEmpty
              ? ComboCompleteness.partial
              : ComboCompleteness.none;

      results.add(DeckComboStatus(
        combo: combo,
        cardsInDeck: inDeck,
        cardsMissing: missing,
        completeness: completeness,
      ));
    }

    // Trier : complete en premier, puis partial, puis none ;
    // au sein de chaque groupe, par deckCount decroissant
    results.sort((a, b) {
      final orderA = a.completeness.index;
      final orderB = b.completeness.index;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return b.combo.deckCount.compareTo(a.combo.deckCount);
    });

    return results;
  }
}
