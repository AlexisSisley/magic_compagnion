// Fichier : lib/services/edhrec_service.dart

import 'dart:developer';
import 'package:dio/dio.dart';

import '../models/edhrec_models.dart';
export '../models/edhrec_models.dart';

class EdhrecService {
  final Dio _dio;

  // Caches
  final Map<String, EdhrecCommanderData> _commanderCache = {};
  final Map<String, List<EdhrecCardSuggestion>> _themeCache = {};
  final Map<String, List<EdhrecCombo>> _comboCache = {};

  EdhrecService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://json.edhrec.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': 'MagicCompanion/1.0'},
            ));

  // Correction de la generation du Slug pour EDHRec
  String _formatSlug(String name) {
    // 1. Minuscule
    String slug = name.toLowerCase();

    // 2. Gestion des cartes doubles (ex: "Jace // Jace") -> On garde la face avant
    if (slug.contains('//')) {
      slug = slug.split('//')[0];
    }

    // 3. Enlever tout ce qui n'est pas lettre, chiffre, espace ou tiret
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s\-]'), '');

    // 4. Nettoyer les espaces
    slug = slug.trim().replaceAll(RegExp(r'\s+'), '-');

    return slug;
  }

  /// Mapping des sections EDHRec vers nos titres
  static const _sectionsMap = {
    'High Synergy Cards': 'Haute Synergie',
    'Top Cards': 'Top Cartes',
    'Creatures': 'Creatures',
    'Instants': 'Ephemeres',
    'Sorceries': 'Rituels',
    'Artifacts': 'Artefacts',
    'Enchantments': 'Enchantements',
    'Lands': 'Terrains',
    'Planeswalkers': 'Planeswalkers',
  };

  // ============================================================
  // getCommanderData  (enriched)
  // ============================================================

  Future<EdhrecCommanderData> getCommanderData(String commanderName) async {
    final slug = _formatSlug(commanderName);

    if (_commanderCache.containsKey(slug)) {
      return _commanderCache[slug]!;
    }

    try {
      final response = await _dio.get('/pages/commanders/$slug.json');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {};

        if (!data.containsKey('container')) {
          return EdhrecCommanderData.empty;
        }
        final container = data['container'] as Map<String, dynamic>;
        if (!container.containsKey('json_dict')) {
          const result = EdhrecCommanderData.empty;
          _commanderCache[slug] = result;
          return result;
        }

        final jsonDict = container['json_dict'] as Map<String, dynamic>;

        // --- Suggestions ---
        final cardLists = (jsonDict['cardlists'] as List<dynamic>?) ?? [];
        final Map<String, List<EdhrecCardSuggestion>> categorized = {};

        for (var section in cardLists) {
          final header = section['header'] as String?;
          if (header != null && _sectionsMap.containsKey(header)) {
            final categoryTitle = _sectionsMap[header]!;
            final cards = (section['cardviews'] as List<dynamic>?) ?? [];
            final List<EdhrecCardSuggestion> suggestions = [];
            for (var card in cards) {
              suggestions.add(EdhrecCardSuggestion.fromJson(
                  card as Map<String, dynamic>));
            }
            if (suggestions.isNotEmpty) {
              categorized[categoryTitle] = suggestions;
            }
          }
        }

        // --- Themes ---
        final tagLinks = (jsonDict['taglinks'] as List<dynamic>?) ?? [];
        final List<EdhrecTheme> themes = [];
        for (var tag in tagLinks) {
          final theme = EdhrecTheme.fromJson(tag as Map<String, dynamic>);
          if (theme.deckCount >= 50) {
            themes.add(theme);
          }
        }

        // --- Top combos ---
        final comboCounts = (jsonDict['combocounts'] as List<dynamic>?) ?? [];
        final List<EdhrecCombo> topCombos = [];
        for (var combo in comboCounts) {
          topCombos.add(EdhrecCombo.fromComboCount(
              combo as Map<String, dynamic>));
        }

        // --- Total decks ---
        final totalDecks = (jsonDict['num_decks'] as num?)?.toInt() ?? 0;

        final result = EdhrecCommanderData(
          categorizedSuggestions: categorized,
          themes: themes,
          topCombos: topCombos,
          totalDecks: totalDecks,
        );

        _commanderCache[slug] = result;
        return result;
      } else {
        log('Erreur EDHRec ($slug): ${response.statusCode}', name: 'EdhrecService');
        return EdhrecCommanderData.empty;
      }
    } catch (e) {
      log('Exception EDHRec: $e', name: 'EdhrecService');
      return EdhrecCommanderData.empty;
    }
  }

  // ============================================================
  // getThemeCards
  // ============================================================

  Future<List<EdhrecCardSuggestion>> getThemeCards(
      String commanderName, String themeSlug) async {
    final slug = _formatSlug(commanderName);
    final cacheKey = '$slug/$themeSlug';

    if (_themeCache.containsKey(cacheKey)) {
      return _themeCache[cacheKey]!;
    }

    try {
      final response = await _dio.get('/pages/themes/$slug/$themeSlug.json');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {};

        if (!data.containsKey('container')) return [];
        final container = data['container'] as Map<String, dynamic>;
        if (!container.containsKey('json_dict')) return [];

        final jsonDict = container['json_dict'] as Map<String, dynamic>;
        final cardLists = (jsonDict['cardlists'] as List<dynamic>?) ?? [];

        final List<EdhrecCardSuggestion> cards = [];
        for (var section in cardLists) {
          final cardviews = (section['cardviews'] as List<dynamic>?) ?? [];
          for (var card in cardviews) {
            cards.add(EdhrecCardSuggestion.fromJson(
                card as Map<String, dynamic>));
          }
        }

        _themeCache[cacheKey] = cards;
        return cards;
      } else {
        return [];
      }
    } catch (e) {
      log('Exception EDHRec getThemeCards: $e', name: 'EdhrecService');
      return [];
    }
  }

  // ============================================================
  // getCommanderCombos
  // ============================================================

  Future<List<EdhrecCombo>> getCommanderCombos(String commanderName) async {
    final slug = _formatSlug(commanderName);

    if (_comboCache.containsKey(slug)) {
      return _comboCache[slug]!;
    }

    try {
      final response = await _dio.get('/pages/combos/$slug.json');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {};

        if (!data.containsKey('container')) return [];
        final container = data['container'] as Map<String, dynamic>;
        if (!container.containsKey('json_dict')) return [];

        final jsonDict = container['json_dict'] as Map<String, dynamic>;
        final cardLists = (jsonDict['cardlists'] as List<dynamic>?) ?? [];

        final List<EdhrecCombo> combos = [];
        for (var section in cardLists) {
          combos.add(EdhrecCombo.fromJson(section as Map<String, dynamic>));
        }

        // Sort by deckCount descending
        combos.sort((a, b) => b.deckCount.compareTo(a.deckCount));

        // Limit to 50
        final result = combos.length > 50 ? combos.sublist(0, 50) : combos;

        _comboCache[slug] = result;
        return result;
      } else {
        return [];
      }
    } catch (e) {
      log('Exception EDHRec getCommanderCombos: $e', name: 'EdhrecService');
      return [];
    }
  }

  // ============================================================
  // clearCache
  // ============================================================

  void clearCache() {
    _commanderCache.clear();
    _themeCache.clear();
    _comboCache.clear();
  }

  // ============================================================
  // getRecommendations (retrocompatibilite)
  // ============================================================

  /// Retourne une Map organisee par categories (format legacy)
  Future<Map<String, List<String>>> getRecommendations(String commanderName) async {
    final data = await getCommanderData(commanderName);
    final Map<String, List<String>> result = {};
    for (final entry in data.categorizedSuggestions.entries) {
      result[entry.key] = entry.value.map((c) => c.name).toList();
    }
    return result;
  }
}
