# Identité de tirage et langue d'affichage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** L'app stocke le tirage réellement possédé (édition + langue) et affiche la carte dans la langue préférée quand une traduction existe, sans jamais fausser le prix.

**Architecture:** Un service `CardResolver` devient le point de passage unique de toute résolution de carte. Il travaille en deux temps : un batch `POST /cards/collection` qui fixe l'édition (le batch Scryfall ignore le paramètre `lang`), puis un `GET /cards/{set}/{cn}/{lang}` unitaire qui récupère la traduction. Les traductions sont mises en cache dans Drift et chargées en tâche de fond par un worker alimenté par une file persistante, pour que l'import rende la main immédiatement.

**Tech Stack:** Flutter / Dart, Riverpod, Drift (sqlite), Dio, API Scryfall, `flutter_test` (pas de mockito : Dio est mocké par intercepteur, la base par `NativeDatabase.memory()`).

**Spec:** `docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md`

## Global Constraints

- **Le `scryfallId` stocké n'est jamais réécrit par la projection d'affichage.** C'est l'identité du carton possédé. Toute tâche qui écrit dans `deck_cards.scryfallId` ou `collection_cards.scryfallId` hors import explicite est un bug.
- **Le prix se calcule toujours sur le `scryfallId` possédé**, jamais sur la traduction affichée.
- **Un 404 sur une traduction est une réponse, pas une erreur** : on l'enregistre dans `print_translation_absent` et on ne redemande plus jamais ce couple `(oracleId, lang)`.
- **Un nom de carte tient sur une ligne** dans les listes : troncature avec ellipse, hauteur de ligne constante.
- **Jamais de spinner sur un nom de carte** : le résolveur rend toujours quelque chose immédiatement.
- Langue préférée = `SharedPreferences.getString('glossaryLang')`, défaut `'fr'` (valeur existante, lue aujourd'hui dans `lib/controllers/card_search_controller.dart:394`).
- Rate limit Scryfall : 10 req/s, déjà appliqué par `ScryfallApiService._enforceRateLimit()`. Ne pas le contourner.
- Conventions de test du projet : `flutter_test`, Dio mocké par `InterceptorsWrapper` (voir `test/services/scryfall_api_service_test.dart`), base Drift via `AppDatabase(NativeDatabase.memory())` (voir `test/data/app_database_test.dart`). N'ajouter aucune dépendance de test.
- Commande de test : `flutter test <chemin>`.

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/services/deck_format_service.dart` | Parsing decklist — porte désormais set/cn/finish | 1 |
| `lib/services/scryfall_api_service.dart` | Client HTTP — sait demander une langue | 2 |
| `lib/data/database/app_database.dart` | Schéma v4 + DAO cache/file | 3 |
| `lib/models/card_print.dart` (créé) | `PrintRequest`, `ResolvedPrint` — types partagés | 4 |
| `lib/services/card_resolver.dart` (créé) | Résolution en deux temps + cache | 4 |
| `lib/services/translation_worker.dart` (créé) | Drain de la file, backoff | 5 |
| `lib/services/collection_service.dart` | Import : passe par le résolveur | 6 |
| `lib/controllers/card_detail_controller.dart` | OCR : capte la langue imprimée | 7 |
| `lib/providers/card_display_provider.dart` (créé) | Projection oracleId + langue → affichage | 8 |
| `lib/widgets/decks/deck_card_title.dart` | `DeckCardTile` — troncature une ligne | 8 |
| `lib/services/print_backfill_service.dart` (créé) | Reprise des tirages existants | 9 |
| `lib/providers/preferred_language_provider.dart` (créé) | Langue préférée + déclencheur de backfill | 10 |
| `lib/widgets/cards/versions_selector_sheet.dart` | Choix du tirage, toutes langues | 9 |

---

### Task 1: Le parser garde l'édition

Aujourd'hui `_cleanCardName()` retire `(LTC) 284` de la ligne avant de la rendre. C'est la perte d'information d'origine.

**Files:**
- Modify: `lib/services/deck_format_service.dart`
- Test: `test/services/deck_format_service_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `DecklistEntry` gagne trois champs optionnels — `String? setCode`, `String? collectorNumber`, `bool isFoil` (défaut `false`). Les champs existants `name`, `quantity`, `section` ne changent ni de nom ni de type.

- [ ] **Step 1: Write the failing test**

Ajouter dans `test/services/deck_format_service_test.dart` :

```dart
group('DeckFormatService - identité de tirage', () {
  test('une ligne Moxfield conserve set, numéro et foil', () {
    final result = DeckFormatService.parseDecklistText('1 Sol Ring (LTC) 284 *F*');

    expect(result.mainboard, hasLength(1));
    final entry = result.mainboard.first;
    expect(entry.name, 'Sol Ring');
    expect(entry.quantity, 1);
    expect(entry.setCode, 'LTC');
    expect(entry.collectorNumber, '284');
    expect(entry.isFoil, isTrue);
  });

  test('une ligne sans édition laisse les champs nuls', () {
    final result = DeckFormatService.parseDecklistText('3 Lightning Bolt');

    final entry = result.mainboard.first;
    expect(entry.name, 'Lightning Bolt');
    expect(entry.quantity, 3);
    expect(entry.setCode, isNull);
    expect(entry.collectorNumber, isNull);
    expect(entry.isFoil, isFalse);
  });

  test('le numéro de collection peut porter un suffixe de lettre', () {
    final result = DeckFormatService.parseDecklistText('1 Brainstorm (MH2) 42a');

    expect(result.mainboard.first.setCode, 'MH2');
    expect(result.mainboard.first.collectorNumber, '42a');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/deck_format_service_test.dart`
Expected: FAIL — `The getter 'setCode' isn't defined for the class 'DecklistEntry'`.

- [ ] **Step 3: Write minimal implementation**

Dans `lib/services/deck_format_service.dart`, remplacer la classe `DecklistEntry` par :

```dart
/// Entree individuelle d'une decklist parsee.
class DecklistEntry {
  final String name;
  final int quantity;
  final String section; // 'mainboard', 'sideboard', 'commander'

  /// Code d'edition lu sur la ligne (ex: 'LTC'). Null si absent.
  final String? setCode;

  /// Numero de collection lu sur la ligne (ex: '284'). Null si absent.
  final String? collectorNumber;

  /// Marqueur foil Moxfield/MTGO (`*F*`).
  final bool isFoil;

  const DecklistEntry({
    required this.name,
    required this.quantity,
    required this.section,
    this.setCode,
    this.collectorNumber,
    this.isFoil = false,
  });
}
```

Toujours dans le même fichier, ajouter à côté de `_cardLineRegex` :

```dart
  /// Capture `(SET) 284` ou `[SET] 284` en fin de nom, numero optionnellement suffixe.
  static final RegExp _printRegex =
      RegExp(r'[\(\[]([A-Za-z0-9]{2,6})[\)\]]\s*([0-9]{1,4}[a-z]?)?', caseSensitive: false);

  /// Capture le marqueur foil MTGO/Moxfield.
  static final RegExp _foilRegex = RegExp(r'\*F\*', caseSensitive: false);
```

Puis, dans `parseDecklistText`, remplacer la ligne

```dart
      String name = _cleanCardName(match.group(2)!);
```

par :

```dart
      final String rawName = match.group(2)!;
      final printMatch = _printRegex.firstMatch(rawName);
      final String? setCode = printMatch?.group(1)?.toUpperCase();
      final String? collectorNumber = printMatch?.group(2);
      final bool isFoil = _foilRegex.hasMatch(rawName);
      String name = _cleanCardName(rawName);
```

Enfin, propager les trois champs dans les trois `DecklistEntry(...)` du `switch` qui suit. Les trois appels deviennent, à la section près :

```dart
          mainboard.add(DecklistEntry(
            name: name,
            quantity: qty,
            section: 'mainboard',
            setCode: setCode,
            collectorNumber: collectorNumber,
            isFoil: isFoil,
          ));
```

(pour la branche `sideboard`, même bloc avec `section: 'sideboard'` ajouté à `sideboard`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/deck_format_service_test.dart`
Expected: PASS, y compris les tests existants du fichier — `_cleanCardName` n'a pas changé de comportement, on lit simplement la ligne brute avant de la nettoyer.

- [ ] **Step 5: Commit**

```bash
git add lib/services/deck_format_service.dart test/services/deck_format_service_test.dart
git commit -m "feat(import): conserver edition, numero et foil a la lecture d'une decklist"
```

---

### Task 2: Le client sait demander une langue

**Files:**
- Modify: `lib/services/scryfall_api_service.dart`
- Test: `test/services/scryfall_api_service_test.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `Future<Map<String, dynamic>> getCardBySetAndNumber(String setCode, String collectorNumber, {String? lang})`. Le paramètre est nommé et optionnel : tous les appels existants compilent sans modification.

- [ ] **Step 1: Write the failing test**

Ajouter dans `test/services/scryfall_api_service_test.dart` :

```dart
group('ScryfallApiService - langue', () {
  test('sans lang, la route reste /cards/{set}/{cn}', () async {
    late String capturedPath;
    final dio = _createMockDio((options) {
      capturedPath = options.path;
      return {'id': 'en-id', 'lang': 'en'};
    });

    await ScryfallApiService(dio: dio).getCardBySetAndNumber('eld', '146');

    expect(capturedPath, '/cards/eld/146');
  });

  test('avec lang, la langue est un segment de route', () async {
    late String capturedPath;
    final dio = _createMockDio((options) {
      capturedPath = options.path;
      return {'id': 'fr-id', 'lang': 'fr', 'printed_name': 'Frisson de probabilité'};
    });

    final data =
        await ScryfallApiService(dio: dio).getCardBySetAndNumber('eld', '146', lang: 'fr');

    expect(capturedPath, '/cards/eld/146/fr');
    expect(data['printed_name'], 'Frisson de probabilité');
  });

  test('deux langues de la meme carte ne partagent pas la meme entree de cache', () async {
    int calls = 0;
    final dio = _createMockDio((options) {
      calls++;
      return {'id': 'x', 'lang': options.path.endsWith('/fr') ? 'fr' : 'en'};
    });

    final api = ScryfallApiService(dio: dio);
    await api.getCardBySetAndNumber('eld', '146');
    await api.getCardBySetAndNumber('eld', '146', lang: 'fr');

    expect(calls, 2);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/scryfall_api_service_test.dart`
Expected: FAIL — `No named parameter with the name 'lang'`.

- [ ] **Step 3: Write minimal implementation**

Dans `lib/services/scryfall_api_service.dart`, remplacer :

```dart
  /// Récupère une carte par set code et collector number.
  Future<Map<String, dynamic>> getCardBySetAndNumber(String setCode, String collectorNumber) async {
    return _get('/cards/$setCode/$collectorNumber', cacheTtl: longCacheTtl);
  }
```

par :

```dart
  /// Récupère une carte par set code et collector number.
  ///
  /// [lang] cible une traduction precise (`/cards/eld/146/fr`). Attention :
  /// `POST /cards/collection` ignore silencieusement la langue, seule cette
  /// route unitaire rend une version traduite.
  Future<Map<String, dynamic>> getCardBySetAndNumber(
    String setCode,
    String collectorNumber, {
    String? lang,
  }) async {
    final suffix = (lang == null || lang.isEmpty) ? '' : '/$lang';
    return _get('/cards/$setCode/$collectorNumber$suffix', cacheTtl: longCacheTtl);
  }
```

Le cache de `_get` est indexé sur le chemin : deux langues donnent deux chemins, donc deux entrées. Le troisième test le verrouille.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/scryfall_api_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/scryfall_api_service.dart test/services/scryfall_api_service_test.dart
git commit -m "feat(api): router une carte vers sa traduction via /cards/{set}/{cn}/{lang}"
```

---

### Task 3: Le schéma v4 — cache, absences, file

**Files:**
- Modify: `lib/data/database/app_database.dart`
- Test: `test/data/app_database_v4_test.dart` (créer)

**Interfaces:**
- Consumes: rien.
- Produces sur `AppDatabase` :
  - `Future<DbCardPrint?> getCardPrint(String scryfallId)`
  - `Future<DbCardPrint?> findTranslation(String oracleId, String lang)`
  - `Future<void> upsertCardPrint(DbCardPrint print)`
  - `Future<bool> isTranslationAbsent(String oracleId, String lang)`
  - `Future<void> markTranslationAbsent(String oracleId, String lang)`
  - `Future<void> enqueueTranslation({required String scryfallId, required String setCode, required String collectorNumber, required String lang})`
  - `Future<List<DbTranslationTask>> nextTranslationTasks({int limit = 20})`
  - `Future<void> completeTranslationTask(int id)`
  - `Future<void> failTranslationTask(int id, String error)`

  Classe de données Drift générée : `DbCardPrint` (champs `scryfallId`, `oracleId`, `setCode`, `collectorNumber`, `lang`, `printedName`, `printedText`, `imageUri`, `fetchedAt`) et `DbTranslationTask` (champs `id`, `scryfallId`, `setCode`, `collectorNumber`, `lang`, `attempts`, `lastError`, `nextAttemptAt`).

- [ ] **Step 1: Write the failing test**

Créer `test/data/app_database_v4_test.dart` :

```dart
// Tests du schema v4 : cache de tirages, absences de traduction, file de travail.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';

AppDatabase _createTestDb() => AppDatabase(NativeDatabase.memory());

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String oracleId = 'oracle-thrill',
  String? printedName,
}) {
  return DbCardPrint(
    scryfallId: scryfallId,
    oracleId: oracleId,
    setCode: 'eld',
    collectorNumber: '146',
    lang: lang,
    printedName: printedName,
    printedText: null,
    imageUri: null,
    fetchedAt: DateTime.utc(2026, 9, 17),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = _createTestDb());
  tearDown(() async => db.close());

  group('Cache de tirages', () {
    test('un tirage ecrit est relu par son scryfallId', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));

      final read = await db.getCardPrint('en-id');
      expect(read, isNotNull);
      expect(read!.lang, 'en');
      expect(read.oracleId, 'oracle-thrill');
    });

    test('findTranslation retrouve la version francaise par oracleId', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));
      await db.upsertCardPrint(
        _print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité'),
      );

      final fr = await db.findTranslation('oracle-thrill', 'fr');
      expect(fr!.scryfallId, 'fr-id');
      expect(fr.printedName, 'Frisson de probabilité');
    });

    test('findTranslation rend null quand la langue est absente du cache', () async {
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));

      expect(await db.findTranslation('oracle-thrill', 'it'), isNull);
    });

    test('upsert deux fois le meme scryfallId ne cree pas de doublon', () async {
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Ancien'));
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr', printedName: 'Nouveau'));

      final read = await db.getCardPrint('fr-id');
      expect(read!.printedName, 'Nouveau');
    });
  });

  group('Absences de traduction', () {
    test('une absence non enregistree est fausse', () async {
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isFalse);
    });

    test('une absence enregistree est memorisee', () async {
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');

      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'de'), isFalse);
    });

    test('marquer deux fois la meme absence ne leve pas', () async {
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');
      await db.markTranslationAbsent('oracle-dreadbore', 'fr');

      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
    });
  });

  group('File de traduction', () {
    test('une tache enfilee ressort de nextTranslationTasks', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      final tasks = await db.nextTranslationTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.scryfallId, 'en-id');
      expect(tasks.first.lang, 'fr');
      expect(tasks.first.attempts, 0);
    });

    test('une tache terminee quitte la file', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final task = (await db.nextTranslationTasks()).first;

      await db.completeTranslationTask(task.id);

      expect(await db.nextTranslationTasks(), isEmpty);
    });

    test('une tache en echec reste en file, compte ses tentatives et recule', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final task = (await db.nextTranslationTasks()).first;

      await db.failTranslationTask(task.id, 'SocketException');

      final after = await db.nextTranslationTasks();
      expect(after, hasLength(1));
      expect(after.first.attempts, 1);
      expect(after.first.lastError, 'SocketException');
      expect(after.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);
    });

    test('enfiler deux fois le meme couple ne cree pas de doublon', () async {
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      await db.enqueueTranslation(
        scryfallId: 'en-id', setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(await db.nextTranslationTasks(), hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/app_database_v4_test.dart`
Expected: FAIL — `Undefined class 'DbCardPrint'`.

- [ ] **Step 3: Write minimal implementation**

Dans `lib/data/database/app_database.dart`, ajouter les trois tables après les tables existantes :

```dart
/// Cache des tirages Scryfall (une ligne par impression, langue comprise).
@DataClassName('DbCardPrint')
class CardPrints extends Table {
  TextColumn get scryfallId => text()();
  TextColumn get oracleId => text()();
  TextColumn get setCode => text()();
  TextColumn get collectorNumber => text()();
  TextColumn get lang => text()();
  TextColumn get printedName => text().nullable()();
  TextColumn get printedText => text().nullable()();
  TextColumn get imageUri => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {scryfallId};
}

/// Couples (carte, langue) dont Scryfall a confirme qu'aucune traduction
/// n'existe. Un 404 est une reponse definitive, pas une panne.
@DataClassName('DbTranslationAbsent')
class TranslationAbsences extends Table {
  TextColumn get oracleId => text()();
  TextColumn get lang => text()();

  @override
  Set<Column> get primaryKey => {oracleId, lang};
}

/// File persistante des traductions a recuperer en tache de fond.
@DataClassName('DbTranslationTask')
class TranslationTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scryfallId => text()();
  TextColumn get setCode => text()();
  TextColumn get collectorNumber => text()();
  TextColumn get lang => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime()();
}
```

Déclarer les trois tables dans `@DriftDatabase(tables: [...])`, passer `schemaVersion` à `4`, et ajouter la marche de migration dans `onUpgrade`, après le bloc `if (from < 3)` :

```dart
        if (from < 4) {
          await m.createTable(cardPrints);
          await m.createTable(translationAbsences);
          await m.createTable(translationTasks);
          await m.createIndex(Index(
            'idx_card_prints_oracle_lang',
            'CREATE INDEX IF NOT EXISTS idx_card_prints_oracle_lang '
            'ON card_prints (oracle_id, lang)',
          ));
        }
```

Ajouter les méthodes DAO à la fin de la classe `AppDatabase` :

```dart
  // ============================================================
  // CACHE DE TIRAGES / TRADUCTIONS
  // ============================================================

  Future<DbCardPrint?> getCardPrint(String scryfallId) =>
      (select(cardPrints)..where((p) => p.scryfallId.equals(scryfallId)))
          .getSingleOrNull();

  Future<DbCardPrint?> findTranslation(String oracleId, String lang) =>
      (select(cardPrints)
            ..where((p) => p.oracleId.equals(oracleId) & p.lang.equals(lang))
            ..limit(1))
          .getSingleOrNull();

  Future<void> upsertCardPrint(DbCardPrint print) =>
      into(cardPrints).insertOnConflictUpdate(print);

  Future<bool> isTranslationAbsent(String oracleId, String lang) async {
    final row = await (select(translationAbsences)
          ..where((a) => a.oracleId.equals(oracleId) & a.lang.equals(lang)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> markTranslationAbsent(String oracleId, String lang) =>
      into(translationAbsences).insertOnConflictUpdate(
        DbTranslationAbsent(oracleId: oracleId, lang: lang),
      );

  Future<void> enqueueTranslation({
    required String scryfallId,
    required String setCode,
    required String collectorNumber,
    required String lang,
  }) async {
    final existing = await (select(translationTasks)
          ..where((t) => t.scryfallId.equals(scryfallId) & t.lang.equals(lang)))
        .getSingleOrNull();
    if (existing != null) return;

    await into(translationTasks).insert(TranslationTasksCompanion.insert(
      scryfallId: scryfallId,
      setCode: setCode,
      collectorNumber: collectorNumber,
      lang: lang,
      nextAttemptAt: DateTime.now(),
    ));
  }

  /// Taches prêtes a etre rejouees, les plus anciennes d'abord.
  Future<List<DbTranslationTask>> nextTranslationTasks({int limit = 20}) =>
      (select(translationTasks)
            ..where((t) => t.nextAttemptAt.isSmallerOrEqualValue(DateTime.now()))
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(limit))
          .get();

  Future<void> completeTranslationTask(int id) =>
      (delete(translationTasks)..where((t) => t.id.equals(id))).go();

  /// Recule la tache d'un backoff exponentiel plafonne a une heure.
  Future<void> failTranslationTask(int id, String error) async {
    final task = await (select(translationTasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (task == null) return;

    final attempts = task.attempts + 1;
    final delaySeconds = (1 << (attempts - 1)) * 30;
    final capped = delaySeconds > 3600 ? 3600 : delaySeconds;

    await (update(translationTasks)..where((t) => t.id.equals(id))).write(
      TranslationTasksCompanion(
        attempts: Value(attempts),
        lastError: Value(error),
        nextAttemptAt: Value(DateTime.now().add(Duration(seconds: capped))),
      ),
    );
  }
```

Le dernier test lit `nextTranslationTasks()` juste après un échec : la tâche est reculée de 30 s, donc elle ne ressortirait pas du filtre `nextAttemptAt <= now`. Adapter ce test-là pour interroger la table directement :

```dart
      final after = await db.select(db.translationTasks).get();
```

- [ ] **Step 4: Régénérer le code Drift puis lancer les tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Puis: `flutter test test/data/app_database_v4_test.dart test/data/app_database_test.dart test/data/app_database_v2_test.dart`
Expected: PASS sur les trois fichiers — les tests v2/v3 existants ne doivent pas bouger, la migration v4 n'ajoute que des tables.

- [ ] **Step 5: Commit**

```bash
git add lib/data/database/app_database.dart lib/data/database/app_database.g.dart test/data/app_database_v4_test.dart
git commit -m "feat(db): schema v4 — cache de tirages, absences de traduction, file persistante"
```

---

### Task 4: Le résolveur en deux temps

**Files:**
- Create: `lib/models/card_print.dart`
- Create: `lib/services/card_resolver.dart`
- Test: `test/services/card_resolver_test.dart` (créer)

**Interfaces:**
- Consumes: `ScryfallApiService.getCardBySetAndNumber(set, cn, {lang})` et `fetchCollection(identifiers)` (Task 2) ; les DAO de Task 3.
- Produces :
  - `class PrintRequest { final String? scryfallId; final String? setCode; final String? collectorNumber; final String? lang; final String name; }`
  - `class ResolvedPrint { final String scryfallId; final String oracleId; final String setCode; final String collectorNumber; final String lang; final String name; final String? printedName; }`
  - `class CardResolver { CardResolver({required ScryfallApiService api, required AppDatabase db}); Future<List<ResolvedPrint>> resolveEditions(List<PrintRequest> requests); Future<ResolvedPrint?> resolveTranslation({required String scryfallId, required String oracleId, required String setCode, required String collectorNumber, required String lang}); }`

- [ ] **Step 1: Write the failing test**

Créer `test/services/card_resolver_test.dart` :

```dart
// Tests du CardResolver. Fixtures calquees sur les reponses reelles de
// Scryfall pour eld/146, relevees le 2026-09-17.
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_print.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';

const _oracleId = '1cb0610b-a731-42c2-b93f-0a29f63cebf4';
const _enId = 'c9021f85-7ab4-4a78-a398-1611fe09cd14';
const _frId = '87027e87-e62d-42d6-9a79-c3e18394223d';

Map<String, dynamic> _enCard() => {
      'id': _enId,
      'oracle_id': _oracleId,
      'name': 'Thrill of Possibility',
      'set': 'eld',
      'collector_number': '146',
      'lang': 'en',
    };

Map<String, dynamic> _frCard() => {
      'id': _frId,
      'oracle_id': _oracleId,
      'name': 'Thrill of Possibility',
      'printed_name': 'Frisson de probabilité',
      'printed_text': 'Piochez deux cartes.',
      'set': 'eld',
      'collector_number': '146',
      'lang': 'fr',
    };

/// Dio mocke : [handler] rend soit une Map (200), soit un int (code d'erreur).
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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('resolveEditions', () {
    test('resout un set et un numero vers le tirage exact', () async {
      final dio = _mockDio((_) => {'data': [_enCard()], 'not_found': []});
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final results = await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);

      expect(results, hasLength(1));
      expect(results.first.scryfallId, _enId);
      expect(results.first.oracleId, _oracleId);
      expect(results.first.setCode, 'eld');
    });

    test('met le tirage resolu en cache', () async {
      final dio = _mockDio((_) => {'data': [_enCard()], 'not_found': []});
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);

      final cached = await db.getCardPrint(_enId);
      expect(cached, isNotNull);
      expect(cached!.oracleId, _oracleId);
    });

    test('une carte deja en cache ne declenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((_) {
        calls++;
        return {'data': [_enCard()], 'not_found': []};
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);
      const request =
          PrintRequest(name: 'Thrill of Possibility', scryfallId: _enId);

      await resolver.resolveEditions([request]); // remplit le cache
      final callsAfterFirst = calls;
      await resolver.resolveEditions([request]);

      expect(calls, callsAfterFirst);
    });
  });

  group('resolveTranslation', () {
    test('rend la version francaise avec son nom imprime', () async {
      final dio = _mockDio((options) =>
          options.path.endsWith('/fr') ? _frCard() : _enCard());
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final fr = await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(fr, isNotNull);
      expect(fr!.scryfallId, _frId);
      expect(fr.printedName, 'Frisson de probabilité');
      expect(fr.lang, 'fr');
    });

    test('un 404 rend null et memorise l absence', () async {
      final dio = _mockDio((_) => 404);
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      final fr = await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );

      expect(fr, isNull);
      expect(await db.isTranslationAbsent('oracle-dreadbore', 'fr'), isTrue);
    });

    test('une absence memorisee ne redeclenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((_) {
        calls++;
        return 404;
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );
      await resolver.resolveTranslation(
        scryfallId: 'sld-en', oracleId: 'oracle-dreadbore',
        setCode: 'sld', collectorNumber: '141', lang: 'fr',
      );

      expect(calls, 1);
    });

    test('une traduction en cache ne redeclenche aucune requete', () async {
      int calls = 0;
      final dio = _mockDio((options) {
        calls++;
        return options.path.endsWith('/fr') ? _frCard() : _enCard();
      });
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );
      final callsAfterFirst = calls;
      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      expect(calls, callsAfterFirst);
    });

    test('la traduction n ecrase pas le tirage possede', () async {
      final dio = _mockDio((options) =>
          options.path.endsWith('/fr') ? _frCard() : _enCard());
      final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

      await resolver.resolveEditions([
        const PrintRequest(name: 'Thrill of Possibility', setCode: 'eld', collectorNumber: '146'),
      ]);
      await resolver.resolveTranslation(
        scryfallId: _enId, oracleId: _oracleId,
        setCode: 'eld', collectorNumber: '146', lang: 'fr',
      );

      final owned = await db.getCardPrint(_enId);
      expect(owned!.lang, 'en');
      expect(owned.scryfallId, _enId);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/card_resolver_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:magic_companion/services/card_resolver.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/models/card_print.dart` :

```dart
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
  });

  /// Le nom a afficher : le nom imprime quand il existe, sinon le nom oracle.
  String get displayName => printedName ?? name;

  factory ResolvedPrint.fromJson(Map<String, dynamic> json) {
    final imageUris = json['image_uris'] as Map<String, dynamic>?;
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
    );
  }
}
```

Créer `lib/services/card_resolver.dart` :

```dart
// Point de passage unique de toute resolution de carte.
//
// Deux temps, imposes par l'API Scryfall :
//   1. POST /cards/collection fixe l'edition (il IGNORE le parametre lang)
//   2. GET /cards/{set}/{cn}/{lang} rend la traduction, qui a son propre id
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import 'package:dio/dio.dart';

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import 'scryfall_api_service.dart';

class CardResolver {
  static const int _batchSize = 75;

  final ScryfallApiService _api;
  final AppDatabase _db;

  CardResolver({required ScryfallApiService api, required AppDatabase db})
      : _api = api,
        _db = db;

  /// Temps 1 : fixe l'edition de chaque requete, cache compris.
  Future<List<ResolvedPrint>> resolveEditions(List<PrintRequest> requests) async {
    final List<ResolvedPrint> resolved = [];
    final List<PrintRequest> toFetch = [];

    for (final request in requests) {
      final cached = await _fromCache(request);
      if (cached != null) {
        resolved.add(cached);
      } else {
        toFetch.add(request);
      }
    }

    for (var i = 0; i < toFetch.length; i += _batchSize) {
      final slice = toFetch.skip(i).take(_batchSize).toList();
      final identifiers = slice.map(_toIdentifier).toList();

      try {
        final data = await _api.fetchCollection(identifiers);
        final List<dynamic> found = data['data'] ?? [];
        for (final json in found) {
          final print = ResolvedPrint.fromJson(json as Map<String, dynamic>);
          await _cache(print);
          resolved.add(print);
        }
      } on DioException {
        // Lot injoignable : les cartes restent non resolues, l'appelant decide.
      }
    }

    return resolved;
  }

  /// Temps 2 : recupere la traduction d'un tirage, ou null s'il n'en existe pas.
  Future<ResolvedPrint?> resolveTranslation({
    required String scryfallId,
    required String oracleId,
    required String setCode,
    required String collectorNumber,
    required String lang,
  }) async {
    if (await _db.isTranslationAbsent(oracleId, lang)) return null;

    final cached = await _db.findTranslation(oracleId, lang);
    if (cached != null) return _fromRow(cached);

    try {
      final data = await _api.getCardBySetAndNumber(setCode, collectorNumber, lang: lang);
      final print = ResolvedPrint.fromJson(data);
      await _cache(print);
      return print;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Pas de traduction dans cette langue : c'est une reponse, pas une panne.
        await _db.markTranslationAbsent(oracleId, lang);
        return null;
      }
      rethrow;
    }
  }

  Map<String, dynamic> _toIdentifier(PrintRequest request) {
    if (request.scryfallId != null) return {'id': request.scryfallId};
    if (request.setCode != null && request.collectorNumber != null) {
      return {'set': request.setCode!.toLowerCase(), 'collector_number': request.collectorNumber};
    }
    return {'name': request.name};
  }

  Future<ResolvedPrint?> _fromCache(PrintRequest request) async {
    if (request.scryfallId == null) return null;
    final row = await _db.getCardPrint(request.scryfallId!);
    return row == null ? null : _fromRow(row);
  }

  ResolvedPrint _fromRow(DbCardPrint row) => ResolvedPrint(
        scryfallId: row.scryfallId,
        oracleId: row.oracleId,
        setCode: row.setCode,
        collectorNumber: row.collectorNumber,
        lang: row.lang,
        name: row.printedName ?? '',
        printedName: row.printedName,
        printedText: row.printedText,
        imageUri: row.imageUri,
      );

  Future<void> _cache(ResolvedPrint print) => _db.upsertCardPrint(DbCardPrint(
        scryfallId: print.scryfallId,
        oracleId: print.oracleId,
        setCode: print.setCode,
        collectorNumber: print.collectorNumber,
        lang: print.lang,
        printedName: print.printedName ?? print.name,
        printedText: print.printedText,
        imageUri: print.imageUri,
        fetchedAt: DateTime.now(),
      ));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/card_resolver_test.dart`
Expected: PASS — 8 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/models/card_print.dart lib/services/card_resolver.dart test/services/card_resolver_test.dart
git commit -m "feat(cards): CardResolver — edition en batch, traduction unitaire, 404 memorise"
```

---

### Task 5: Le worker de traduction

**Files:**
- Create: `lib/services/translation_worker.dart`
- Test: `test/services/translation_worker_test.dart` (créer)

**Interfaces:**
- Consumes: `CardResolver.resolveTranslation(...)` (Task 4), `AppDatabase.nextTranslationTasks / completeTranslationTask / failTranslationTask / enqueueTranslation` (Task 3).
- Produces: `class TranslationWorker { TranslationWorker({required CardResolver resolver, required AppDatabase db}); Future<int> drain({int maxTasks = 50}); }` — rend le nombre de tâches retirées de la file.

- [ ] **Step 1: Write the failing test**

Créer `test/services/translation_worker_test.dart` :

```dart
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/services/card_resolver.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/services/translation_worker.dart';

const _oracleId = '1cb0610b-a731-42c2-b93f-0a29f63cebf4';
const _enId = 'c9021f85-7ab4-4a78-a398-1611fe09cd14';

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

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Le tirage possede doit etre en cache : le worker y lit l'oracleId.
    await db.upsertCardPrint(DbCardPrint(
      scryfallId: _enId,
      oracleId: _oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: 'en',
      printedName: 'Thrill of Possibility',
      printedText: null,
      imageUri: null,
      fetchedAt: DateTime.utc(2026, 9, 17),
    ));
  });

  tearDown(() async => db.close());

  test('le worker vide la file et met la traduction en cache', () async {
    final dio = _mockDio((_) => {
          'id': 'fr-id',
          'oracle_id': _oracleId,
          'name': 'Thrill of Possibility',
          'printed_name': 'Frisson de probabilité',
          'set': 'eld',
          'collector_number': '146',
          'lang': 'fr',
        });
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.nextTranslationTasks(), isEmpty);
    final fr = await db.findTranslation(_oracleId, 'fr');
    expect(fr!.printedName, 'Frisson de probabilité');
  });

  test('un 404 retire la tache de la file sans la rejouer', () async {
    final dio = _mockDio((_) => 404);
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.select(db.translationTasks).get(), isEmpty);
    expect(await db.isTranslationAbsent(_oracleId, 'fr'), isTrue);
  });

  test('une panne reseau laisse la tache en file avec un backoff', () async {
    final dio = _mockDio((_) => 503);
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: _enId, setCode: 'eld', collectorNumber: '146', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 0);
    final remaining = await db.select(db.translationTasks).get();
    expect(remaining, hasLength(1));
    expect(remaining.first.attempts, 1);
    expect(remaining.first.nextAttemptAt.isAfter(DateTime.now()), isTrue);
  });

  test('une tache dont le tirage possede est inconnu est abandonnee', () async {
    final dio = _mockDio((_) => {'id': 'x', 'oracle_id': 'y', 'lang': 'fr'});
    final worker = TranslationWorker(
      resolver: CardResolver(api: ScryfallApiService(dio: dio), db: db),
      db: db,
    );
    await db.enqueueTranslation(
      scryfallId: 'inconnu', setCode: 'xxx', collectorNumber: '1', lang: 'fr',
    );

    final done = await worker.drain();

    expect(done, 1);
    expect(await db.select(db.translationTasks).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/translation_worker_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../translation_worker.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/services/translation_worker.dart` :

```dart
// Vide la file de traduction en tache de fond.
// L'import rend la main des le temps 1 ; ce worker fait le temps 2.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import 'dart:developer';

import '../data/database/app_database.dart';
import 'card_resolver.dart';

class TranslationWorker {
  final CardResolver _resolver;
  final AppDatabase _db;
  bool _running = false;

  TranslationWorker({required CardResolver resolver, required AppDatabase db})
      : _resolver = resolver,
        _db = db;

  /// Traite les taches pretes. Rend le nombre de taches retirees de la file.
  /// Un seul drain a la fois : un second appel concurrent rend 0 immediatement.
  Future<int> drain({int maxTasks = 50}) async {
    if (_running) return 0;
    _running = true;
    int completed = 0;

    try {
      final tasks = await _db.nextTranslationTasks(limit: maxTasks);
      for (final task in tasks) {
        final owned = await _db.getCardPrint(task.scryfallId);
        if (owned == null) {
          // Le tirage possede n'est plus en cache : la tache n'a plus d'objet.
          await _db.completeTranslationTask(task.id);
          completed++;
          continue;
        }

        try {
          await _resolver.resolveTranslation(
            scryfallId: owned.scryfallId,
            oracleId: owned.oracleId,
            setCode: task.setCode,
            collectorNumber: task.collectorNumber,
            lang: task.lang,
          );
          // 200 comme 404 sont des reponses : la tache est finie dans les deux cas.
          await _db.completeTranslationTask(task.id);
          completed++;
        } catch (e) {
          log('Traduction reportee (${task.scryfallId}/${task.lang}): $e',
              name: 'TranslationWorker');
          await _db.failTranslationTask(task.id, e.toString());
        }
      }
    } finally {
      _running = false;
    }

    return completed;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/translation_worker_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/translation_worker.dart test/services/translation_worker_test.dart
git commit -m "feat(cards): worker de traduction — file persistante, backoff, 404 terminal"
```

---

### Task 6: Brancher l'import sur le résolveur

**Files:**
- Modify: `lib/services/collection_service.dart:110-140`
- Test: `test/services/collection_service_test.dart`

**Interfaces:**
- Consumes: `DecklistEntry.setCode / collectorNumber / isFoil` (Task 1), `CardResolver.resolveEditions` (Task 4), `AppDatabase.enqueueTranslation` (Task 3).
- Produces: `CollectionService.importDecklist(...)` rend la main dès le temps 1 et enfile les traductions.

- [ ] **Step 1: Write the failing test**

Lire d'abord `lib/services/collection_service.dart:110-140` pour reprendre la signature exacte de la méthode d'import existante. `test/services/collection_service_test.dart` n'a pas de helper Dio : y recopier `_mockDio` depuis `test/services/card_resolver_test.dart`, puis ajouter le test qui verrouille les deux comportements :

```dart
test('l import resout par edition et n attend pas les traductions', () async {
  int collectionCalls = 0;
  int unitaryCalls = 0;
  final dio = _mockDio((options) {
    if (options.path.contains('/cards/collection')) {
      collectionCalls++;
      return {
        'data': [
          {
            'id': 'ltc-284-en',
            'oracle_id': 'oracle-sol-ring',
            'name': 'Sol Ring',
            'set': 'ltc',
            'collector_number': '284',
            'lang': 'en',
          }
        ],
        'not_found': [],
      };
    }
    unitaryCalls++;
    return {'id': 'ltc-284-fr', 'oracle_id': 'oracle-sol-ring', 'lang': 'fr'};
  });

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final resolver = CardResolver(api: ScryfallApiService(dio: dio), db: db);

  final entries = DeckFormatService.parseDecklistText('1 Sol Ring (LTC) 284 *F*').mainboard;
  final resolved = await resolver.resolveEditions(entries
      .map((e) => PrintRequest(
            name: e.name,
            setCode: e.setCode,
            collectorNumber: e.collectorNumber,
          ))
      .toList());

  for (final print in resolved) {
    await db.enqueueTranslation(
      scryfallId: print.scryfallId,
      setCode: print.setCode,
      collectorNumber: print.collectorNumber,
      lang: 'fr',
    );
  }

  // Temps 1 seulement : l'edition est exacte, aucune requete unitaire n'a eu lieu.
  expect(resolved.single.scryfallId, 'ltc-284-en');
  expect(resolved.single.setCode, 'ltc');
  expect(collectionCalls, 1);
  expect(unitaryCalls, 0);
  expect(await db.nextTranslationTasks(), hasLength(1));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/collection_service_test.dart`
Expected: FAIL — `PrintRequest` / `CardResolver` non importés, puis échec sur `setCode` si Task 1 n'est pas en place.

- [ ] **Step 3: Write minimal implementation**

Dans `lib/services/collection_service.dart`, remplacer la construction d'identifiants par nom (ligne 122, `batchNames.map((name) => {'name': name})`) par un passage via `CardResolver`. Le service prend le résolveur en dépendance plutôt que l'API brute :

```dart
  final CardResolver _resolver;
  final AppDatabase _db;

  /// Resout les entrees d'une decklist par edition, puis enfile les traductions.
  /// Rend la main des que les editions sont connues : les traductions arrivent
  /// en tache de fond (voir TranslationWorker).
  Future<List<ResolvedPrint>> resolveImportedEntries(
    List<DecklistEntry> entries, {
    required String preferredLang,
  }) async {
    final requests = entries
        .map((e) => PrintRequest(
              name: e.name,
              setCode: e.setCode,
              collectorNumber: e.collectorNumber,
            ))
        .toList();

    final resolved = await _resolver.resolveEditions(requests);

    for (final print in resolved) {
      if (print.lang == preferredLang) continue;
      await _db.enqueueTranslation(
        scryfallId: print.scryfallId,
        setCode: print.setCode,
        collectorNumber: print.collectorNumber,
        lang: preferredLang,
      );
    }

    return resolved;
  }
```

Mettre à jour le constructeur de `CollectionService` et son provider dans `lib/providers/service_providers.dart` pour injecter `CardResolver` et `AppDatabase`. Lire le provider existant avant d'éditer : suivre exactement le style de déclaration déjà utilisé dans ce fichier.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/collection_service_test.dart test/services/deck_format_service_test.dart`
Expected: PASS sur les deux fichiers.

- [ ] **Step 5: Commit**

```bash
git add lib/services/collection_service.dart lib/providers/service_providers.dart test/services/collection_service_test.dart
git commit -m "feat(import): resoudre par edition et differer les traductions"
```

---

### Task 7: Le scanner lit la langue imprimée

Les cartes modernes impriment la langue en bas : `146/280 C · ELD · FR`. L'OCR capture déjà set et numéro mais jette la langue.

**Files:**
- Modify: `lib/controllers/card_detail_controller.dart:205-230` et `:292-304`
- Test: `test/controllers/card_detail_lang_test.dart` (créer)

**Interfaces:**
- Consumes: `ScryfallApiService.getCardBySetAndNumber(set, cn, {lang})` (Task 2).
- Produces: une fonction de haut niveau testable en Dart pur, extraite du contrôleur :
  `({String setCode, String collectorNumber, String? lang})? parsePrintFooter(String blockText)` exportée depuis `lib/controllers/card_detail_controller.dart`.

- [ ] **Step 1: Write the failing test**

Créer `test/controllers/card_detail_lang_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_detail_controller.dart';

void main() {
  group('parsePrintFooter', () {
    test('lit set, numero et langue sur un bas de carte francais', () {
      final parsed = parsePrintFooter('146/280 C ELD FR');

      expect(parsed, isNotNull);
      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, 'fr');
    });

    test('sans code langue, la langue est nulle', () {
      final parsed = parsePrintFooter('ELD 146');

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });

    test('ignore un code langue qui n est pas supporte par Scryfall', () {
      final parsed = parsePrintFooter('146/280 C ELD ZZ');

      expect(parsed!.lang, isNull);
    });

    test('rend null sur un texte sans motif d edition', () {
      expect(parsePrintFooter('Créature : humain et éclaireur'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/card_detail_lang_test.dart`
Expected: FAIL — `Undefined name 'parsePrintFooter'`.

- [ ] **Step 3: Write minimal implementation**

Dans `lib/controllers/card_detail_controller.dart`, ajouter au niveau du fichier (hors de la classe), près des autres déclarations de haut niveau :

```dart
/// Langues imprimees sur les cartes et connues de Scryfall.
const Set<String> kPrintedLanguages = {
  'en', 'fr', 'de', 'it', 'es', 'pt', 'ja', 'ko', 'ru', 'zhs', 'zht', 'ph',
};

final RegExp _footerRegex = RegExp(
  r'\b([A-Z0-9]{3,5})[\s•\/\-]{1,3}([0-9]{1,4}[a-z]?)\b',
  caseSensitive: false,
);
final RegExp _footerLangRegex = RegExp(r'\b([A-Za-z]{2,3})\b\s*$');

/// Lit le bas d'une carte : edition, numero de collection et langue imprimee.
/// Rend null quand aucun motif d'edition n'est reconnaissable.
({String setCode, String collectorNumber, String? lang})? parsePrintFooter(
  String blockText,
) {
  final match = _footerRegex.firstMatch(blockText);
  if (match == null) return null;

  String? lang;
  final langMatch = _footerLangRegex.firstMatch(blockText.trim());
  final candidate = langMatch?.group(1)?.toLowerCase();
  if (candidate != null && kPrintedLanguages.contains(candidate)) {
    lang = candidate;
  }

  return (
    setCode: match.group(1)!,
    collectorNumber: match.group(2)!,
    lang: lang,
  );
}
```

Remplacer ensuite la boucle OCR (`lib/controllers/card_detail_controller.dart:214-226`) par :

```dart
      for (var block in recognizedText.blocks) {
        final String blockText = block.text.replaceAll('\n', ' ');
        final parsed = parsePrintFooter(blockText);
        if (parsed != null) {
          if (!mounted) return;
          state = state.copyWith(
            statusMessage:
                'Code détecté : ${parsed.setCode} #${parsed.collectorNumber}',
          );
          final bool success = await _fetchExactCard(
            parsed.setCode,
            parsed.collectorNumber,
            lang: parsed.lang,
          );
          if (success) return;
        }
      }
```

Et élargir `_fetchExactCard` (ligne 292) :

```dart
  Future<bool> _fetchExactCard(String set, String cn, {String? lang}) async {
    state = state.copyWith(
      statusMessage: 'Identification précise ($set #$cn)...',
    );
    try {
      final data = await _apiService.getCardBySetAndNumber(set, cn, lang: lang);
      selectCard(ScryfallCard.fromJson(data));
      return true;
    } catch (e) {
      // Une langue absente n'est pas un echec : on retente sans langue.
      if (lang != null) return _fetchExactCard(set, cn);
    }
    return false;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/card_detail_lang_test.dart test/controllers/`
Expected: PASS, y compris les tests de contrôleur existants.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/card_detail_controller.dart test/controllers/card_detail_lang_test.dart
git commit -m "feat(scan): lire la langue imprimee au bas de la carte et la resoudre"
```

---

### Task 8: La projection d'affichage et la troncature

**Porte visuelle.** Cette tâche déplace des pixels : elle ne se clôt pas sur des tests verts. La maquette validée est https://claude.ai/artifact/6hnNC9MM1fH112ptf8oMoQ.

**Files:**
- Create: `lib/providers/card_display_provider.dart`
- Modify: `lib/widgets/decks/deck_card_title.dart` — widget `DeckCardTile`, le `ListTile` dont le `title` rend le nom de la carte
- Test: `test/providers/card_display_provider_test.dart` (créer)

**Interfaces:**
- Consumes: `AppDatabase.findTranslation(oracleId, lang)` (Task 3), `ResolvedPrint` (Task 4).
- Produces: `class CardDisplay { final String name; final String lang; final bool isFallback; }` et
  `Future<CardDisplay> resolveDisplay({required AppDatabase db, required DbCardPrint owned, required String preferredLang})`.

- [ ] **Step 1: Write the failing test**

Créer `test/providers/card_display_provider_test.dart` :

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/providers/card_display_provider.dart';

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  required String printedName,
  String oracleId = 'oracle-thrill',
}) =>
    DbCardPrint(
      scryfallId: scryfallId,
      oracleId: oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: lang,
      printedName: printedName,
      printedText: null,
      imageUri: null,
      fetchedAt: DateTime.utc(2026, 9, 17),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('la traduction en cache est projetee', () async {
    final owned = _print(
        scryfallId: 'en-id', lang: 'en', printedName: 'Thrill of Possibility');
    await db.upsertCardPrint(owned);
    await db.upsertCardPrint(_print(
        scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité'));

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Frisson de probabilité');
    expect(display.lang, 'fr');
    expect(display.isFallback, isFalse);
  });

  test('sans traduction, on replie sur le tirage possede et on le signale', () async {
    final owned = _print(
        scryfallId: 'sld-en',
        lang: 'en',
        printedName: 'Dreadbore',
        oracleId: 'oracle-dreadbore');
    await db.upsertCardPrint(owned);

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Dreadbore');
    expect(display.lang, 'en');
    expect(display.isFallback, isTrue);
  });

  test('un tirage deja dans la langue voulue n est pas un repli', () async {
    final owned = _print(
        scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité');
    await db.upsertCardPrint(owned);

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Frisson de probabilité');
    expect(display.isFallback, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/card_display_provider_test.dart`
Expected: FAIL — fichier `card_display_provider.dart` absent.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/providers/card_display_provider.dart` :

```dart
// Projection d'affichage : le tirage possede reste la verite, la langue
// preferee n'est qu'une vue par-dessus.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import '../data/database/app_database.dart';

/// Ce qu'on montre a l'ecran pour une carte possedee.
class CardDisplay {
  final String name;
  final String lang;

  /// Vrai quand aucune traduction n'existe dans la langue preferee et qu'on
  /// affiche le tirage possede a la place. L'UI le signale par un badge ambre.
  final bool isFallback;

  const CardDisplay({
    required this.name,
    required this.lang,
    required this.isFallback,
  });
}

/// Projette un tirage possede dans la langue preferee, sans jamais le modifier.
Future<CardDisplay> resolveDisplay({
  required AppDatabase db,
  required DbCardPrint owned,
  required String preferredLang,
}) async {
  if (owned.lang == preferredLang) {
    return CardDisplay(
      name: owned.printedName ?? '',
      lang: owned.lang,
      isFallback: false,
    );
  }

  final translated = await db.findTranslation(owned.oracleId, preferredLang);
  if (translated != null) {
    return CardDisplay(
      name: translated.printedName ?? '',
      lang: translated.lang,
      isFallback: false,
    );
  }

  return CardDisplay(
    name: owned.printedName ?? '',
    lang: owned.lang,
    isFallback: true,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/card_display_provider_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 5: Appliquer la troncature dans la ligne de deck**

Sur le `Text` qui rend le nom de carte dans la ligne de deck :

```dart
Text(
  display.name,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  softWrap: false,
  style: AppTextStyles.cardName,
),
```

Dans `DeckCardTile`, c'est le `title:` du `ListTile`. La hauteur de ligne ne doit jamais dépendre du nom : `ListTile` grandit si son `title` passe à deux lignes, donc `maxLines: 1` et `softWrap: false` sont tous les deux nécessaires, pas seulement l'ellipse.

- [ ] **Step 6: Porte visuelle — capture avant de continuer**

Run: `flutter run -d windows`
Ouvrir un deck contenant au moins une carte au nom long (`Libérateur, mécanoptère de combat d'Urza`, BRO 237) et une carte sans version française (`Dreadbore`, SLD 141).
Prendre une capture de la liste de deck et de la fiche carte, la comparer à la maquette, et **la faire valider par l'utilisateur avant de passer à la Task 9.** Des tests verts ne closent pas cette étape.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/card_display_provider.dart lib/widgets/decks/deck_card_title.dart test/providers/card_display_provider_test.dart
git commit -m "feat(ui): projeter la langue preferee et tronquer les noms longs sur une ligne"
```

---

### Task 9: Sélecteur de versions multilingue et reprise de l'existant

**Files:**
- Modify: `lib/widgets/cards/versions_selector_sheet.dart:156`
- Create: `lib/services/print_backfill_service.dart`
- Test: `test/services/print_backfill_service_test.dart` (créer)

**Interfaces:**
- Consumes: `CardResolver.resolveEditions` (Task 4), `AppDatabase.getCardPrint` (Task 3).
- Produces: `class PrintBackfillService { PrintBackfillService({required AppDatabase db, required CardResolver resolver}); Future<int> run(); }` — rend le nombre de tirages mis en cache. **Ne réécrit jamais `scryfallId`.**

> Le backfill vit dans son propre service, pas sur `AppDatabase` : `CardResolver` importe déjà `AppDatabase`, une méthode de backfill sur la base créerait un cycle d'imports entre la couche données et la couche services.

- [ ] **Step 1: Write the failing test**

Créer `test/services/print_backfill_service_test.dart`. Y recopier le helper `_mockDio` de `test/services/card_resolver_test.dart` (les helpers de test ne sont pas partagés dans ce projet) et le squelette habituel (`late AppDatabase db` + setUp/tearDown en mémoire). Puis le test :

```dart
group('Reprise de l existant', () {
  test('le backfill met les tirages en cache sans toucher aux scryfallId', () async {
    await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
          deckId: 'deck-1',
          board: 'main',
          scryfallId: 'ancien-id',
          name: 'Sol Ring',
        ));
    await db.into(db.decks).insert(
        DecksCompanion.insert(id: 'deck-1', name: 'Test'));

    final avant = await db.select(db.deckCards).get();
    expect(avant.single.scryfallId, 'ancien-id');

    // Un resolveur qui rend toujours le meme tirage.
    final service = PrintBackfillService(db: db, resolver: _stubResolver(db));
    final resolved = await service.run();

    final apres = await db.select(db.deckCards).get();
    expect(apres.single.scryfallId, 'ancien-id'); // jamais reecrit
    expect(resolved, 1);
    expect(await db.getCardPrint('ancien-id'), isNotNull);
  });
});
```

Le stub :

```dart
CardResolver _stubResolver(AppDatabase db) {
  final dio = _mockDio((_) => {
        'data': [
          {
            'id': 'ancien-id',
            'oracle_id': 'oracle-sol-ring',
            'name': 'Sol Ring',
            'set': 'ltc',
            'collector_number': '284',
            'lang': 'en',
          }
        ],
        'not_found': [],
      });
  return CardResolver(api: ScryfallApiService(dio: dio), db: db);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/print_backfill_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../print_backfill_service.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/services/print_backfill_service.dart` :

```dart
// Reprise de l'existant : met en cache le tirage de chaque carte deja stockee,
// pour que la projection d'affichage dispose d'un oracleId.
//
// Ne modifie AUCUNE ligne de deck ni de collection : le scryfallId possede est
// la verite, et ce service ne fait que remplir le cache a cote.

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import 'card_resolver.dart';

class PrintBackfillService {
  final AppDatabase _db;
  final CardResolver _resolver;

  PrintBackfillService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  /// Rend le nombre de tirages nouvellement mis en cache.
  Future<int> run() async {
    final deckRows = await _db.select(_db.deckCards).get();
    final collectionRows = await _db.select(_db.collectionCards).get();

    final ids = <String, String>{}; // scryfallId -> nom
    for (final row in deckRows) {
      ids[row.scryfallId] = row.name;
    }
    for (final row in collectionRows) {
      ids[row.scryfallId] = row.name;
    }

    final missing = <PrintRequest>[];
    for (final entry in ids.entries) {
      if (await _db.getCardPrint(entry.key) == null) {
        missing.add(PrintRequest(name: entry.value, scryfallId: entry.key));
      }
    }

    final resolved = await _resolver.resolveEditions(missing);
    return resolved.length;
  }
}
```

Dans `lib/widgets/cards/versions_selector_sheet.dart`, remplacer la recherche de versions par une recherche multilingue. Ligne 156, le libellé `'#${card.collectorNumber} • ${card.lang.toUpperCase()}'` reste correct ; ce qui change est la requête qui alimente la liste :

```dart
final data = await apiService.searchCards(
  'oracleid:${card.oracleId} ',
  unique: 'prints',
  includeMultilingual: true,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS sur l'ensemble de la suite (652+ tests existants compris).

- [ ] **Step 5: Porte visuelle**

Ouvrir le sélecteur de versions sur une carte à plusieurs langues (`Thrill of Possibility`, ELD 146, 11 langues). Capture, comparaison à la maquette, validation par l'utilisateur.

- [ ] **Step 6: Commit**

```bash
git add lib/services/print_backfill_service.dart lib/widgets/cards/versions_selector_sheet.dart test/services/print_backfill_service_test.dart
git commit -m "feat(cards): selecteur de versions multilingue et reprise des tirages existants"
```

---

---

### Task 10: La langue préférée et son déclencheur

Les tâches 6 et 8 prennent `preferredLang` en paramètre ; personne ne le fournit encore. Cette tâche branche `glossaryLang` et fait repartir le backfill quand l'utilisateur change de langue.

Attention : `glossaryLang` a **deux domiciles** dans ce projet. `lib/pages/glossary/glossary_page.dart:72` l'écrit dans `SharedPreferences`, tandis que `lib/services/backup_service.dart:133` et `lib/data/migration/migration_service.dart:308` le lisent depuis `AppSettings` en base. La source de vérité retenue est `SharedPreferences` (c'est elle que lit déjà `card_detail_controller.dart:160`), la base n'en étant qu'un miroir pour la sauvegarde.

**Files:**
- Create: `lib/providers/preferred_language_provider.dart`
- Modify: `lib/pages/glossary/glossary_page.dart:72`
- Test: `test/providers/preferred_language_provider_test.dart` (créer)

**Interfaces:**
- Consumes: `AppDatabase.enqueueTranslation`, `AppDatabase.getCardPrint`, `AppDatabase.findTranslation`, `AppDatabase.isTranslationAbsent` (Task 3) ; `TranslationWorker.drain()` (Task 5).
- Produces:
  - `Future<String> readPreferredLanguage()` — rend `glossaryLang`, défaut `'fr'`.
  - `Future<void> writePreferredLanguage(AppDatabase db, String lang)`.
  - `Future<int> enqueueOwnedCardsForLanguage({required AppDatabase db, required String lang})` — enfile les traductions manquantes des cartes présentes dans un deck ou dans la collection, et rend le nombre de tâches créées.

- [ ] **Step 1: Write the failing test**

Créer `test/providers/preferred_language_provider_test.dart` :

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/providers/preferred_language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String oracleId = 'oracle-thrill',
}) =>
    DbCardPrint(
      scryfallId: scryfallId,
      oracleId: oracleId,
      setCode: 'eld',
      collectorNumber: '146',
      lang: lang,
      printedName: 'Thrill of Possibility',
      printedText: null,
      imageUri: null,
      fetchedAt: DateTime.utc(2026, 9, 17),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('readPreferredLanguage', () {
    test('rend fr par defaut', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await readPreferredLanguage(), 'fr');
    });

    test('rend la langue enregistree', () async {
      SharedPreferences.setMockInitialValues({'glossaryLang': 'it'});
      expect(await readPreferredLanguage(), 'it');
    });
  });

  group('enqueueOwnedCardsForLanguage', () {
    setUp(() async {
      await db.into(db.decks).insert(DecksCompanion.insert(id: 'deck-1', name: 'Test'));
      await db.into(db.deckCards).insert(DeckCardsCompanion.insert(
            deckId: 'deck-1',
            board: 'main',
            scryfallId: 'en-id',
            name: 'Thrill of Possibility',
          ));
      await db.upsertCardPrint(_print(scryfallId: 'en-id', lang: 'en'));
    });

    test('enfile les cartes d un deck dans la nouvelle langue', () async {
      final queued = await enqueueOwnedCardsForLanguage(db: db, lang: 'fr');

      expect(queued, 1);
      final tasks = await db.nextTranslationTasks();
      expect(tasks, hasLength(1));
      expect(tasks.first.lang, 'fr');
    });

    test('n enfile pas une carte deja dans la bonne langue', () async {
      final queued = await enqueueOwnedCardsForLanguage(db: db, lang: 'en');

      expect(queued, 0);
      expect(await db.nextTranslationTasks(), isEmpty);
    });

    test('n enfile pas une traduction deja en cache', () async {
      await db.upsertCardPrint(_print(scryfallId: 'fr-id', lang: 'fr'));

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 0);
    });

    test('n enfile pas une absence deja connue', () async {
      await db.markTranslationAbsent('oracle-thrill', 'fr');

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 0);
    });

    test('ne touche a rien hors deck et collection', () async {
      // Un tirage en cache qui n'est dans aucun deck ni collection.
      await db.upsertCardPrint(
          _print(scryfallId: 'orphelin', lang: 'en', oracleId: 'oracle-autre'));

      expect(await enqueueOwnedCardsForLanguage(db: db, lang: 'fr'), 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/preferred_language_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../preferred_language_provider.dart'`.

- [ ] **Step 3: Write minimal implementation**

Créer `lib/providers/preferred_language_provider.dart` :

```dart
// La langue preferee des cartes, et le backfill qu'un changement declenche.
//
// Portee du backfill : uniquement les cartes presentes dans un deck ou dans la
// collection. Traduire tout le cache couterait des milliers de requetes dont la
// plupart ne seraient jamais regardees.

import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';

const String kPreferredLanguageKey = 'glossaryLang';
const String kDefaultLanguage = 'fr';

/// Langue d'affichage des cartes. Partagee avec le glossaire.
Future<String> readPreferredLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kPreferredLanguageKey) ?? kDefaultLanguage;
}

/// Enregistre la langue preferee, dans les preferences et dans son miroir en
/// base (que lit le service de sauvegarde).
Future<void> writePreferredLanguage(AppDatabase db, String lang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPreferredLanguageKey, lang);
  await db.setSetting(kPreferredLanguageKey, lang);
}

/// Enfile les traductions manquantes des cartes possedees. Rend le nombre de
/// taches creees.
Future<int> enqueueOwnedCardsForLanguage({
  required AppDatabase db,
  required String lang,
}) async {
  final deckRows = await db.select(db.deckCards).get();
  final collectionRows = await db.select(db.collectionCards).get();

  final ownedIds = <String>{
    ...deckRows.map((r) => r.scryfallId),
    ...collectionRows.map((r) => r.scryfallId),
  };

  int queued = 0;
  for (final scryfallId in ownedIds) {
    final owned = await db.getCardPrint(scryfallId);
    if (owned == null) continue;
    if (owned.lang == lang) continue;
    if (await db.findTranslation(owned.oracleId, lang) != null) continue;
    if (await db.isTranslationAbsent(owned.oracleId, lang)) continue;

    await db.enqueueTranslation(
      scryfallId: owned.scryfallId,
      setCode: owned.setCode,
      collectorNumber: owned.collectorNumber,
      lang: lang,
    );
    queued++;
  }

  return queued;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/preferred_language_provider_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Brancher le changement de langue**

Dans `lib/pages/glossary/glossary_page.dart:72`, remplacer l'écriture directe

```dart
    await prefs.setString('glossaryLang', newLang);
```

par un passage via le provider, suivi du backfill et d'un drain non bloquant :

```dart
    await writePreferredLanguage(db, newLang);
    await enqueueOwnedCardsForLanguage(db: db, lang: newLang);
    unawaited(translationWorker.drain()); // ne bloque pas le changement de langue
```

Importer `dart:async` pour `unawaited`. Récupérer `db` et `translationWorker` depuis les providers Riverpod de `lib/providers/service_providers.dart`, en suivant le style de déclaration déjà en place dans ce fichier.

- [ ] **Step 6: Run the whole suite**

Run: `flutter test`
Expected: PASS sur l'ensemble.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/preferred_language_provider.dart lib/pages/glossary/glossary_page.dart test/providers/preferred_language_provider_test.dart
git commit -m "feat(i18n): promouvoir glossaryLang en langue des cartes et relancer le backfill"
```

## Ce que le plan ne couvre pas

- **L'optimisation du backfill par set** (`q=set:<code> lang:<lang>`, 175 cartes par requête). Le chemin unitaire suffit pour l'import et le scan ; l'optimisation se justifie seulement quand une grosse collection change de langue. À planifier séparément si le besoin se confirme.
- **Le link Moxfield.** Spec séparée, sondes déjà consignées dans la section « Hors périmètre » du design.
- **Le téléchargement du bulk `all_cards`.**
