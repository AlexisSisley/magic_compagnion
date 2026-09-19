# Import Moxfield — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Importer une collection Moxfield depuis un fichier exporté, et un deck Moxfield depuis son URL, en conservant le tirage exact de chaque carte.

**Architecture:** Deux chemins d'entrée — un parser CSV pur pour la collection, un client HTTP pour les decks — qui convergent tous deux sur `CardResolver.resolveEditions`, la chaîne de résolution livrée le 2026-09-17. L'écriture passe par `upsertCollectionCard` (clé `scryfallId` + `isFoil`) pour la collection et par `DeckService` pour les decks. Les traductions sont enfilées puis drainées sans être attendues.

**Tech Stack:** Flutter / Dart, Riverpod, Drift, Dio, API Scryfall, API Moxfield (`api2.moxfield.com`), `flutter_test` (aucune dépendance de test supplémentaire : Dio mocké par intercepteur, base en `NativeDatabase.memory()`).

**Spec:** `docs/superpowers/specs/2026-09-19-import-moxfield-design.md`

## Global Constraints

- **L'app ne contacte jamais Moxfield pour la collection.** Elle lit un fichier exporté par l'utilisateur. Cette propriété ne doit être contournée par aucune « amélioration ».
- **L'import n'efface jamais rien.** Une carte présente dans l'app et absente du fichier reste intacte.
- **Réimporter deux fois ne change rien.** `upsertCollectionCard` est appelé avec `absoluteQuantity`, jamais `quantityToAdd`.
- **Aucune ligne ne disparaît en silence.** `imported + tagged + unreadable == linesRead`. C'est l'assertion centrale de la suite.
- **Un import dégradé ne se produit jamais sans décision explicite** : le bouton dit « Importer quand même », pas « Importer ».
- Tag des cartes résolues par nom seul : la chaîne exacte est `à vérifier` (constante `kNeedsCheckTag`).
- Langue préférée : `readPreferredLanguage()` de `lib/providers/preferred_language_provider.dart`. Ne jamais relire `glossaryLang` en direct.
- Rate limiting Scryfall : déjà appliqué par `ScryfallApiService`. Ne pas le contourner. Les appels Moxfield passent par une instance Dio distincte (autre hôte, autre quota).
- `flutter_test` uniquement, AUCUNE dépendance nouvelle. Commande : `flutter test <chemin>`.
- Thème : `AppColors`, `AppTextStyles`. Ne pas inventer de style.

## Signatures existantes que ce plan consomme

Relevées dans le code le 2026-09-19, à reprendre telles quelles :

```dart
// lib/data/database/app_database.dart:356
Future<void> upsertCollectionCard({
  required String scryfallId,
  required String cardName,
  int? quantityToAdd,
  int? absoluteQuantity,
  bool isFoil = false,
  List<String>? newTags,
});

// lib/models/card_print.dart:22
class ResolvedPrint {
  final String scryfallId, oracleId, setCode, collectorNumber, lang, name;
  final String? printedName, printedText, imageUri;
  final List<String> colorIdentity;
}

// lib/models/card_print.dart:79
class EditionResolution {
  final List<ResolvedPrint> resolved;
  final List<PrintRequest> notFound;
  final List<PrintRequest> failed;
  final List<String> errors;
  bool get isComplete;
}

// lib/services/card_resolver.dart
Future<EditionResolution> resolveEditions(List<PrintRequest> requests);
Future<void> cachePrintFromJson(Map<String, dynamic> json);

// lib/providers/preferred_language_provider.dart
Future<String> readPreferredLanguage();

// lib/services/translation_worker.dart
Future<int> drain({int maxTasks});
```

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/models/moxfield_import.dart` (créé) | `CollectionEntry`, `CollectionParseResult`, `CollectionImportResult`, `kNeedsCheckTag` | 1 |
| `lib/services/moxfield_collection_parser.dart` (créé) | Parser CSV pur : colonnes, valeurs, invariant de somme | 1 |
| `lib/services/collection_import_service.dart` (créé) | Résolution, fusion idempotente, tag `à vérifier` | 2 |
| `lib/widgets/collection/moxfield_import_sheet.dart` (créé) | Écrans 1 et 2 : explication et vérification | 3 |
| `lib/widgets/collection/moxfield_import_report.dart` (créé) | Écran 3 : bilan | 4 |
| `lib/pages/collections/collection_page.dart:167` | `_importBulk` cesse d'être un stub | 3 |
| `lib/services/moxfield_deck_client.dart` (créé) | Extraction d'identifiant, GET, codes HTTP | 5 |
| `lib/services/moxfield_deck_mapper.dart` (créé) | JSON Moxfield → boards du modèle `Deck` | 6 |
| `lib/controllers/deck_list_controller.dart` | `importDeckFromMoxfieldUrl` | 7 |
| `lib/widgets/decks/deck_import_modal.dart` | Troisième onglet « URL Moxfield » | 7 |
| `test/captures/moxfield_import_captures_test.dart` (créé) | Captures des quatre écrans | 8 |

---

### Task 1: Le parser CSV

Le seul composant réellement neuf. Dart pur, testable sans mock ni base.

**Files:**
- Create: `lib/models/moxfield_import.dart`
- Create: `lib/services/moxfield_collection_parser.dart`
- Test: `test/services/moxfield_collection_parser_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces :
  - `const String kNeedsCheckTag = 'à vérifier';`
  - `class CollectionEntry { final String name; final String? setCode; final String? collectorNumber; final String? lang; final bool isFoil; final int quantity; }`
  - `class CollectionParseResult { final List<CollectionEntry> entries; final List<String> recognizedColumns; final List<String> missingIdentityColumns; final List<String> unreadableLines; final String? refusal; bool get isDegraded; int get linesRead; }`
  - `class MoxfieldCollectionParser { static CollectionParseResult parse(String csv); }`

- [ ] **Step 1: Write the failing test**

Créer `test/services/moxfield_collection_parser_test.dart` :

```dart
// Tests du parser d'export de collection Moxfield.
// Dart pur : aucune dependance Flutter, aucun mock, aucune base.
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/services/moxfield_collection_parser.dart';

const _entete =
    '"Count","Tradelist Count","Name","Edition","Condition","Language","Foil",'
    '"Tags","Last Modified","Collector Number","Alter","Proxy","Purchase Price"';

String _ligne({
  String count = '1',
  String name = 'Sol Ring',
  String edition = 'ltc',
  String language = 'en',
  String foil = '',
  String cn = '284',
}) =>
    '"$count","0","$name","$edition","Near Mint","$language","$foil","",'
    '"2026-09-19","$cn","","",""';

void main() {
  group('Colonnes', () {
    test('un entete Moxfield complet est entierement reconnu', () {
      final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne()}');

      expect(r.refusal, isNull);
      expect(r.isDegraded, isFalse);
      expect(r.missingIdentityColumns, isEmpty);
      expect(r.recognizedColumns,
          containsAll(['Count', 'Name', 'Edition', 'Collector Number', 'Language', 'Foil']));
      expect(r.entries.single.name, 'Sol Ring');
      expect(r.entries.single.setCode, 'ltc');
      expect(r.entries.single.collectorNumber, '284');
    });

    test('la casse et les espaces de l entete sont tolerés', () {
      final r = MoxfieldCollectionParser.parse(
          ' count , NAME , edition , collector number \n1,Sol Ring,ltc,284');

      expect(r.refusal, isNull);
      expect(r.entries.single.setCode, 'ltc');
    });

    test('les colonnes peuvent etre dans n importe quel ordre', () {
      final r = MoxfieldCollectionParser.parse(
          'Name,Edition,Collector Number,Count\nSol Ring,ltc,284,3');

      expect(r.entries.single.quantity, 3);
      expect(r.entries.single.setCode, 'ltc');
    });

    test('Quantity est un alias de Count', () {
      final r = MoxfieldCollectionParser.parse('Quantity,Name\n2,Sol Ring');

      expect(r.refusal, isNull);
      expect(r.entries.single.quantity, 2);
    });

    test('sans colonne Name, l import REFUSE et nomme la colonne', () {
      final r = MoxfieldCollectionParser.parse('Count,Edition\n1,ltc');

      expect(r.refusal, isNotNull);
      expect(r.refusal, contains('Name'));
      expect(r.entries, isEmpty);
    });

    test('sans colonne de quantite, l import REFUSE et nomme la colonne', () {
      final r = MoxfieldCollectionParser.parse('Name,Edition\nSol Ring,ltc');

      expect(r.refusal, isNotNull);
      expect(r.refusal, contains('Count'));
      expect(r.entries, isEmpty);
    });

    test('sans edition ni numero, le mode degrade est signale mais on continue', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\n1,Sol Ring');

      expect(r.refusal, isNull);
      expect(r.isDegraded, isTrue);
      expect(r.missingIdentityColumns, containsAll(['Edition', 'Collector Number']));
      expect(r.entries.single.setCode, isNull);
    });
  });

  group('Valeurs', () {
    test('les marqueurs de foil reconnus valent tous foil', () {
      for (final v in ['foil', 'Foil', 'true', '1', 'yes', 'etched']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(foil: v)}');
        expect(r.entries.single.isFoil, isTrue, reason: 'valeur "$v"');
      }
    });

    test('les marqueurs de non-foil reconnus valent tous non-foil', () {
      for (final v in ['', 'nonFoil', 'normal', 'false', 'none']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(foil: v)}');
        expect(r.entries.single.isFoil, isFalse, reason: 'valeur "$v"');
      }
    });

    test('la langue accepte le code, le nom anglais et le nom francais', () {
      for (final v in ['fr', 'FR', 'French', 'Français']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(language: v)}');
        expect(r.entries.single.lang, 'fr', reason: 'valeur "$v"');
      }
    });

    test('une langue inconnue vaut "pas de langue" et ne perd pas la ligne', () {
      final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(language: 'klingon')}');

      expect(r.entries, hasLength(1));
      expect(r.entries.single.lang, isNull);
    });

    test('un nom contenant une virgule entre guillemets reste entier', () {
      final r = MoxfieldCollectionParser.parse(
          'Count,Name\n1,"Erebos, God of the Dead"');

      expect(r.entries.single.name, 'Erebos, God of the Dead');
    });
  });

  group('Lignes illisibles', () {
    test('une quantite non numerique rend la ligne illisible, jamais devinee', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\nbeaucoup,Sol Ring');

      expect(r.entries, isEmpty);
      expect(r.unreadableLines, hasLength(1));
      expect(r.unreadableLines.single, contains('Sol Ring'));
    });

    test('un nom vide rend la ligne illisible', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\n1,');

      expect(r.entries, isEmpty);
      expect(r.unreadableLines, hasLength(1));
    });

    test('une ligne tronquee est illisible et n interrompt pas le reste', () {
      final r = MoxfieldCollectionParser.parse(
          'Count,Name,Edition\n1,Sol Ring,ltc\n1\n2,Cultivate,m21');

      expect(r.entries, hasLength(2));
      expect(r.unreadableLines, hasLength(1));
    });
  });

  group('Invariant de somme', () {
    test('entrees + illisibles = lignes lues', () {
      final csv = [
        'Count,Name,Edition,Collector Number',
        '1,Sol Ring,ltc,284',
        'beaucoup,Cultivate,m21,177',
        '2,Counterspell,mh2,267',
        '1,,eld,146',
      ].join('\n');

      final r = MoxfieldCollectionParser.parse(csv);

      expect(r.linesRead, 4);
      expect(r.entries.length + r.unreadableLines.length, r.linesRead);
    });

    test('un fichier vide ne leve pas et refuse proprement', () {
      final r = MoxfieldCollectionParser.parse('');

      expect(r.refusal, isNotNull);
      expect(r.entries, isEmpty);
      expect(r.linesRead, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/moxfield_collection_parser_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../moxfield_collection_parser.dart'`.

- [ ] **Step 3: Write the models**

Créer `lib/models/moxfield_import.dart` :

```dart
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
class CollectionImportResult {
  final int imported;
  final int added;
  final int updated;
  final int tagged;
  final List<String> unreadableLines;
  final List<String> taggedNames;

  const CollectionImportResult({
    this.imported = 0,
    this.added = 0,
    this.updated = 0,
    this.tagged = 0,
    this.unreadableLines = const [],
    this.taggedNames = const [],
  });
}
```

- [ ] **Step 4: Write the parser**

Créer `lib/services/moxfield_collection_parser.dart` :

```dart
// Parser d'export de collection Moxfield.
//
// Le format exact n'a pas pu etre verifie sur un fichier reel : les colonnes
// sont donc detectees par leur nom, avec alias, et classees selon ce qu'on perd
// si elles manquent. Se tromper d'en-tete doit produire un message, jamais une
// collection fausse.
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import '../models/moxfield_import.dart';

class MoxfieldCollectionParser {
  static const List<String> _countAliases = ['count', 'quantity', 'qty'];
  static const List<String> _nameAliases = ['name', 'card', 'card name'];
  static const List<String> _editionAliases = ['edition', 'set', 'set code'];
  static const List<String> _cnAliases = ['collector number', 'collectornumber', 'card number'];
  static const List<String> _langAliases = ['language', 'lang'];
  static const List<String> _foilAliases = ['foil', 'finish', 'foiling'];

  static const Set<String> _foilTrue = {'foil', 'true', '1', 'yes', 'etched', 'oui'};

  /// Langues connues de Scryfall, avec leurs noms usuels.
  static const Map<String, String> _langMap = {
    'en': 'en', 'english': 'en', 'anglais': 'en',
    'fr': 'fr', 'french': 'fr', 'français': 'fr', 'francais': 'fr',
    'de': 'de', 'german': 'de', 'allemand': 'de', 'deutsch': 'de',
    'es': 'es', 'spanish': 'es', 'espagnol': 'es', 'español': 'es',
    'it': 'it', 'italian': 'it', 'italien': 'it', 'italiano': 'it',
    'pt': 'pt', 'portuguese': 'pt', 'portugais': 'pt',
    'ja': 'ja', 'japanese': 'ja', 'japonais': 'ja',
    'ko': 'ko', 'korean': 'ko', 'coreen': 'ko',
    'ru': 'ru', 'russian': 'ru', 'russe': 'ru',
    'zhs': 'zhs', 'zht': 'zht', 'ph': 'ph',
  };

  static CollectionParseResult parse(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const CollectionParseResult(
        refusal: 'Fichier vide : aucune ligne à lire.',
      );
    }

    final delimiter = _detectDelimiter(lines.first);
    final header = _parseLine(lines.first, delimiter)
        .map((h) => h.trim().toLowerCase())
        .toList();

    int idx(List<String> aliases) =>
        header.indexWhere((h) => aliases.contains(h));

    final countIdx = idx(_countAliases);
    final nameIdx = idx(_nameAliases);
    final editionIdx = idx(_editionAliases);
    final cnIdx = idx(_cnAliases);
    final langIdx = idx(_langAliases);
    final foilIdx = idx(_foilAliases);

    final manquantes = <String>[
      if (countIdx == -1) 'Count',
      if (nameIdx == -1) 'Name',
    ];
    if (manquantes.isNotEmpty) {
      return CollectionParseResult(
        refusal:
            'Colonne(s) indispensable(s) introuvable(s) : ${manquantes.join(', ')}. '
            'Vérifie que le fichier vient bien de l’export de collection Moxfield.',
      );
    }

    final reconnues = <String>[
      'Count', 'Name',
      if (editionIdx != -1) 'Edition',
      if (cnIdx != -1) 'Collector Number',
      if (langIdx != -1) 'Language',
      if (foilIdx != -1) 'Foil',
    ];
    final identiteManquante = <String>[
      if (editionIdx == -1) 'Edition',
      if (cnIdx == -1) 'Collector Number',
    ];

    final entries = <CollectionEntry>[];
    final illisibles = <String>[];

    String? at(List<String> cols, int i) =>
        (i == -1 || i >= cols.length) ? null : cols[i].trim();

    for (var i = 1; i < lines.length; i++) {
      final raw = lines[i].trim();
      final cols = _parseLine(raw, delimiter);

      final name = at(cols, nameIdx);
      final rawCount = at(cols, countIdx);
      final qty = int.tryParse(rawCount ?? '');

      if (name == null || name.isEmpty || qty == null || qty <= 0) {
        illisibles.add(raw);
        continue;
      }

      final edition = at(cols, editionIdx);
      final cn = at(cols, cnIdx);
      final rawLang = at(cols, langIdx)?.toLowerCase();
      final rawFoil = at(cols, foilIdx)?.toLowerCase();

      entries.add(CollectionEntry(
        name: name,
        quantity: qty,
        setCode: (edition == null || edition.isEmpty) ? null : edition,
        collectorNumber: (cn == null || cn.isEmpty) ? null : cn,
        lang: rawLang == null ? null : _langMap[rawLang],
        isFoil: rawFoil != null && _foilTrue.contains(rawFoil),
      ));
    }

    return CollectionParseResult(
      entries: entries,
      recognizedColumns: reconnues,
      missingIdentityColumns: identiteManquante,
      unreadableLines: illisibles,
    );
  }

  static String _detectDelimiter(String headerLine) =>
      headerLine.contains(';') && !headerLine.contains(',') ? ';' : ',';

  /// Decoupe une ligne CSV en respectant les guillemets.
  static List<String> _parseLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delimiter && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/moxfield_collection_parser_test.dart`
Expected: PASS — 17 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/models/moxfield_import.dart lib/services/moxfield_collection_parser.dart test/services/moxfield_collection_parser_test.dart
git commit -m "feat(import): parser d'export de collection Moxfield"
```

---

### Task 2: Le service d'import de collection

**Files:**
- Create: `lib/services/collection_import_service.dart`
- Test: `test/services/collection_import_service_test.dart`

**Interfaces:**
- Consumes: `CollectionEntry`, `CollectionImportResult`, `kNeedsCheckTag` (Task 1) ; `CardResolver.resolveEditions` ; `AppDatabase.upsertCollectionCard`, `enqueueTranslation` ; `readPreferredLanguage()`.
- Produces : `class CollectionImportService { CollectionImportService({required AppDatabase db, required CardResolver resolver}); Future<CollectionImportResult> import(CollectionParseResult parsed, {required String preferredLang}); }`

- [ ] **Step 1: Write the failing test**

Créer `test/services/collection_import_service_test.dart` :

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/collection_import_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

/// Dio mocke : [handler] rend une Map (200) ou un int (code d'erreur).
Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: ScryfallApiService.baseUrl));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
    final result = handler(options);
    if (result is int) {
      h.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: result),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    h.resolve(Response(requestOptions: options, statusCode: 200, data: result));
  }));
  return dio;
}

Map<String, dynamic> _carte({
  required String id,
  String set = 'ltc',
  String cn = '284',
  String name = 'Sol Ring',
  String lang = 'en',
}) =>
    {
      'id': id,
      'oracle_id': 'oracle-$name',
      'name': name,
      'set': set,
      'collector_number': cn,
      'lang': lang,
      'color_identity': <String>[],
    };

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  CollectionImportService _service(Dio dio) => CollectionImportService(
        db: db,
        resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      );

  test('une carte resolue entre en collection avec son tirage exact', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    final r = await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.scryfallId, 'ltc-284-en');
    expect(rows.single.quantity, 2);
    expect(r.imported, 1);
    expect(r.added, 1);
    expect(r.tagged, 0);
  });

  test('reimporter le meme contenu laisse la collection identique', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });
    const parsed = CollectionParseResult(entries: [
      CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
    ]);

    await _service(dio).import(parsed, preferredLang: 'fr');
    await _service(dio).import(parsed, preferredLang: 'fr');

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.quantity, 2, reason: 'quantite absolue, jamais additionnee');
  });

  test('la quantite du fichier remplace celle de l app', () async {
    await db.upsertCollectionCard(
        scryfallId: 'ltc-284-en', cardName: 'Sol Ring', absoluteQuantity: 9);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 2, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.quantity, 2);
  });

  test('une carte absente du fichier survit a l import', () async {
    await db.upsertCollectionCard(
        scryfallId: 'autre-id', cardName: 'Cultivate', absoluteQuantity: 4);
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.map((r) => r.scryfallId), containsAll(['autre-id', 'ltc-284-en']));
    expect(rows.firstWhere((r) => r.scryfallId == 'autre-id').quantity, 4);
  });

  test('foil et non-foil du meme tirage sont deux lignes distinctes', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
        CollectionEntry(
            name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284', isFoil: true),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isFoil), hasLength(1));
  });

  test('une carte introuvable est ajoutee par son nom et tagee', () async {
    final dio = _mockDio((options) {
      final ids = (options.data as Map)['identifiers'] as List;
      final parNom = ids.any((i) => (i as Map).containsKey('name'));
      return {
        'data': parNom ? [_carte(id: 'nom-seul-id', set: 'xxx', cn: '1')] : <dynamic>[],
        'not_found': parNom ? <dynamic>[] : ids,
      };
    });

    final r = await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'plst', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows, hasLength(1));
    expect(rows.single.tags, contains(kNeedsCheckTag));
    expect(r.tagged, 1);
    expect(r.taggedNames, contains('Sol Ring'));
  });

  test('une carte resolue exactement ne porte PAS le tag', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final rows = await db.getAllCollectionCards();
    expect(rows.single.tags, isNot(contains(kNeedsCheckTag)));
  });

  test('un tirage hors langue preferee enfile une traduction', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-en', lang: 'en')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    final taches = await db.nextTranslationTasks();
    expect(taches, hasLength(1));
    expect(taches.single.lang, 'fr');
  });

  test('un tirage deja dans la langue preferee n enfile rien', () async {
    final dio = _mockDio((_) => {
          'data': [_carte(id: 'ltc-284-fr', lang: 'fr')],
          'not_found': <dynamic>[],
        });

    await _service(dio).import(
      const CollectionParseResult(entries: [
        CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284'),
      ]),
      preferredLang: 'fr',
    );

    expect(await db.nextTranslationTasks(), isEmpty);
  });

  test('les lignes illisibles sont reportees telles quelles', () async {
    final dio = _mockDio((_) => {'data': <dynamic>[], 'not_found': <dynamic>[]});

    final r = await _service(dio).import(
      const CollectionParseResult(
        entries: [],
        unreadableLines: ['beaucoup,Sol Ring'],
      ),
      preferredLang: 'fr',
    );

    expect(r.unreadableLines, ['beaucoup,Sol Ring']);
    expect(r.imported, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/collection_import_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../collection_import_service.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/services/collection_import_service.dart` :

```dart
// Import d'une collection Moxfield deja lue par MoxfieldCollectionParser.
//
// Fusion par tirage : la cle est (scryfallId, isFoil), la quantite du fichier
// REMPLACE celle de l'app, et rien n'est jamais supprime. Ecrire une quantite
// absolue rend l'import idempotent -- reimporter le meme fichier par doute est
// le geste naturel, il ne doit pas doubler la collection.
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import '../models/moxfield_import.dart';
import 'card_resolver.dart';

class CollectionImportService {
  final AppDatabase _db;
  final CardResolver _resolver;

  CollectionImportService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  Future<CollectionImportResult> import(
    CollectionParseResult parsed, {
    required String preferredLang,
  }) async {
    if (parsed.entries.isEmpty) {
      return CollectionImportResult(unreadableLines: parsed.unreadableLines);
    }

    // Temps 1 : resoudre par edition quand on l'a.
    final requetes = parsed.entries
        .map((e) => PrintRequest(
              name: e.name,
              setCode: e.setCode,
              collectorNumber: e.collectorNumber,
            ))
        .toList();
    final resolution = await _resolver.resolveEditions(requetes);

    // Index des tirages resolus par (set, cn) puis par nom, pour rattacher
    // chaque entree du fichier a son tirage.
    final parEdition = <String, ResolvedPrint>{};
    final parNom = <String, ResolvedPrint>{};
    for (final p in resolution.resolved) {
      parEdition['${p.setCode.toLowerCase()}|${p.collectorNumber}'] = p;
      parNom.putIfAbsent(p.name.toLowerCase(), () => p);
    }

    // Temps 2 : les entrees non resolues repassent par leur nom seul.
    final nonResolues = <CollectionEntry>[];
    for (final e in parsed.entries) {
      if (_tirage(e, parEdition, parNom) == null) nonResolues.add(e);
    }
    if (nonResolues.isNotEmpty) {
      final secours = await _resolver.resolveEditions(
        nonResolues.map((e) => PrintRequest(name: e.name)).toList(),
      );
      for (final p in secours.resolved) {
        parNom.putIfAbsent(p.name.toLowerCase(), () => p);
      }
    }

    int imported = 0, added = 0, updated = 0, tagged = 0;
    final tagues = <String>[];

    for (final e in parsed.entries) {
      final exact = _parEdition(e, parEdition);
      final tirage = exact ?? parNom[e.name.toLowerCase()];
      if (tirage == null) continue;

      final existant = await _db.getCollectionCard(tirage.scryfallId, e.isFoil);
      if (existant == null) {
        added++;
      } else {
        updated++;
      }

      await _db.upsertCollectionCard(
        scryfallId: tirage.scryfallId,
        cardName: tirage.name,
        absoluteQuantity: e.quantity,
        isFoil: e.isFoil,
        newTags: exact == null ? const [kNeedsCheckTag] : null,
      );
      imported++;

      if (exact == null) {
        tagged++;
        tagues.add(e.name);
      }

      if (tirage.lang != preferredLang) {
        await _db.enqueueTranslation(
          scryfallId: tirage.scryfallId,
          setCode: tirage.setCode,
          collectorNumber: tirage.collectorNumber,
          lang: preferredLang,
        );
      }
    }

    return CollectionImportResult(
      imported: imported,
      added: added,
      updated: updated,
      tagged: tagged,
      unreadableLines: parsed.unreadableLines,
      taggedNames: tagues,
    );
  }

  ResolvedPrint? _parEdition(CollectionEntry e, Map<String, ResolvedPrint> index) {
    if (e.setCode == null || e.collectorNumber == null) return null;
    return index['${e.setCode!.toLowerCase()}|${e.collectorNumber}'];
  }

  ResolvedPrint? _tirage(
    CollectionEntry e,
    Map<String, ResolvedPrint> parEdition,
    Map<String, ResolvedPrint> parNom,
  ) =>
      _parEdition(e, parEdition) ?? parNom[e.name.toLowerCase()];
}
```

- [ ] **Step 4: Add the missing DAO method**

`getCollectionCard` n'existe pas encore. Ajouter sur `AppDatabase`, à côté de `upsertCollectionCard` :

```dart
  /// Une carte de collection par tirage et finition, ou null.
  Future<DbCollectionCard?> getCollectionCard(String scryfallId, bool isFoil) =>
      (select(collectionCards)
            ..where((c) => c.scryfallId.equals(scryfallId) & c.isFoil.equals(isFoil)))
          .getSingleOrNull();
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/collection_import_service_test.dart test/services/moxfield_collection_parser_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/collection_import_service.dart lib/data/database/app_database.dart test/services/collection_import_service_test.dart
git commit -m "feat(import): fusion idempotente de la collection par tirage"
```

---

### Task 3: Le parcours guidé — explication et vérification

**Porte visuelle.** Écrans 1 et 2 de la maquette validée : https://claude.ai/artifact/AcgKxXZdanZjFJv6ZFKuFj

**Files:**
- Create: `lib/widgets/collection/moxfield_import_sheet.dart`
- Modify: `lib/pages/collections/collection_page.dart:167` (`_importBulk`) et `:319` (libellé du menu)
- Test: `test/widgets/collection/moxfield_import_sheet_test.dart`

**Interfaces:**
- Consumes: `MoxfieldCollectionParser.parse` (Task 1), `CollectionImportService.import` (Task 2).
- Produces: `class MoxfieldImportSheet extends ConsumerStatefulWidget` — feuille modale ouverte par `_importBulk`.

- [ ] **Step 1: Write the failing test**

Créer `test/widgets/collection/moxfield_import_sheet_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/widgets/collection/moxfield_import_sheet.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('l ecran d explication nomme les etapes de l export Moxfield',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet()));
    await tester.pumpAndSettle();

    expect(find.textContaining('moxfield.com'), findsOneWidget);
    expect(find.textContaining('Export'), findsWidgets);
    expect(find.text('Choisir le fichier'), findsOneWidget);
  });

  testWidgets('la verification affiche les colonnes reconnues et le nombre de lignes',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        entries: [CollectionEntry(name: 'Sol Ring', quantity: 1, setCode: 'ltc', collectorNumber: '284')],
        recognizedColumns: ['Count', 'Name', 'Edition', 'Collector Number', 'Language', 'Foil'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('1'), findsWidgets);
    expect(find.text('Edition'), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);
  });

  testWidgets('en mode degrade le bouton dit "Importer quand meme" et les colonnes manquantes sont nommees',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        entries: [CollectionEntry(name: 'Sol Ring', quantity: 1)],
        recognizedColumns: ['Count', 'Name'],
        missingIdentityColumns: ['Edition', 'Collector Number'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Importer quand même'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    expect(find.textContaining('Edition'), findsWidgets);
  });

  testWidgets('un refus affiche le message du parser et aucun bouton d import',
      (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportSheet(
      debugParsed: CollectionParseResult(
        refusal: 'Colonne(s) indispensable(s) introuvable(s) : Name.',
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Name'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    expect(find.text('Importer quand même'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/collection/moxfield_import_sheet_test.dart`
Expected: FAIL — fichier `moxfield_import_sheet.dart` absent.

- [ ] **Step 3: Write the sheet**

Créer `lib/widgets/collection/moxfield_import_sheet.dart`. Le widget porte trois états : explication, vérification, bilan. Le paramètre `debugParsed` permet d'ouvrir directement sur la vérification dans les tests, sans sélecteur de fichier — il est annoté `@visibleForTesting`.

Points non négociables du rendu, tirés de la maquette :
- l'écran d'explication liste **quatre étapes numérotées** citant `moxfield.com`, `Collection`, `More → Export` et le format `CSV` ;
- l'écran de vérification affiche le **nombre de lignes lues** et une puce par colonne reconnue ;
- en mode dégradé, les colonnes manquantes apparaissent en ambre (`AppColors.amber`) et le bouton principal porte le libellé **`Importer quand même`** ;
- un refus affiche le message du parser et **aucun** bouton d'import.

Suivre `AppColors` et `AppTextStyles` ; s'inspirer de la structure de `deck_import_modal.dart` pour la feuille modale.

- [ ] **Step 4: Drainer la file apres l'import**

L'import enfile des traductions (Task 2) mais rien ne les recupere. Apres l'appel a
`CollectionImportService.import`, lancer le worker **sans l'attendre** :

```dart
    unawaited(ref.read(translationWorkerProvider).drain());
```

Importer `dart:async` pour `unawaited`. Le drain ne doit jamais retarder l'affichage du
bilan : l'utilisateur voit son resultat, les traductions arrivent ensuite.

Ajouter le test qui le verrouille, dans le fichier de test de cette tache :

```dart
  testWidgets('apres un import, la file de traduction est drainee', (tester) async {
    // Monter la feuille avec un CollectionImportService double qui enfile une
    // tache, et un TranslationWorker double qui compte ses appels a drain().
    // Apres le tap sur "Importer", drainCalls doit valoir 1.
  });
```

- [ ] **Step 5: Brancher `_importBulk`**

Dans `lib/pages/collections/collection_page.dart`, remplacer le stub :

```dart
  Future<void> _importBulk() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (_) => const MoxfieldImportSheet(),
    );
  }
```

Et le libellé du menu (ligne 319) :

```dart
  const PopupMenuItem(value: 'import', child: Text('Importer depuis Moxfield')),
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/widgets/collection/moxfield_import_sheet_test.dart`
Expected: PASS — 5 tests.

- [ ] **Step 7: Run the whole suite**

Run: `flutter test`
Expected: PASS. Tu modifies une page utilisateur : les tests existants doivent tous passer.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/collection/moxfield_import_sheet.dart lib/pages/collections/collection_page.dart test/widgets/collection/moxfield_import_sheet_test.dart
git commit -m "feat(import): parcours guide d'import de collection Moxfield"
```

---

### Task 4: Le bilan d'import

**Porte visuelle.** Écran 3 de la maquette.

**Files:**
- Create: `lib/widgets/collection/moxfield_import_report.dart`
- Modify: `lib/widgets/collection/moxfield_import_sheet.dart` (afficher le bilan après import)
- Test: `test/widgets/collection/moxfield_import_report_test.dart`

**Interfaces:**
- Consumes: `CollectionImportResult` (Task 1).
- Produces: `class MoxfieldImportReport extends StatelessWidget { const MoxfieldImportReport({required this.result}); final CollectionImportResult result; }`

- [ ] **Step 1: Write the failing test**

Créer `test/widgets/collection/moxfield_import_report_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/widgets/collection/moxfield_import_report.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('le bilan affiche les quatre compteurs', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 1247, added: 1114, updated: 133, tagged: 12,
        taggedNames: ['Sol Ring', 'Chaos Warp'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('1247'), findsWidgets);
    expect(find.textContaining('1114'), findsWidgets);
    expect(find.textContaining('133'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('les cartes tagees sont NOMMEES, pas seulement comptees', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 2, tagged: 2,
        taggedNames: ['Sol Ring', 'Chaos Warp'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sol Ring'), findsOneWidget);
    expect(find.textContaining('Chaos Warp'), findsOneWidget);
  });

  testWidgets('sans carte tagee, le bloc ambre n apparait pas', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(imported: 10, added: 10),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('à vérifier'), findsNothing);
  });

  testWidgets('les lignes illisibles sont citees telles quelles', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 1,
        unreadableLines: ['beaucoup,Sol Ring,ltc,284'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('beaucoup,Sol Ring'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/collection/moxfield_import_report_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3: Write the report widget**

Créer `lib/widgets/collection/moxfield_import_report.dart`. Rendu attendu, d'après la maquette :

- quatre lignes de compteurs : **Cartes importées**, **Ajoutées**, **Quantité mise à jour**, **Tagées à vérifier** — la dernière en `AppColors.amber` ;
- un panneau ambre listant les cartes tagées, avec la raison quand elle est connue, affiché **seulement** si `result.tagged > 0` ;
- un panneau listant les lignes illisibles, affiché seulement si `result.unreadableLines` est non vide ;
- pas de bouton d'action : la feuille se ferme par le bouton de la barre.

Les compteurs utilisent `FontFeature.tabularFigures` pour que les colonnes de chiffres s'alignent.

- [ ] **Step 4: Afficher le bilan après import**

Dans `moxfield_import_sheet.dart`, après l'appel à `CollectionImportService.import`, passer à l'état « bilan » et rendre `MoxfieldImportReport(result: ...)`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widgets/collection/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/collection/moxfield_import_report.dart lib/widgets/collection/moxfield_import_sheet.dart test/widgets/collection/moxfield_import_report_test.dart
git commit -m "feat(import): bilan d'import nommant les cartes tagees"
```

---

### Task 5: Le client Moxfield

**Files:**
- Create: `lib/services/moxfield_deck_client.dart`
- Test: `test/services/moxfield_deck_client_test.dart`

**Interfaces:**
- Consumes: rien (instance Dio propre, hôte distinct de Scryfall).
- Produces :
  - `String? extractPublicId(String url)` — fonction de haut niveau, testable seule.
  - `class MoxfieldException implements Exception { final MoxfieldError kind; final String message; }`
  - `enum MoxfieldError { notPublic, accessDenied, transient, malformedUrl }`
  - `class MoxfieldDeckClient { MoxfieldDeckClient({Dio? dio}); Future<Map<String, dynamic>> fetchDeck(String publicId); }`

- [ ] **Step 1: Write the failing test**

Créer `test/services/moxfield_deck_client_test.dart` :

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/moxfield_deck_client.dart';

Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
    final result = handler(options);
    if (result is int) {
      h.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: result),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    h.resolve(Response(requestOptions: options, statusCode: 200, data: result));
  }));
  return dio;
}

void main() {
  group('extractPublicId', () {
    test('extrait l identifiant d une URL de deck', () {
      expect(extractPublicId('https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA'),
          'f-27i01CpkmBPljy89HQeA');
    });

    test('accepte le sous-domaine www et une barre finale', () {
      expect(extractPublicId('https://www.moxfield.com/decks/abc123/'), 'abc123');
    });

    test('rend null sur une URL Moxfield qui n est pas un deck', () {
      expect(extractPublicId('https://moxfield.com/users/Noruk'), isNull);
    });

    test('rend null sur un autre site', () {
      expect(extractPublicId('https://archidekt.com/decks/12345'), isNull);
    });

    test('rend null sur du texte quelconque', () {
      expect(extractPublicId('bonjour'), isNull);
    });
  });

  group('fetchDeck', () {
    test('rend le JSON du deck sur 200', () async {
      final client = MoxfieldDeckClient(
          dio: _mockDio((_) => {'name': 'Invincible toph', 'boards': {}}));

      final deck = await client.fetchDeck('f-27i01CpkmBPljy89HQeA');

      expect(deck['name'], 'Invincible toph');
    });

    test('un 404 devient notPublic avec un message parlant', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 404));

      expect(
        () => client.fetchDeck('inconnu'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.notPublic)
            .having((e) => e.message, 'message', contains('public'))),
      );
    });

    test('un 403 devient accessDenied et oriente vers l export', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 403));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.accessDenied)
            .having((e) => e.message, 'message', contains('export'))),
      );
    });

    test('un 429 devient transient', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 429));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.transient)),
      );
    });

    test('un 500 devient transient', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 500));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.transient)),
      );
    });

    test('l URL appelee est bien la route v3 des decks', () async {
      late String chemin;
      final client = MoxfieldDeckClient(dio: _mockDio((options) {
        chemin = options.uri.toString();
        return {'name': 'x', 'boards': {}};
      }));

      await client.fetchDeck('abc123');

      expect(chemin, contains('api2.moxfield.com/v3/decks/all/abc123'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/moxfield_deck_client_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/services/moxfield_deck_client.dart` :

```dart
// Client de l'API Moxfield pour l'import de deck par URL.
//
// ATTENTION -- decision assumee : les conditions d'utilisation de Moxfield
// (clause 5) interdisent l'acces automatise sans approbation ecrite. Le
// proprietaire du projet en a ete informe et a decide d'ajouter ce chemin.
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md, section
// "Le cadre juridique, et la decision prise".
//
// Consequence a tenir : l'import de collection par fichier ne doit JAMAIS
// dependre de ce client. Il est le chemin de repli si Moxfield ferme l'acces.

import 'package:dio/dio.dart';

enum MoxfieldError { malformedUrl, notPublic, accessDenied, transient }

class MoxfieldException implements Exception {
  final MoxfieldError kind;
  final String message;
  const MoxfieldException(this.kind, this.message);

  @override
  String toString() => message;
}

final RegExp _deckUrlRegex =
    RegExp(r'^https?://(?:www\.)?moxfield\.com/decks/([A-Za-z0-9_-]+)/?$');

/// Extrait l'identifiant public d'une URL de deck Moxfield, ou null.
String? extractPublicId(String url) =>
    _deckUrlRegex.firstMatch(url.trim())?.group(1);

class MoxfieldDeckClient {
  static const String baseUrl = 'https://api2.moxfield.com';

  final Dio _dio;

  MoxfieldDeckClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'MagicCompanion/1.0',
                'Accept': 'application/json',
              },
            ));

  Future<Map<String, dynamic>> fetchDeck(String publicId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/v3/decks/all/$publicId',
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        throw const MoxfieldException(MoxfieldError.notPublic,
            'Deck introuvable. Vérifie que le deck est public sur Moxfield.');
      }
      if (code == 401 || code == 403) {
        throw const MoxfieldException(MoxfieldError.accessDenied,
            "Moxfield refuse l'accès. Utilise l'export du deck depuis leur site, "
            'puis colle le texte dans l’onglet « Coller du texte ».');
      }
      throw MoxfieldException(MoxfieldError.transient,
          'Moxfield est injoignable pour le moment (${code ?? 'réseau'}). Réessaie plus tard.');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/moxfield_deck_client_test.dart`
Expected: PASS — 11 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/moxfield_deck_client.dart test/services/moxfield_deck_client_test.dart
git commit -m "feat(import): client Moxfield, extraction d'identifiant et codes HTTP distincts"
```

---

### Task 6: La correspondance des boards

**Files:**
- Create: `lib/services/moxfield_deck_mapper.dart`
- Test: `test/services/moxfield_deck_mapper_test.dart`

**Interfaces:**
- Consumes: le JSON rendu par `MoxfieldDeckClient.fetchDeck` (Task 5), `PrintRequest` (existant).
- Produces :
  - `class MoxfieldCardLine { final String scryfallId; final String name; final int quantity; final bool isFoil; final bool isProxy; final String board; }`
  - `class MoxfieldDeckData { final String name; final String format; final List<MoxfieldCardLine> lines; final String? commanderScryfallId; final String? partnerScryfallId; }`
  - `class MoxfieldDeckMapper { static MoxfieldDeckData fromJson(Map<String, dynamic> json); }`

Les valeurs de `board` sont exactement `'mainboard'`, `'sideboard'`, `'considering'`.

- [ ] **Step 1: Write the failing test**

Créer `test/services/moxfield_deck_mapper_test.dart`. Les fixtures reprennent la structure réelle du deck « Invincible toph », relevée le 2026-09-19 :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/moxfield_deck_mapper.dart';

Map<String, dynamic> _carte({
  required String id,
  required String name,
  int quantity = 1,
  bool isFoil = false,
  bool isProxy = false,
  String set = 'tla',
  String cn = '353',
  String lang = 'en',
}) =>
    {
      'quantity': quantity,
      'isFoil': isFoil,
      'isProxy': isProxy,
      'finish': isFoil ? 'foil' : 'nonFoil',
      'card': {
        'scryfall_id': id,
        'name': name,
        'set': set,
        'cn': cn,
        'lang': lang,
      },
    };

Map<String, dynamic> _deck({Map<String, dynamic>? boards}) => {
      'name': 'Invincible toph',
      'format': 'commander',
      'boards': boards ??
          {
            'commanders': {
              'cards': {'a': _carte(id: 'toph-id', name: 'Toph, the First Metalbender')}
            },
            'mainboard': {
              'cards': {
                'b': _carte(id: 'wurmcoil-id', name: 'Wurmcoil Engine', set: 'cm2', cn: '231'),
                'c': _carte(id: 'lattice-id', name: 'Mycosynth Lattice', quantity: 2, isFoil: true),
              }
            },
            'maybeboard': {
              'cards': {'d': _carte(id: 'maybe-id', name: 'Contagion Engine')}
            },
            'sideboard': {'cards': <String, dynamic>{}},
            'attractions': {
              'cards': {'e': _carte(id: 'attr-id', name: 'Attraction')}
            },
          },
    };

void main() {
  test('le nom et le format sont repris', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.name, 'Invincible toph');
    expect(d.format, 'commander');
  });

  test('le commandant est extrait du board commanders', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.commanderScryfallId, 'toph-id');
    expect(d.partnerScryfallId, isNull);
  });

  test('le maybeboard atterrit dans considering', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    final maybe = d.lines.where((l) => l.board == 'considering');
    expect(maybe, hasLength(1));
    expect(maybe.single.name, 'Contagion Engine');
  });

  test('les boards sans equivalent sont ignores silencieusement', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.lines.any((l) => l.name == 'Attraction'), isFalse);
  });

  test('quantite, foil et proxy sont fidelement repris', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    final lattice = d.lines.firstWhere((l) => l.name == 'Mycosynth Lattice');
    expect(lattice.quantity, 2);
    expect(lattice.isFoil, isTrue);
    expect(lattice.isProxy, isFalse);
  });

  test('le scryfall_id est repris tel quel, sans resolution par nom', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.lines.map((l) => l.scryfallId),
        containsAll(['wurmcoil-id', 'lattice-id', 'maybe-id']));
  });

  test('un deck sans commandant ne leve pas', () {
    final d = MoxfieldDeckMapper.fromJson(_deck(boards: {
      'mainboard': {
        'cards': {'b': _carte(id: 'x', name: 'Lightning Bolt')}
      }
    }));

    expect(d.commanderScryfallId, isNull);
    expect(d.lines, hasLength(1));
  });

  test('deux commandants donnent un commandant et un partenaire', () {
    final d = MoxfieldDeckMapper.fromJson(_deck(boards: {
      'commanders': {
        'cards': {
          'a': _carte(id: 'cmd-1', name: 'Commandant A'),
          'b': _carte(id: 'cmd-2', name: 'Commandant B'),
        }
      },
      'mainboard': {'cards': <String, dynamic>{}},
    }));

    expect(d.commanderScryfallId, isNotNull);
    expect(d.partnerScryfallId, isNotNull);
    expect(d.commanderScryfallId, isNot(d.partnerScryfallId));
  });

  test('une carte sans scryfall_id est ignoree plutot que de casser l import', () {
    final d = MoxfieldDeckMapper.fromJson({
      'name': 'x',
      'format': 'commander',
      'boards': {
        'mainboard': {
          'cards': {
            'a': {'quantity': 1, 'card': {'name': 'Sans id'}},
            'b': _carte(id: 'bon-id', name: 'Bonne carte'),
          }
        }
      },
    });

    expect(d.lines, hasLength(1));
    expect(d.lines.single.scryfallId, 'bon-id');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/moxfield_deck_mapper_test.dart`
Expected: FAIL — fichier absent.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/services/moxfield_deck_mapper.dart` :

```dart
// Correspondance entre la structure de deck Moxfield et le modele de l'app.
//
// Structure relevee sur un deck reel le 2026-09-19 :
//   boards { commanders, mainboard, sideboard, maybeboard, attractions, ... }
//   chaque entree : { quantity, isFoil, isProxy, finish, card { scryfall_id,
//                     name, set, cn, lang } }
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

/// Une ligne de deck telle que Moxfield la decrit.
class MoxfieldCardLine {
  final String scryfallId;
  final String name;
  final int quantity;
  final bool isFoil;
  final bool isProxy;

  /// 'mainboard', 'sideboard' ou 'considering'.
  final String board;

  const MoxfieldCardLine({
    required this.scryfallId,
    required this.name,
    required this.quantity,
    required this.board,
    this.isFoil = false,
    this.isProxy = false,
  });
}

class MoxfieldDeckData {
  final String name;
  final String format;
  final List<MoxfieldCardLine> lines;
  final String? commanderScryfallId;
  final String? partnerScryfallId;

  const MoxfieldDeckData({
    required this.name,
    required this.format,
    this.lines = const [],
    this.commanderScryfallId,
    this.partnerScryfallId,
  });
}

class MoxfieldDeckMapper {
  /// Boards Moxfield retenus, et leur equivalent dans le modele Deck.
  /// Les boards absents de cette table (attractions, stickers, planes...) sont
  /// ignores : ils n'ont pas d'equivalent et ne concernent pas les formats geres.
  static const Map<String, String> _boards = {
    'mainboard': 'mainboard',
    'sideboard': 'sideboard',
    'maybeboard': 'considering',
  };

  static MoxfieldDeckData fromJson(Map<String, dynamic> json) {
    final boards = (json['boards'] as Map?)?.cast<String, dynamic>() ?? {};
    final lines = <MoxfieldCardLine>[];

    for (final entry in _boards.entries) {
      final cards = ((boards[entry.key] as Map?)?['cards'] as Map?) ?? {};
      for (final raw in cards.values) {
        final line = _line(raw, entry.value);
        if (line != null) lines.add(line);
      }
    }

    final commandants = ((boards['commanders'] as Map?)?['cards'] as Map?)?.values.toList() ?? [];
    final ids = commandants
        .map((c) => ((c as Map)['card'] as Map?)?['scryfall_id'] as String?)
        .whereType<String>()
        .toList();

    return MoxfieldDeckData(
      name: json['name'] as String? ?? 'Deck importé',
      format: json['format'] as String? ?? 'Commander',
      lines: lines,
      commanderScryfallId: ids.isNotEmpty ? ids.first : null,
      partnerScryfallId: ids.length > 1 ? ids[1] : null,
    );
  }

  static MoxfieldCardLine? _line(dynamic raw, String board) {
    if (raw is! Map) return null;
    final card = raw['card'];
    if (card is! Map) return null;

    final id = card['scryfall_id'] as String?;
    if (id == null || id.isEmpty) return null;

    return MoxfieldCardLine(
      scryfallId: id,
      name: card['name'] as String? ?? '',
      quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
      isFoil: raw['isFoil'] as bool? ?? false,
      isProxy: raw['isProxy'] as bool? ?? false,
      board: board,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/moxfield_deck_mapper_test.dart`
Expected: PASS — 9 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/moxfield_deck_mapper.dart test/services/moxfield_deck_mapper_test.dart
git commit -m "feat(import): correspondance des boards Moxfield, maybeboard vers considering"
```

---

### Task 7: Brancher l'import de deck par URL

**Files:**
- Modify: `lib/controllers/deck_list_controller.dart`
- Modify: `lib/widgets/decks/deck_import_modal.dart`
- Modify: `lib/providers/service_providers.dart`
- Test: `test/controllers/deck_list_moxfield_test.dart`

**Interfaces:**
- Consumes: `extractPublicId`, `MoxfieldDeckClient.fetchDeck`, `MoxfieldException` (Task 5) ; `MoxfieldDeckMapper.fromJson` (Task 6) ; `CardResolver.resolveEditions`.
- Produces: `Future<DeckListActionResult> importDeckFromMoxfieldUrl(String url)` sur `DeckListController`.

- [ ] **Step 1: Write the failing test**

Créer `test/controllers/deck_list_moxfield_test.dart`. Reprendre le helper `_mockDio` de `test/services/card_resolver_test.dart` et le squelette de base en mémoire. Le test central :

Le contrôleur prend deux doubles : un `MoxfieldDeckClient` construit sur un Dio mocké
qui rend le JSON du deck, et un `ScryfallApiService` construit sur un second Dio mocké
qui répond au `POST /cards/collection`. Monte le reste (`DeckService`, `AppDatabase` en
mémoire, `TranslationWorker`) comme le fait déjà `test/controllers/deck_list_controller_test.dart`.

```dart
test('un deck importe par URL porte les tirages exacts de Moxfield', () async {

  final result = await controller.importDeckFromMoxfieldUrl(
      'https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA');

  expect(result.success, isTrue);
  final decks = await deckService.loadDecks();
  final deck = decks.firstWhere((d) => d.name == 'Invincible toph');
  expect(deck.mainboard.map((c) => c.scryfallId), containsAll(['wurmcoil-id', 'lattice-id']));
  expect(deck.commanderScryfallId, 'toph-id');
  expect(deck.considering.map((c) => c.name), contains('Contagion Engine'));
});

test('les identifiants envoyes a Scryfall sont des scryfall_id, jamais des noms', () async {
  late List<dynamic> envoyes;
  // le mock capture options.data['identifiers']
  await controller.importDeckFromMoxfieldUrl('https://moxfield.com/decks/abc');

  expect(envoyes.every((i) => (i as Map).containsKey('id')), isTrue);
  expect(envoyes.any((i) => (i as Map).containsKey('name')), isFalse);
});

test('une URL invalide ne declenche AUCUNE requete', () async {
  int appels = 0;
  // mock qui incremente appels
  final result = await controller.importDeckFromMoxfieldUrl('bonjour');

  expect(result.success, isFalse);
  expect(result.message, contains('URL'));
  expect(appels, 0);
});

test('un deck prive rend un message parlant, pas une trace technique', () async {
  // client mocke qui leve MoxfieldException(notPublic)
  final result = await controller.importDeckFromMoxfieldUrl(
      'https://moxfield.com/decks/prive');

  expect(result.success, isFalse);
  expect(result.message, contains('public'));
  expect(result.message, isNot(contains('DioException')));
});
```

Compléter la construction des doubles en suivant le style de `test/controllers/deck_list_controller_test.dart`, qui monte déjà ce contrôleur.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/deck_list_moxfield_test.dart`
Expected: FAIL — `The method 'importDeckFromMoxfieldUrl' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

Sur `DeckListController`, ajouter :

```dart
  /// Importe un deck depuis une URL Moxfield.
  ///
  /// Chaque carte porte son scryfall_id : la resolution se fait par identifiant
  /// exact, sans heuristique d'appariement par nom.
  Future<DeckListActionResult> importDeckFromMoxfieldUrl(String url) async {
    final publicId = extractPublicId(url);
    if (publicId == null) {
      return const DeckListActionResult(
        success: false,
        message: 'URL Moxfield non reconnue. Attendu : moxfield.com/decks/…',
      );
    }

    state = state.copyWith(isImporting: true, isLoading: true);
    try {
      final json = await _moxfieldClient.fetchDeck(publicId);
      final data = MoxfieldDeckMapper.fromJson(json);

      final requetes = data.lines
          .map((l) => PrintRequest(name: l.name, scryfallId: l.scryfallId))
          .toList();
      final resolution = await _cardResolver.resolveEditions(requetes);

      // Index des tirages resolus par scryfallId : la resolution etant faite
      // par identifiant exact, la correspondance est directe et sans ambiguite
      // -- contrairement a importDeck, aucune cle par nom n'est necessaire.
      final parId = {for (final p in resolution.resolved) p.scryfallId: p};

      DeckCard toDeckCard(MoxfieldCardLine l) => DeckCard(
            scryfallId: parId[l.scryfallId]?.scryfallId ?? 'LOCAL:${l.name}',
            name: l.name,
            quantity: l.quantity,
            proxyQuantity: l.isProxy ? l.quantity : 0,
            isFoil: l.isFoil,
          );

      await _deckService.createNewDeck(data.name);
      final decks = await _deckService.loadDecks();
      final newDeck = decks.firstWhere((d) => d.name == data.name);

      newDeck.format = data.format;
      newDeck.mainboard =
          data.lines.where((l) => l.board == 'mainboard').map(toDeckCard).toList();
      newDeck.sideboard =
          data.lines.where((l) => l.board == 'sideboard').map(toDeckCard).toList();
      newDeck.considering =
          data.lines.where((l) => l.board == 'considering').map(toDeckCard).toList();
      newDeck.commanderScryfallId = data.commanderScryfallId;
      newDeck.commanderSecondaryScryfallId = data.partnerScryfallId;
      newDeck.colors = _sortedColorIdentity(resolution.resolved);

      await _deckService.updateDeck(newDeck);

      // Les traductions enfilees par la resolution partent sans etre attendues,
      // exactement comme dans importDeck (deck_list_controller.dart:338).
      unawaited(_translationWorker.drain());

      return DeckListActionResult(
        success: resolution.isComplete,
        message: resolution.isComplete
            ? 'Deck « ${data.name} » importé depuis Moxfield.'
            : '${data.lines.length - resolution.resolved.length} carte(s) sur '
                '${data.lines.length} n’ont pas pu être identifiées.',
      );
    } on MoxfieldException catch (e) {
      return DeckListActionResult(success: false, message: e.message);
    } finally {
      state = state.copyWith(isImporting: false, isLoading: false);
      await loadDecks();
    }
  }
```

`_sortedColorIdentity` est le tri WUBRG déjà appliqué dans `importDeck`
(`deck_list_controller.dart`, autour de la ligne 305) : **extrais-le en méthode privée
partagée** plutôt que de le recopier, et vérifie qu'`importDeck` reste vert.

Le commandant doit figurer dans le mainboard s'il n'y est pas déjà, comme le fait
`importDeck` — reprends cette logique telle quelle.

- [ ] **Step 4: Ajouter l'onglet « URL Moxfield »**

`deck_import_modal.dart` a deux onglets (« Coller du texte », « Fichier »). En ajouter un troisième avec un champ de saisie d'URL, dont le bouton appelle `importDeckFromMoxfieldUrl`. Le message rendu s'affiche dans le même `SnackBar` que les deux autres onglets — vert si `success`, rouge sinon.

- [ ] **Step 5: Déclarer les providers**

Dans `service_providers.dart`, ajouter `moxfieldDeckClientProvider` en suivant le style des providers existants, et l'injecter dans `deckListControllerProvider`.

- [ ] **Step 6: Run the whole suite**

Run: `flutter test`
Expected: PASS. Tu touches un contrôleur et une modale utilisateur.

- [ ] **Step 7: Commit**

```bash
git add lib/controllers/deck_list_controller.dart lib/widgets/decks/deck_import_modal.dart lib/providers/service_providers.dart test/controllers/deck_list_moxfield_test.dart
git commit -m "feat(import): import de deck par URL Moxfield"
```

---

### Task 8: Les captures visuelles

**Porte bloquante.** Maquette de référence : https://claude.ai/artifact/AcgKxXZdanZjFJv6ZFKuFj

**Files:**
- Create: `test/captures/moxfield_import_captures_test.dart`
- Create: `test/captures/goldens/20_moxfield_explication.png`, `21_moxfield_verification.png`, `22_moxfield_bilan.png`, `23_moxfield_degrade.png`

**Interfaces:**
- Consumes: `MoxfieldImportSheet` (Task 3), `MoxfieldImportReport` (Task 4).
- Produces: quatre PNG à comparer à la maquette.

- [ ] **Step 1: Lire le modèle**

Lire `test/captures/life_counter_captures_test.dart` **en entier** avant d'écrire. Son en-tête documente le tag `capture`, la commande de génération avec `--run-skipped`, et surtout le chargement de vraies polices système sans lequel le binding de test headless ne rend aucun glyphe réel.

- [ ] **Step 2: Écrire le fichier de captures**

Quatre captures, correspondant aux quatre écrans de la maquette :
- `20_moxfield_explication.png` — les quatre étapes de l'export ;
- `21_moxfield_verification.png` — 1 247 lignes, six colonnes reconnues, bouton `Importer` ;
- `22_moxfield_bilan.png` — les quatre compteurs et les cartes tagées nommées ;
- `23_moxfield_degrade.png` — colonnes d'identité manquantes en ambre, bouton `Importer quand même`.

Utiliser les widgets réels, pas des reconstitutions.

- [ ] **Step 3: Générer**

Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/moxfield_import_captures_test.dart`

- [ ] **Step 4: Vérifier que la suite ordinaire les ignore**

Run: `flutter test`
Expected: PASS, les captures skippées.

- [ ] **Step 5: Regarder chaque PNG**

Ouvrir les quatre fichiers et les regarder. Si le texte est du tofu, si une ligne déborde, si un panneau est vide, le dire au lieu de livrer des fichiers que personne n'a regardés.

- [ ] **Step 6: Commit**

```bash
git add test/captures/moxfield_import_captures_test.dart test/captures/goldens/2*.png
git commit -m "test(captures): captures visuelles de l'import Moxfield"
```

---

## Ce que le plan ne couvre pas

- **L'import de deck par fichier** reste inchangé : le TXT Moxfield est déjà lu correctement depuis le 2026-09-17.
- **Le format CSV de deck** continue de perdre les éditions là où le TXT les garde.
- **La liste des decks publics d'un utilisateur** (`v2/decks/search?authorUserNames=`) n'est pas exploitée.
- **La collection par API** est impossible (401) et le restera sans compte authentifié.
