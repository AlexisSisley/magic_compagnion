// Fichier : lib/models/search_filters.dart
// VERSION MISE À JOUR : Ajout CMC et Rareté

class SearchFilters {
  final String? setCode;
  final String? cardType;
  final Set<String> colors;
  
  // --- NOUVEAUX FILTRES ---
  final double? minCmc;
  final double? maxCmc;
  final String? rarity; // 'common', 'uncommon', 'rare', 'mythic'

  SearchFilters({
    this.setCode,
    this.cardType,
    this.colors = const {},
    this.minCmc,
    this.maxCmc,
    this.rarity,
  });

  SearchFilters copyWith({
    String? setCode,
    String? cardType,
    Set<String>? colors,
    double? minCmc,
    double? maxCmc,
    String? rarity,
  }) {
    return SearchFilters(
      setCode: setCode ?? this.setCode,
      cardType: cardType ?? this.cardType,
      colors: colors ?? this.colors,
      minCmc: minCmc ?? this.minCmc,
      maxCmc: maxCmc ?? this.maxCmc,
      rarity: rarity ?? this.rarity,
    );
  }
}