// Types partages de l'import Moxfield.
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

/// Tag pose sur une carte dont le tirage n'a pas pu etre identifie avec
/// certitude et qui a ete resolue par son nom seul.
const String kNeedsCheckTag = 'à vérifier';

/// Une ligne d'export de collection, telle que lue dans le fichier.
class CollectionEntry {
  final String name;
  final String? setCode;
  final String? collectorNumber;
  final String? lang;
  final bool isFoil;
  final int quantity;

  const CollectionEntry({
    required this.name,
    required this.quantity,
    this.setCode,
    this.collectorNumber,
    this.lang,
    this.isFoil = false,
  });

  /// Vrai quand CETTE ligne porte une identite de tirage complete.
  ///
  /// `CollectionParseResult.isDegraded` ne dit que si le fichier entier a les
  /// colonnes ; une colonne presente mais vide sur une ligne precise doit
  /// etre detectee ici, ligne par ligne, pour que l'import puisse taguer
  /// `à vérifier` uniquement les cartes qui en ont besoin.
  bool get hasIdentity => setCode != null && collectorNumber != null;
}

/// Ce que le parser a compris du fichier.
class CollectionParseResult {
  final List<CollectionEntry> entries;

  /// Colonnes trouvees, sous leur nom canonique, pour affichage.
  final List<String> recognizedColumns;

  /// Colonnes d'identite absentes (`Edition`, `Collector Number`).
  final List<String> missingIdentityColumns;

  /// Lignes que le parser n'a pas su lire, citees telles quelles.
  final List<String> unreadableLines;

  /// Non nul quand une colonne indispensable manque : l'import ne part pas.
  final String? refusal;

  const CollectionParseResult({
    this.entries = const [],
    this.recognizedColumns = const [],
    this.missingIdentityColumns = const [],
    this.unreadableLines = const [],
    this.refusal,
  });

  /// Vrai quand l'identite du tirage est incomplete : les cartes seront
  /// resolues par leur nom seul, donc sur une edition arbitraire.
  bool get isDegraded => missingIdentityColumns.isNotEmpty;

  /// Nombre de lignes de donnees lues, en-tete exclu.
  int get linesRead => entries.length + unreadableLines.length;
}

/// Ce qu'un import a produit dans la collection.
///
/// Regle 4 : aucune ligne ne disparait en silence. Toute ligne de
/// [CollectionParseResult.entries] est comptee soit dans [imported], soit
/// dans [notIdentified] -- jamais ni l'un ni l'autre. Avec les lignes
/// illisibles du parser (deja comptees en amont, jamais retraitees ici),
/// l'egalite `imported + notIdentified + unreadableLines.length ==
/// linesRead` est l'assertion centrale de la suite de tests.
class CollectionImportResult {
  final int imported;
  final int added;
  final int updated;
  final int tagged;

  /// Nombre de lignes dont aucun tirage n'a pu etre identifie, ni par
  /// edition exacte ni par repli sur le nom seul.
  final int notIdentified;

  final List<String> unreadableLines;
  final List<String> taggedNames;

  /// Noms des lignes comptees dans [notIdentified], dans l'ordre du fichier.
  final List<String> notIdentifiedNames;

  const CollectionImportResult({
    this.imported = 0,
    this.added = 0,
    this.updated = 0,
    this.tagged = 0,
    this.notIdentified = 0,
    this.unreadableLines = const [],
    this.taggedNames = const [],
    this.notIdentifiedNames = const [],
  });
}
