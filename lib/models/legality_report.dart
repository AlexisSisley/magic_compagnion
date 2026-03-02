// Fichier : lib/models/legality_report.dart
// Modele de rapport de legalite d'un deck (Sprint 10, US-10.3).

/// Statut de legalite pour un format.
enum LegalityStatus { legal, illegal, unknown }

/// Regles structurelles pour un format de jeu.
class FormatRules {
  final int minMainboard;
  final int maxSideboard;
  final int maxCopies;
  final bool singleton;
  final bool exactMainboard;
  final bool requiresCommander;
  final bool checksColorIdentity;
  final bool hasRestricted;

  const FormatRules({
    required this.minMainboard,
    required this.maxSideboard,
    required this.maxCopies,
    required this.singleton,
    this.exactMainboard = false,
    this.requiresCommander = false,
    this.checksColorIdentity = false,
    this.hasRestricted = false,
  });
}

/// Resultat de legalite d'un deck pour un format donne.
class FormatLegalityResult {
  final String format;
  final LegalityStatus status;
  final List<String> violations;
  final int totalCards;
  final int illegalCards;
  final int bannedCards;
  final int restrictedCards;

  const FormatLegalityResult({
    required this.format,
    required this.status,
    this.violations = const [],
    this.totalCards = 0,
    this.illegalCards = 0,
    this.bannedCards = 0,
    this.restrictedCards = 0,
  });
}

/// Rapport complet de legalite couvrant tous les formats.
class LegalityReport {
  final List<FormatLegalityResult> results;
  final int unresolvedCards;
  final DateTime generatedAt;

  const LegalityReport({
    required this.results,
    this.unresolvedCards = 0,
    required this.generatedAt,
  });

  /// Retourne le resultat pour un format specifique (ou null si absent).
  FormatLegalityResult? getFormat(String format) {
    final lower = format.toLowerCase();
    for (final r in results) {
      if (r.format.toLowerCase() == lower) return r;
    }
    return null;
  }

  /// Nombre de formats legaux.
  int get legalCount => results.where((r) => r.status == LegalityStatus.legal).length;

  /// Nombre de formats illegaux.
  int get illegalCount => results.where((r) => r.status == LegalityStatus.illegal).length;
}
