// Fichier : lib/models/search_filters.dart

class SearchFilters {
  final String? setCode;
  final String? cardType;
  final Set<String> colors;

  // Constructeur avec des valeurs par défaut
  SearchFilters({
    this.setCode,
    this.cardType,
    this.colors = const {},
  });

  // Méthode pour copier et mettre à jour (immutable)
  SearchFilters copyWith({
    String? setCode,
    String? cardType,
    Set<String>? colors,
  }) {
    return SearchFilters(
      setCode: setCode ?? this.setCode,
      cardType: cardType ?? this.cardType,
      colors: colors ?? this.colors,
    );
  }
}