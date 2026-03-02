// Fichier : lib/models/search_filters.dart

class SearchFilters {
  final String? setCode;
  final String? cardType;
  final Set<String> colors;

  final double? minCmc;
  final double? maxCmc;
  final String? rarity;
  final String? keyword;

  // --- NOUVEAU Sprint 9 : Prix max (filtre budget) ---
  final double? maxPrice;

  // --- NOUVEAUX CHAMPS UX ---
  final String sortType; // 'name', 'price', 'cmc', 'type', 'date'
  final bool sortAscending;
  final Set<String> tags; // Filtre par tags utilisateur

  // --- Sprint 12 Feature #9 : Recherche multilingue ---
  final String? searchLanguage; // null = utiliser la preference par defaut

  /// Liste des langues supportees par l'API Scryfall.
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'it', 'name': 'Italiano'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'ja', 'name': '日本語'},
    {'code': 'ko', 'name': '한국어'},
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'zhs', 'name': '简体中文'},
    {'code': 'zht', 'name': '繁體中文'},
  ];

  const SearchFilters({
    this.setCode,
    this.cardType,
    this.colors = const {},
    this.minCmc,
    this.maxCmc,
    this.rarity,
    this.keyword,
    this.maxPrice,
    this.sortType = 'name',
    this.sortAscending = true,
    this.tags = const {},
    this.searchLanguage,
  });

  SearchFilters copyWith({
    String? setCode,
    String? cardType,
    Set<String>? colors,
    double? minCmc,
    double? maxCmc,
    String? rarity,
    String? keyword,
    double? maxPrice,
    bool clearMaxPrice = false,
    String? sortType,
    bool? sortAscending,
    Set<String>? tags,
    String? searchLanguage,
    bool clearSearchLanguage = false,
  }) {
    return SearchFilters(
      setCode: setCode ?? this.setCode,
      cardType: cardType ?? this.cardType,
      colors: colors ?? this.colors,
      minCmc: minCmc ?? this.minCmc,
      maxCmc: maxCmc ?? this.maxCmc,
      rarity: rarity ?? this.rarity,
      keyword: keyword ?? this.keyword,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      sortType: sortType ?? this.sortType,
      sortAscending: sortAscending ?? this.sortAscending,
      tags: tags ?? this.tags,
      searchLanguage: clearSearchLanguage ? null : (searchLanguage ?? this.searchLanguage),
    );
  }
}