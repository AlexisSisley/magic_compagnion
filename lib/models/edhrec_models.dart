// Fichier : lib/models/edhrec_models.dart
// Modeles de donnees pour l'integration EDHREC Deep (Sprint 11).

/// Carte recommandee par EDHREC avec scores de synergie et inclusion.
class EdhrecCardSuggestion {
  final String name;
  final String sanitized;
  final double synergy; // -1.0 a +1.0
  final int inclusion; // pourcentage (0-100)
  final int numDecks; // nombre de decks utilisant cette carte
  final int potentialDecks; // nombre total de decks analyses
  final double salt; // salt score EDHREC (0.0+, indicateur de frustration)

  const EdhrecCardSuggestion({
    required this.name,
    required this.sanitized,
    required this.synergy,
    required this.inclusion,
    required this.numDecks,
    required this.potentialDecks,
    this.salt = 0.0,
  });

  factory EdhrecCardSuggestion.fromJson(Map<String, dynamic> json) {
    return EdhrecCardSuggestion(
      name: json['name'] as String? ?? '',
      sanitized: json['sanitized'] as String? ?? '',
      synergy: (json['synergy'] as num?)?.toDouble() ?? 0.0,
      inclusion: (json['inclusion'] as num?)?.toInt() ?? 0,
      numDecks: (json['num_decks'] as num?)?.toInt() ?? 0,
      potentialDecks: (json['potential_decks'] as num?)?.toInt() ?? 0,
      salt: (json['salt'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Label de categorie base sur la synergie et l'inclusion.
  /// - "Pick specifique" : haute synergie (>= 0.20)
  /// - "Bonne synergie" : synergie moderee (>= 0.05)
  /// - "Staple generique" : haute inclusion (>= 80%) et faible synergie (< 0.05)
  /// - "Standard" : tout le reste
  String get categoryLabel {
    if (synergy >= 0.20) return 'Pick specifique';
    if (synergy >= 0.05) return 'Bonne synergie';
    if (inclusion >= 80 && synergy < 0.05) return 'Staple generique';
    return 'Standard';
  }
}

/// Theme ou tribu disponible pour un commandant EDHREC.
class EdhrecTheme {
  final String name;
  final String slug;
  final int deckCount;

  const EdhrecTheme({
    required this.name,
    required this.slug,
    required this.deckCount,
  });

  factory EdhrecTheme.fromJson(Map<String, dynamic> json) {
    final href = json['href'] as String? ?? '';
    // href format: "/themes/atraxa-praetors-voice/infect"
    final slug = href.isNotEmpty ? href.split('/').last : '';
    return EdhrecTheme(
      name: json['value'] as String? ?? json['name'] as String? ?? '',
      slug: slug,
      deckCount: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Combo identifie par EDHREC.
class EdhrecCombo {
  final int comboId;
  final String name; // ex: "Vraska + Vorinclex"
  final List<String> cardNames; // noms des cartes du combo
  final List<String> results; // ex: ["Target opponent loses the game"]
  final String colors; // ex: "GWUB"
  final int deckCount; // nombre de decks utilisant ce combo
  final double percentage; // pourcentage d'utilisation
  final int rank; // rang de popularite

  const EdhrecCombo({
    required this.comboId,
    required this.name,
    required this.cardNames,
    required this.results,
    required this.colors,
    required this.deckCount,
    required this.percentage,
    required this.rank,
  });

  /// Parse un combo depuis une section du JSON EDHREC (endpoint combos).
  factory EdhrecCombo.fromJson(Map<String, dynamic> section) {
    final cardViews = section['cardviews'] as List<dynamic>? ?? [];
    final cardNames =
        cardViews.map((c) => (c as Map<String, dynamic>)['name'] as String? ?? '').toList();
    final combo = section['combo'] as Map<String, dynamic>? ?? {};
    final results =
        (combo['results'] as List<dynamic>?)?.map((r) => r.toString()).toList() ?? [];

    return EdhrecCombo(
      comboId: (combo['comboId'] as num?)?.toInt() ?? 0,
      name: section['header'] as String? ?? cardNames.join(' + '),
      cardNames: cardNames,
      results: results,
      colors: combo['colors'] as String? ?? '',
      deckCount: (combo['count'] as num?)?.toInt() ?? 0,
      percentage: (combo['percentage'] as num?)?.toDouble() ?? 0.0,
      rank: (combo['rank'] as num?)?.toInt() ?? 0,
    );
  }

  /// Cree un combo simplifie depuis les combocounts de la page principale.
  factory EdhrecCombo.fromComboCount(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return EdhrecCombo(
      comboId: 0,
      name: name,
      cardNames: name.split(' + '),
      results: const [],
      colors: '',
      deckCount: (json['count'] as num?)?.toInt() ?? 0,
      percentage: 0.0,
      rank: 0,
    );
  }
}

/// Resultat complet de l'analyse EDHREC pour un commandant.
class EdhrecCommanderData {
  final Map<String, List<EdhrecCardSuggestion>> categorizedSuggestions;
  final List<EdhrecTheme> themes;
  final List<EdhrecCombo> topCombos; // Top combos (resume depuis page principale)
  final int totalDecks; // Nombre total de decks analyses

  const EdhrecCommanderData({
    required this.categorizedSuggestions,
    required this.themes,
    required this.topCombos,
    required this.totalDecks,
  });

  static const empty = EdhrecCommanderData(
    categorizedSuggestions: {},
    themes: [],
    topCombos: [],
    totalDecks: 0,
  );

  bool get isEmpty =>
      categorizedSuggestions.isEmpty && themes.isEmpty && topCombos.isEmpty;
}

/// Resultat de l'analyse de synergie d'un deck.
class DeckSynergyReport {
  final double globalScore; // 0-100
  final int cardsWithSynergyData; // Nombre de cartes du deck trouvees dans EDHREC
  final int totalDeckCards; // Nombre total de cartes du deck
  final List<CardSynergyEntry> cardScores; // Score par carte du deck
  final double averageSalt; // Salt score moyen du deck (Sprint 12)

  const DeckSynergyReport({
    required this.globalScore,
    required this.cardsWithSynergyData,
    required this.totalDeckCards,
    required this.cardScores,
    this.averageSalt = 0.0,
  });
}

/// Score de synergie d'une carte individuelle du deck.
class CardSynergyEntry {
  final String cardName;
  final String scryfallId;
  final double synergy; // -1.0 a +1.0
  final int inclusion; // 0-100
  final String categoryLabel; // "Pick specifique", "Staple generique", etc.
  final double salt; // salt score EDHREC (Sprint 12)

  const CardSynergyEntry({
    required this.cardName,
    required this.scryfallId,
    required this.synergy,
    required this.inclusion,
    required this.categoryLabel,
    this.salt = 0.0,
  });
}

/// Combo avec statut de presence dans le deck.
class DeckComboStatus {
  final EdhrecCombo combo;
  final List<String> cardsInDeck; // Cartes du combo presentes dans le deck
  final List<String> cardsMissing; // Cartes du combo manquantes
  final ComboCompleteness completeness; // complete, partial, none

  const DeckComboStatus({
    required this.combo,
    required this.cardsInDeck,
    required this.cardsMissing,
    required this.completeness,
  });
}

/// Niveau de completion d'un combo dans le deck.
enum ComboCompleteness { complete, partial, none }

/// Estimation du power level d'un deck Commander (Sprint 12, US-12.2).
/// Score de 1 a 10 avec 6 facteurs contributifs.
class DeckPowerLevel {
  final int score; // 1-10
  final String label; // "Casual", "Focused", "Optimized", "High Power", "cEDH"
  final Map<String, double> factors; // Facteurs contributifs (chacun sur 10)

  const DeckPowerLevel({
    required this.score,
    required this.label,
    required this.factors,
  });

  /// Retourne le label textuel pour un score donne.
  static String labelForScore(int score) {
    if (score <= 3) return 'Casual';
    if (score <= 5) return 'Focused';
    if (score <= 7) return 'Optimized';
    if (score <= 9) return 'High Power';
    return 'cEDH';
  }
}
