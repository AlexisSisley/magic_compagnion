// Fichier : lib/utils/scryfall_query_builder.dart
// Utilitaire pour construire les requetes Scryfall a partir de filtres.

import '../models/search_filters.dart';

/// Construit la query Scryfall a partir d'un texte et de filtres.
///
/// Cette classe extrait la logique de construction de requetes
/// qui etait auparavant dans CardSearchController._searchCardsApi.
class ScryfallQueryBuilder {
  /// Construit la query finale Scryfall en combinant le texte libre
  /// et les filtres actifs.
  ///
  /// Exemples :
  /// - buildQuery('dragon', SearchFilters(colors: {'R'})) => 'dragon c:R'
  /// - buildQuery('', SearchFilters(setCode: 'mkm', rarity: 'mythic')) => 'e:mkm r:mythic'
  static String buildQuery(String textQuery, SearchFilters filters) {
    final List<String> queryParts = [];

    if (textQuery.isNotEmpty) queryParts.add(textQuery);

    if (filters.setCode != null) {
      queryParts.add('e:${filters.setCode}');
    }
    if (filters.colors.isNotEmpty) {
      queryParts.add('c:${filters.colors.join()}');
    }
    if (filters.cardType != null) {
      queryParts.add('t:${filters.cardType}');
    }
    if (filters.rarity != null) {
      queryParts.add('r:${filters.rarity}');
    }
    if (filters.minCmc != null) {
      queryParts.add('cmc>=${filters.minCmc!.toInt()}');
    }
    if (filters.maxCmc != null) {
      queryParts.add('cmc<=${filters.maxCmc!.toInt()}');
    }
    if (filters.keyword != null) {
      queryParts.add('o:"${filters.keyword!.replaceAll('"', '')}"');
    }

    return queryParts.join(' ');
  }

  /// Determine la valeur 'unique' pour l'API Scryfall.
  /// Si un setCode est present, retourne 'prints' pour voir toutes les editions.
  static String uniqueParam(SearchFilters filters) {
    return filters.setCode != null ? 'prints' : 'cards';
  }

  /// Determine le parametre 'order' pour l'API Scryfall
  /// en fonction de la methode de tri choisie.
  static String orderParam(String sortBy) {
    switch (sortBy) {
      case 'cmc':
        return 'cmc';
      case 'eur':
      case 'price_desc':
      case 'price_asc':
        return 'eur';
      default:
        return 'name';
    }
  }
}
