class Keyword {
  final String term;
  final String definition;
  final String category;
  final String? example; // <-- AJOUTÉ
  final String? image;   // <-- AJOUTÉ

  Keyword({
    required this.term, 
    required this.definition, 
    required this.category,
    this.example, // <-- AJOUTÉ
    this.image,   // <-- AJOUTÉ
  });

  factory Keyword.fromJson(Map<String, dynamic> json) {
    return Keyword(
      term: json['term'] as String,
      definition: json['definition'] as String,
      category: json['category'] as String? ?? 'Mots-clés',
      example: json['example'] as String?, // <-- AJOUTÉ
      image: json['image'] as String?,     // <-- AJOUTÉ
    );
  }
}