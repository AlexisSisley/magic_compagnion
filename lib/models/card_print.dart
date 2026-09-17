// Types partages de l'identite de tirage.
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

/// Ce qu'on sait d'une carte avant resolution.
class PrintRequest {
  final String name;
  final String? scryfallId;
  final String? setCode;
  final String? collectorNumber;
  final String? lang;

  const PrintRequest({
    required this.name,
    this.scryfallId,
    this.setCode,
    this.collectorNumber,
    this.lang,
  });
}

/// Un tirage identifie sans ambiguite.
class ResolvedPrint {
  final String scryfallId;
  final String oracleId;
  final String setCode;
  final String collectorNumber;
  final String lang;
  final String name;
  final String? printedName;
  final String? printedText;
  final String? imageUri;

  /// Identite de couleur du tirage resolu (ex. `['W', 'U']`), telle que
  /// rendue par Scryfall pour CE tirage precis -- gratuite dans la reponse
  /// batch, et plus juste que toute donnee locale puisqu'elle decrit la
  /// carte reellement resolue plutot qu'une impression "par defaut".
  final List<String> colorIdentity;

  const ResolvedPrint({
    required this.scryfallId,
    required this.oracleId,
    required this.setCode,
    required this.collectorNumber,
    required this.lang,
    required this.name,
    this.printedName,
    this.printedText,
    this.imageUri,
    this.colorIdentity = const [],
  });

  /// Le nom a afficher : le nom imprime quand il existe, sinon le nom oracle.
  String get displayName => printedName ?? name;

  factory ResolvedPrint.fromJson(Map<String, dynamic> json) {
    final imageUris = json['image_uris'] as Map<String, dynamic>?;
    final colorIdentityJson = json['color_identity'] as List<dynamic>?;
    return ResolvedPrint(
      scryfallId: json['id'] as String,
      oracleId: json['oracle_id'] as String? ?? '',
      setCode: json['set'] as String? ?? '',
      collectorNumber: json['collector_number'] as String? ?? '',
      lang: json['lang'] as String? ?? 'en',
      name: json['name'] as String? ?? '',
      printedName: json['printed_name'] as String?,
      printedText: json['printed_text'] as String?,
      imageUri: imageUris?['normal'] as String?,
      colorIdentity:
          colorIdentityJson?.map((e) => e as String).toList() ?? const [],
    );
  }
}

/// Resultat d'une resolution d'editions en lot.
///
/// Un lot peut echouer sans condamner les autres : ce qui a ete resolu est
/// rendu, et ce qui ne l'a pas ete est nomme, avec sa cause. L'appelant decide
/// quoi faire d'un import partiel — il ne peut pas le decider s'il l'ignore.
class EditionResolution {
  /// Les tirages effectivement identifies.
  final List<ResolvedPrint> resolved;

  /// Les requetes que Scryfall a explicitement declarees introuvables
  /// (champ `not_found` de la reponse).
  final List<PrintRequest> notFound;

  /// Les requetes d'un lot qui n'a pas abouti (reseau, 5xx, 429).
  final List<PrintRequest> failed;

  /// Un message par lot en echec, pour le diagnostic.
  final List<String> errors;

  const EditionResolution({
    this.resolved = const [],
    this.notFound = const [],
    this.failed = const [],
    this.errors = const [],
  });

  /// Vrai quand toutes les requetes ont trouve leur tirage.
  bool get isComplete => notFound.isEmpty && failed.isEmpty;
}
