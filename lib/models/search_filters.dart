// Fichier : lib/models/search_filters.dart

class SearchFilters {
  final String? setCode;
  final String? cardType;
  final Set<String> colors;
  
  final double? minCmc;
  final double? maxCmc;
  final String? rarity; 
  final String? keyword;
  
  // --- NOUVEAUX CHAMPS UX ---
  final String sortType; // 'name', 'price', 'cmc', 'type', 'date'
  final bool sortAscending;
  final Set<String> tags; // Filtre par tags utilisateur

  const SearchFilters({
    this.setCode,
    this.cardType,
    this.colors = const {},
    this.minCmc,
    this.maxCmc,
    this.rarity,
    this.keyword,
    this.sortType = 'name',
    this.sortAscending = true,
    this.tags = const {},
  });

  SearchFilters copyWith({
    String? setCode,
    String? cardType,
    Set<String>? colors,
    double? minCmc,
    double? maxCmc,
    String? rarity,
    String? keyword,
    String? sortType,
    bool? sortAscending,
    Set<String>? tags,
  }) {
    return SearchFilters(
      setCode: setCode ?? this.setCode,
      cardType: cardType ?? this.cardType,
      colors: colors ?? this.colors,
      minCmc: minCmc ?? this.minCmc,
      maxCmc: maxCmc ?? this.maxCmc,
      rarity: rarity ?? this.rarity,
      keyword: keyword ?? this.keyword,
      sortType: sortType ?? this.sortType,
      sortAscending: sortAscending ?? this.sortAscending,
      tags: tags ?? this.tags,
    );
  }
}