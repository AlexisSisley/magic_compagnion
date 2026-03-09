// Fichier : lib/controllers/deck_stats_controller.dart
// Controller pour DeckStatsTab - extrait la logique de calcul des statistiques.

import 'package:flutter_riverpod/legacy.dart';

import '../models/deck_model.dart';
import '../models/scryfall_card_model.dart';
import '../utils/price_helper.dart';

// --- ETAT IMMUTABLE ---

class DeckStatsState {
  final Map<int, int> manaCurveData;
  final Map<String, int> cardTypeData;
  final Map<String, int> pipCountData;
  final Map<String, int> sourceCountData;
  final Map<String, Map<String, int>> colorByTypeData;
  final double averageCmc;
  final double totalPrice;

  const DeckStatsState({
    this.manaCurveData = const {},
    this.cardTypeData = const {},
    this.pipCountData = const {},
    this.sourceCountData = const {},
    this.colorByTypeData = const {},
    this.averageCmc = 0.0,
    this.totalPrice = 0.0,
  });

  DeckStatsState copyWith({
    Map<int, int>? manaCurveData,
    Map<String, int>? cardTypeData,
    Map<String, int>? pipCountData,
    Map<String, int>? sourceCountData,
    Map<String, Map<String, int>>? colorByTypeData,
    double? averageCmc,
    double? totalPrice,
  }) {
    return DeckStatsState(
      manaCurveData: manaCurveData ?? this.manaCurveData,
      cardTypeData: cardTypeData ?? this.cardTypeData,
      pipCountData: pipCountData ?? this.pipCountData,
      sourceCountData: sourceCountData ?? this.sourceCountData,
      colorByTypeData: colorByTypeData ?? this.colorByTypeData,
      averageCmc: averageCmc ?? this.averageCmc,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}

// --- CONSTANTES ---

/// Couleurs de mana MTG associees a leur code WUBRG + C + M.
const Map<String, int> manaColorValues = {
  'W': 0xFFF0F2C0,
  'U': 0xFF4287f5,
  'B': 0xFF333333,
  'R': 0xFFeb4034,
  'G': 0xFF4caf50,
  'C': 0xFF9e9e9e,
  'M': 0xFFD4AF37,
};

/// Ordre d'affichage des segments de couleur (du bas vers le haut).
const List<String> colorOrder = ['W', 'U', 'B', 'R', 'G', 'C', 'M'];

// --- CONTROLLER (StateNotifier) ---

class DeckStatsController extends StateNotifier<DeckStatsState> {
  DeckStatsController() : super(const DeckStatsState());

  /// Regex pour extraire les pips de mana {W}, {U}, {B}, {R}, {G}.
  static final RegExp _manaPipRegex = RegExp(r'\{([WUBRG])\}');

  /// Lance tous les calculs a partir du mainboard et des donnees Scryfall.
  void calculate(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    final manaCurve = _calculateManaCurve(mainboard, cardData);
    final cardTypes = _calculateCardTypes(mainboard, cardData);
    final pipCount = _calculatePipCount(mainboard, cardData);
    final landSources = _calculateLandSources(mainboard, cardData);
    final colorByType = _calculateColorByType(mainboard, cardData);

    double totalCmc = 0;
    int totalNonLandCards = 0;
    double tempPrice = 0;

    for (final deckCard in mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;
      final double unitPrice = PriceHelper.bestPrice(scryfallCard.prices);
      if (unitPrice > 0) {
        tempPrice += unitPrice * deckCard.quantity;
      }
      if (!scryfallCard.typeLine.toLowerCase().contains('land')) {
        totalCmc += (scryfallCard.cmc ?? 0) * deckCard.quantity;
        totalNonLandCards += deckCard.quantity;
      }
    }

    final avgCmc = totalNonLandCards > 0 ? totalCmc / totalNonLandCards : 0.0;

    state = DeckStatsState(
      manaCurveData: manaCurve,
      cardTypeData: cardTypes,
      pipCountData: pipCount,
      sourceCountData: landSources,
      colorByTypeData: colorByType,
      averageCmc: avgCmc,
      totalPrice: tempPrice,
    );
  }

  // --- CALCULS INTERNES ---

  Map<int, int> _calculateManaCurve(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    Map<int, int> curve = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final deckCard in mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;
      if (scryfallCard.typeLine.toLowerCase().contains('land')) continue;
      int cmc = (scryfallCard.cmc ?? 0).toInt();
      if (cmc >= 7) {
        curve[7] = (curve[7] ?? 0) + deckCard.quantity;
      } else {
        curve[cmc] = (curve[cmc] ?? 0) + deckCard.quantity;
      }
    }
    return curve;
  }

  Map<String, int> _calculateCardTypes(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    Map<String, int> types = {};
    for (final deckCard in mainboard) {
      String type = 'Autres';
      if (deckCard.scryfallId.startsWith('LOCAL:')) {
        type = getPrimaryType(deckCard.name);
      } else {
        final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
        type = scryfallCard != null ? getPrimaryType(scryfallCard.typeLine) : getPrimaryType(deckCard.name);
      }
      types[type] = (types[type] ?? 0) + deckCard.quantity;
    }
    return types;
  }

  Map<String, int> _calculatePipCount(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    Map<String, int> pipCount = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0};
    for (final deckCard in mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;
      if (scryfallCard.typeLine.toLowerCase().contains('land')) continue;
      final manaCost = scryfallCard.manaCost ?? '';
      final matches = _manaPipRegex.allMatches(manaCost);
      for (final match in matches) {
        final pip = match.group(1);
        if (pip != null) {
          pipCount[pip] = (pipCount[pip] ?? 0) + (1 * deckCard.quantity);
        }
      }
    }
    pipCount.removeWhere((key, value) => value == 0);
    return pipCount;
  }

  Map<String, int> _calculateLandSources(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    Map<String, int> sources = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
    for (final deckCard in mainboard) {
      if (deckCard.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
      if (scryfallCard == null) continue;
      if (scryfallCard.typeLine.toLowerCase().contains('land')) {
        if (scryfallCard.colorIdentity.isEmpty) {
          sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
        } else {
          for (var color in scryfallCard.colorIdentity) {
            if (sources.containsKey(color)) {
              sources[color] = (sources[color] ?? 0) + deckCard.quantity;
            }
          }
        }
      } else if (scryfallCard.typeLine.toLowerCase().contains('artifact') &&
          (scryfallCard.name.contains('Signet') ||
              scryfallCard.name.contains('Sol Ring') ||
              scryfallCard.name.contains('Arcane Signet'))) {
        if (scryfallCard.name.contains('Sol Ring')) {
          sources['C'] = (sources['C'] ?? 0) + deckCard.quantity;
        }
      }
    }
    sources.removeWhere((key, value) => value == 0);
    return sources;
  }

  Map<String, Map<String, int>> _calculateColorByType(List<DeckCard> mainboard, List<ScryfallCard> cardData) {
    Map<String, Map<String, int>> data = {};

    for (final deckCard in mainboard) {
      String type = 'Autres';
      List<String> colors = [];

      if (deckCard.scryfallId.startsWith('LOCAL:')) {
        type = getPrimaryType(deckCard.name);
        colors = [];
      } else {
        final scryfallCard = cardData.where((sc) => sc.id == deckCard.scryfallId).firstOrNull;
        if (scryfallCard != null) {
          type = getPrimaryType(scryfallCard.typeLine);
          colors = scryfallCard.colorIdentity;
        } else {
          type = getPrimaryType(deckCard.name);
        }
      }

      // Determination de la categorie de couleur
      String colorKey = 'C';
      if (colors.isEmpty) {
        colorKey = 'C';
      } else if (colors.length > 1) {
        colorKey = 'M';
      } else {
        colorKey = colors.first;
      }

      data.putIfAbsent(type, () => {});
      data[type]![colorKey] = (data[type]![colorKey] ?? 0) + deckCard.quantity;
    }

    // Nettoyage des types vides
    data.removeWhere((key, value) => value.isEmpty);
    return data;
  }

  /// Determine le type principal d'une carte a partir de sa type line.
  /// Expose en static pour les tests et reutilisation.
  static String getPrimaryType(String typeLine) {
    String lowerType = typeLine.toLowerCase();
    if (!lowerType.contains(' — ') &&
        (lowerType.contains('swamp') ||
            lowerType.contains('plains') ||
            lowerType.contains('island') ||
            lowerType.contains('mountain') ||
            lowerType.contains('forest'))) {
      return 'Terrains';
    }
    if (lowerType.contains('creature')) return 'Créatures';
    if (lowerType.contains('planeswalker')) return 'Planeswalkers';
    if (lowerType.contains('land')) return 'Terrains';
    if (lowerType.contains('artifact')) return 'Artefacts';
    if (lowerType.contains('enchantment')) return 'Enchantements';
    if (lowerType.contains('instant')) return 'Instant';
    if (lowerType.contains('sorcery')) return 'Rituels';
    if (lowerType.contains('battle')) return 'Batailles';
    return 'Autres';
  }
}

// --- PROVIDER ---

final deckStatsControllerProvider =
    StateNotifierProvider.autoDispose<DeckStatsController, DeckStatsState>(
  (ref) => DeckStatsController(),
);
