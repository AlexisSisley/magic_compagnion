# Sprint 10 - Architecture Technique : Import/Export & Legalite
> Agent : Sanji (Architecte) | Date : 01/03/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : Import multi-format (TXT, CSV), export multi-format (TXT, CSV, clipboard), verification legalite par format, tags collection
- **Exclu** : Import depuis URL, export vers API tierces, legalite temps reel, import .dec/.dek, EDHREC

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter 3.35.6
- **State Management** : Riverpod (StateNotifier + AutoDispose)
- **Base de donnees** : drift (SQLite)
- **Navigation** : go_router
- **HTTP** : Dio + cache memoire + rate limiting (ScryfallApiService)
- **CI/CD** : GitHub Actions
- **Tests** : 298 tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 298 tests verts en permanence
- Import de 100 cartes en < 10s (batch API /cards/collection par 75)
- Legalite calculee localement (0 requete API supplementaire)
- Budget API Scryfall : respecter le rate limit 10 req/sec

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

---

## Phase 2 : Choix Techniques

| Choix | Decision | Justification |
|-------|----------|---------------|
| Parser de decklists | Nouveau service dedie `DeckFormatService` | Separe de la logique UI, reutilisable pour import et export, testable isolement |
| Resolution noms | `ScryfallApiService.fetchCollection` avec identifiers par nom | Batch API (75 max), deja en place et cache |
| Export fichier | `share_plus` + `path_provider` (deja dans le projet) | Meme pattern que `BackupService.exportData()` |
| Export clipboard | `Clipboard.setData` (package flutter/services) | Natif Flutter, pas de dependance supplementaire |
| Legalite | Methode dans `DeckDetailController` + modele `LegalityReport` | Calcul local sur `fullCardData`, pas de requete API |
| Tags collection | Extension `CollectionService.upsertCardInCollection(newTags:)` | Le parametre existe deja, juste besoin d'UX |
| Formats CSV | Package `csv` (deja standard Flutter) | Parsing CSV robuste, gestion des guillemets et virgules |
| Pas de nouveau package | `share_plus`, `path_provider`, `file_picker` sont deja dans pubspec | Zero nouvelle dependance |

---

## Phase 3 : Architecture des Changements

### 3.1 US-10.1 + US-10.2 : Import/Export Multi-format

#### Nouveau service : `DeckFormatService`

```
lib/services/deck_format_service.dart (~300 lignes)
```

Ce service centralise le parsing et la generation de decklists dans differents formats.

```dart
/// Service de parsing/generation de decklists multi-format.
/// Gere TXT (Moxfield/MTGO), CSV (Archidekt), et texte brut.
class DeckFormatService {
  /// Resultat du parsing d'une decklist.
  static DecklistParseResult parseDecklistText(String text) { ... }

  /// Resultat du parsing d'un CSV.
  static DecklistParseResult parseDecklistCsv(String csvContent) { ... }

  /// Detecte automatiquement le format (TXT vs CSV) et parse.
  static DecklistParseResult autoDetectAndParse(String content) { ... }

  /// Genere le texte au format TXT (Moxfield/MTGO compatible).
  static String exportToTxt(Deck deck) { ... }

  /// Genere le contenu au format CSV.
  static String exportToCsv(Deck deck) { ... }
}

/// Resultat intermediaire du parsing.
class DecklistParseResult {
  final List<DecklistEntry> mainboard;
  final List<DecklistEntry> sideboard;
  final String? commanderName;
  final Map<String, List<String>> cardTags; // nom -> tags (depuis CSV Archidekt)
  final List<String> warnings;
  final bool hasErrors;

  const DecklistParseResult({ ... });
}

class DecklistEntry {
  final String name;
  final int quantity;
  final String section; // 'mainboard', 'sideboard', 'commander'

  const DecklistEntry({ ... });
}
```

#### Algorithme de parsing TXT

```dart
static DecklistParseResult parseDecklistText(String text) {
  final List<DecklistEntry> mainboard = [];
  final List<DecklistEntry> sideboard = [];
  String? commanderName;
  String section = 'mainboard';
  final List<String> warnings = [];

  final regex = RegExp(r'^(\d+)x?\s+(.+)$');

  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty) continue;

    // Detection des sections
    final lowerLine = line.toLowerCase();
    if (lowerLine.startsWith('commander')) { section = 'commander'; continue; }
    if (lowerLine.startsWith('deck') || lowerLine.startsWith('mainboard') || lowerLine.startsWith('main board')) { section = 'mainboard'; continue; }
    if (lowerLine.startsWith('sideboard') || lowerLine.startsWith('side board') || lowerLine.startsWith('sb:')) { section = 'sideboard'; continue; }
    if (lowerLine.startsWith('considering') || lowerLine.startsWith('maybeboard') || lowerLine.startsWith('maybe')) continue; // Ignorer
    if (lowerLine.startsWith('//') || lowerLine.startsWith('#')) continue; // Commentaires

    final match = regex.firstMatch(line);
    if (match == null) {
      warnings.add('Ligne ignoree: $line');
      continue;
    }

    final qty = int.parse(match.group(1)!);
    // Nettoyer le nom : retirer set codes entre parentheses, // face arriere
    String name = match.group(2)!
        .split('//')[0]  // Retirer face arriere double-face
        .replaceAll(RegExp(r'\s*\([A-Z0-9]+\)\s*$'), '')  // Retirer (SET)
        .replaceAll(RegExp(r'\s*\*F\*\s*$'), '')  // Retirer indicateur foil MTGO
        .trim();

    switch (section) {
      case 'commander':
        commanderName = name;
        mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
        break;
      case 'sideboard':
        sideboard.add(DecklistEntry(name: name, quantity: qty, section: 'sideboard'));
        break;
      default:
        mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
    }
  }

  return DecklistParseResult(
    mainboard: mainboard,
    sideboard: sideboard,
    commanderName: commanderName,
    cardTags: {},
    warnings: warnings,
    hasErrors: false,
  );
}
```

#### Algorithme de parsing CSV

```dart
static DecklistParseResult parseDecklistCsv(String csvContent) {
  final List<DecklistEntry> mainboard = [];
  final List<DecklistEntry> sideboard = [];
  String? commanderName;
  final Map<String, List<String>> cardTags = {};
  final List<String> warnings = [];

  final lines = csvContent.split('\n');
  if (lines.isEmpty) return DecklistParseResult.empty();

  // Detecter les colonnes par header
  final header = lines.first.toLowerCase().split(',').map((h) => h.trim().replaceAll('"', '')).toList();
  final qtyIdx = header.indexWhere((h) => h == 'quantity' || h == 'qty' || h == 'count');
  final nameIdx = header.indexWhere((h) => h == 'name' || h == 'card' || h == 'card_name');
  final sectionIdx = header.indexWhere((h) => h == 'section' || h == 'board' || h == 'categories');

  if (qtyIdx == -1 || nameIdx == -1) {
    return DecklistParseResult.empty(warnings: ['CSV invalide: colonnes quantity/name introuvables']);
  }

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    // Parser CSV simple (gestion des guillemets)
    final cols = _parseCsvLine(line);
    if (cols.length <= nameIdx || cols.length <= qtyIdx) continue;

    final qty = int.tryParse(cols[qtyIdx].trim()) ?? 1;
    final name = cols[nameIdx].trim().replaceAll('"', '');
    final section = sectionIdx != -1 ? cols[sectionIdx].trim().toLowerCase() : 'mainboard';

    // Tags depuis Archidekt categories
    if (sectionIdx != -1 && cols[sectionIdx].contains(',')) {
      cardTags[name] = cols[sectionIdx]
          .replaceAll('"', '')
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }

    if (section.contains('side')) {
      sideboard.add(DecklistEntry(name: name, quantity: qty, section: 'sideboard'));
    } else if (section.contains('command')) {
      commanderName = name;
      mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
    } else {
      mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
    }
  }

  return DecklistParseResult(
    mainboard: mainboard, sideboard: sideboard,
    commanderName: commanderName, cardTags: cardTags,
    warnings: warnings, hasErrors: false,
  );
}
```

#### Generation export TXT

```dart
static String exportToTxt(Deck deck) {
  final sb = StringBuffer();

  // Commander section
  if (deck.commanderScryfallId != null) {
    sb.writeln('Commander');
    final cmdCard = deck.mainboard.firstWhere(
      (c) => c.scryfallId == deck.commanderScryfallId,
      orElse: () => DeckCard(scryfallId: '', name: 'Unknown', quantity: 1),
    );
    sb.writeln('1 ${cmdCard.name}');
    if (deck.commanderSecondaryScryfallId != null) {
      final partner = deck.mainboard.firstWhere(
        (c) => c.scryfallId == deck.commanderSecondaryScryfallId,
        orElse: () => DeckCard(scryfallId: '', name: 'Unknown', quantity: 1),
      );
      sb.writeln('1 ${partner.name}');
    }
    sb.writeln();
  }

  // Deck/Mainboard
  sb.writeln('Deck');
  for (final card in deck.mainboard) {
    if (card.scryfallId == deck.commanderScryfallId ||
        card.scryfallId == deck.commanderSecondaryScryfallId) continue;
    sb.writeln('${card.quantity} ${card.name}');
  }

  // Sideboard
  if (deck.sideboard.isNotEmpty) {
    sb.writeln();
    sb.writeln('Sideboard');
    for (final card in deck.sideboard) {
      sb.writeln('${card.quantity} ${card.name}');
    }
  }

  return sb.toString().trimRight();
}

static String exportToCsv(Deck deck) {
  final sb = StringBuffer();
  sb.writeln('quantity,name,section,scryfallId,tags');

  void writeCards(List<DeckCard> cards, String section) {
    for (final card in cards) {
      final tagsStr = card.tags.join(';');
      sb.writeln('${card.quantity},"${card.name}",$section,${card.scryfallId},"$tagsStr"');
    }
  }

  writeCards(deck.mainboard, 'mainboard');
  writeCards(deck.sideboard, 'sideboard');
  writeCards(deck.considering, 'considering');
  writeCards(deck.wishlist, 'wishlist');

  return sb.toString().trimRight();
}
```

#### Integration dans `DeckListController`

Refactorer `importDeck()` pour utiliser `DeckFormatService` :

```dart
Future<DeckListActionResult> importDeckFromText(String deckName, String content) async {
  state = state.copyWith(isImporting: true, isLoading: true);

  // 1. Parser auto-detect (TXT ou CSV)
  final parsed = DeckFormatService.autoDetectAndParse(content);

  if (parsed.mainboard.isEmpty && parsed.sideboard.isEmpty) {
    state = state.copyWith(isImporting: false, isLoading: false);
    return const DeckListActionResult(success: false, message: 'Aucune carte trouvee dans le fichier.');
  }

  // 2. Resoudre les noms via Scryfall
  final allNames = [
    ...parsed.mainboard.map((e) => e.name),
    ...parsed.sideboard.map((e) => e.name),
  ].toSet().toList();

  List<ScryfallCard> scryfallData = await _resolveCardNames(allNames);

  // 3. Creer le deck
  await _deckService.createNewDeck(deckName);
  final decks = await _deckService.loadDecks();
  Deck newDeck = decks.firstWhere((d) => d.name == deckName);

  // 4. Peupler mainboard
  newDeck.mainboard = parsed.mainboard.map((e) => DeckCard(
    scryfallId: _findId(scryfallData, e.name),
    name: e.name,
    quantity: e.quantity,
    tags: parsed.cardTags[e.name] ?? [],
  )).toList();

  // 5. Peupler sideboard
  newDeck.sideboard = parsed.sideboard.map((e) => DeckCard(
    scryfallId: _findId(scryfallData, e.name),
    name: e.name,
    quantity: e.quantity,
  )).toList();

  // 6. Commander
  if (parsed.commanderName != null) {
    newDeck.commanderScryfallId = _findId(scryfallData, parsed.commanderName!);
    newDeck.format = 'Commander';
  }

  // 7. Couleurs
  Set<String> deckColors = {};
  for (var sc in scryfallData) deckColors.addAll(sc.colorIdentity);
  final order = {'W':0, 'U':1, 'B':2, 'R':3, 'G':4, 'C':5};
  newDeck.colors = deckColors.toList()..sort((a,b) => (order[a]??9).compareTo(order[b]??9));

  await _deckService.updateDeck(newDeck);
  state = state.copyWith(isImporting: false, isLoading: false);
  await loadDecks();

  final unresolvedCount = newDeck.mainboard.where((c) => c.scryfallId.startsWith('LOCAL:')).length +
      newDeck.sideboard.where((c) => c.scryfallId.startsWith('LOCAL:')).length;

  String msg = 'Deck importe avec succes (${newDeck.mainboard.length + newDeck.sideboard.length} cartes)';
  if (unresolvedCount > 0) msg += '\n$unresolvedCount carte(s) non trouvee(s) sur Scryfall';
  if (parsed.warnings.isNotEmpty) msg += '\n${parsed.warnings.length} avertissement(s)';

  return DeckListActionResult(message: msg);
}

/// Resout les noms de cartes via l'API Scryfall par batch de 75.
Future<List<ScryfallCard>> _resolveCardNames(List<String> names) async {
  List<ScryfallCard> results = [];
  const chunkSize = 75;

  for (var i = 0; i < names.length; i += chunkSize) {
    final end = (i + chunkSize < names.length) ? i + chunkSize : names.length;
    final batch = names.sublist(i, end);
    final identifiers = batch.map((n) => {'name': n}).toList();

    try {
      final data = await _apiService.fetchCollection(identifiers);
      final cards = (data['data'] as List).map((j) => ScryfallCard.fromJson(j)).toList();
      results.addAll(cards);
    } catch (e) {
      log("Erreur resolution noms batch: $e");
    }
    if (i + chunkSize < names.length) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  return results;
}
```

#### Integration dans `DeckDetailController` (export)

```dart
/// Exporte le deck au format TXT.
String exportAsTxt() => DeckFormatService.exportToTxt(state.currentDeck);

/// Exporte le deck au format CSV.
String exportAsCsv() => DeckFormatService.exportToCsv(state.currentDeck);
```

#### Nouveau widget : modal d'import

```
lib/widgets/decks/deck_import_modal.dart (~180 lignes)
```

Modal avec 2 onglets :
1. **Coller du texte** : TextField multi-lignes + bouton "Importer"
2. **Depuis un fichier** : FilePicker pour .txt/.csv

#### Integration dans `DeckListPage`

Ajouter un bouton "Importer" dans la page decks :
- FAB menu avec "Nouveau deck" et "Importer un deck"
- Le bouton ouvre le `DeckImportModal`

#### Modification de `DeckDetailPage` (export)

Ajouter dans le menu contextuel du deck :
- "Exporter en TXT" -> genere et partage via Share
- "Exporter en CSV" -> genere et partage via Share
- "Copier la decklist" -> copie le TXT dans le clipboard

---

### 3.2 US-10.3 : Verification de Legalite

#### Nouveau modele : `LegalityReport`

```
lib/models/legality_report.dart (~100 lignes)
```

```dart
/// Rapport de legalite d'un deck pour un format donne.
class FormatLegalityResult {
  final String format;
  final LegalityStatus status; // legal, illegal, unknown
  final List<String> violations;
  final int totalCards;
  final int illegalCards;
  final int bannedCards;
  final int restrictedCards; // Pour Vintage

  const FormatLegalityResult({ ... });
}

enum LegalityStatus { legal, illegal, unknown }

/// Rapport complet couvrant tous les formats.
class LegalityReport {
  final List<FormatLegalityResult> results;
  final int unresolvedCards; // Cartes sans scryfallId
  final DateTime generatedAt;

  const LegalityReport({ ... });

  FormatLegalityResult? getFormat(String format) =>
    results.firstWhere((r) => r.format == format, orElse: () => null);
}
```

#### Nouveau service : `LegalityService`

```
lib/services/legality_service.dart (~250 lignes)
```

```dart
/// Service de verification de legalite de deck.
/// Fonctionne 100% localement sur les donnees deja chargees (fullCardData).
class LegalityService {

  /// Formats verifies avec leurs regles.
  static const Map<String, FormatRules> formatRules = {
    'standard':  FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false),
    'pioneer':   FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false),
    'modern':    FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false),
    'legacy':    FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false),
    'vintage':   FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false, hasRestricted: true),
    'pauper':    FormatRules(minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false),
    'commander': FormatRules(minMainboard: 100, maxSideboard: 0, maxCopies: 1, singleton: true, exactMainboard: true, requiresCommander: true, checksColorIdentity: true),
    'brawl':     FormatRules(minMainboard: 60, maxSideboard: 0, maxCopies: 1, singleton: true, exactMainboard: true, requiresCommander: true, checksColorIdentity: true),
  };

  /// Genere un rapport de legalite complet pour un deck.
  static LegalityReport generateReport({
    required Deck deck,
    required List<ScryfallCard> fullCardData,
  }) {
    final unresolvedCards = deck.mainboard.where((c) => c.scryfallId.startsWith('LOCAL:')).length +
        deck.sideboard.where((c) => c.scryfallId.startsWith('LOCAL:')).length;

    final results = formatRules.entries.map((entry) {
      return _checkFormat(
        format: entry.key,
        rules: entry.value,
        deck: deck,
        fullCardData: fullCardData,
      );
    }).toList();

    return LegalityReport(
      results: results,
      unresolvedCards: unresolvedCards,
      generatedAt: DateTime.now(),
    );
  }

  static FormatLegalityResult _checkFormat({
    required String format,
    required FormatRules rules,
    required Deck deck,
    required List<ScryfallCard> fullCardData,
  }) {
    final List<String> violations = [];
    int illegalCards = 0;
    int bannedCards = 0;
    int restrictedCards = 0;

    final totalMainboard = deck.mainboard.fold(0, (s, c) => s + c.quantity);
    final totalSideboard = deck.sideboard.fold(0, (s, c) => s + c.quantity);

    // 1. Taille du deck
    if (rules.exactMainboard) {
      if (totalMainboard != rules.minMainboard) {
        violations.add('Mainboard : $totalMainboard cartes (${rules.minMainboard} requises)');
      }
    } else {
      if (totalMainboard < rules.minMainboard) {
        violations.add('Mainboard : $totalMainboard cartes (minimum ${rules.minMainboard})');
      }
    }

    // 2. Taille sideboard
    if (totalSideboard > rules.maxSideboard) {
      violations.add('Sideboard : $totalSideboard cartes (maximum ${rules.maxSideboard})');
    }

    // 3. Commander requis
    if (rules.requiresCommander && deck.commanderScryfallId == null) {
      violations.add('Commandant manquant');
    }

    // 4. Verifier chaque carte
    // Map scryfallId -> ScryfallCard pour lookup rapide
    final cardDataMap = {for (var c in fullCardData) c.id: c};

    // Commander color identity
    Set<String>? commanderIdentity;
    if (rules.checksColorIdentity && deck.commanderScryfallId != null) {
      final cmdCard = cardDataMap[deck.commanderScryfallId];
      if (cmdCard != null) {
        commanderIdentity = cmdCard.colorIdentity.toSet();
        // Add partner identity
        if (deck.commanderSecondaryScryfallId != null) {
          final partner = cardDataMap[deck.commanderSecondaryScryfallId];
          if (partner != null) commanderIdentity.addAll(partner.colorIdentity);
        }
      }
    }

    // Group cards by name for copy count
    final Map<String, int> cardCounts = {};
    for (final card in [...deck.mainboard, ...deck.sideboard]) {
      if (card.scryfallId.startsWith('LOCAL:')) continue;
      cardCounts[card.name] = (cardCounts[card.name] ?? 0) + card.quantity;
    }

    for (final card in [...deck.mainboard, ...deck.sideboard]) {
      if (card.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardDataMap[card.scryfallId];
      if (scryfallCard == null) continue;

      // 4a. Legality status
      final status = scryfallCard.legalities[format] ?? 'not_legal';
      if (status == 'banned') {
        bannedCards++;
        violations.add('Carte bannie : ${card.name}');
      } else if (status == 'not_legal') {
        illegalCards++;
        violations.add('Carte non legale : ${card.name}');
      } else if (status == 'restricted' && rules.hasRestricted) {
        if (card.quantity > 1) {
          restrictedCards++;
          violations.add('Carte restreinte en exces : ${card.name} (${card.quantity} copies, max 1)');
        }
      }

      // 4b. Copy count
      final isBasicLand = scryfallCard.typeLine.toLowerCase().contains('basic land');
      final anyNumber = scryfallCard.rulesText.toLowerCase().contains('a deck can have any number');
      if (!isBasicLand && !anyNumber) {
        final count = cardCounts[card.name] ?? 0;
        if (count > rules.maxCopies) {
          // Add violation only once per card name
          final violationMsg = '${card.name} : $count copies (max ${rules.maxCopies})';
          if (!violations.contains(violationMsg)) violations.add(violationMsg);
        }
      }

      // 4c. Color identity (Commander/Brawl)
      if (commanderIdentity != null) {
        for (final color in scryfallCard.colorIdentity) {
          if (!commanderIdentity.contains(color)) {
            violations.add('Hors identite de couleur : ${card.name} ($color)');
            break;
          }
        }
      }
    }

    final status = violations.isEmpty ? LegalityStatus.legal : LegalityStatus.illegal;

    return FormatLegalityResult(
      format: format,
      status: status,
      violations: violations,
      totalCards: totalMainboard + totalSideboard,
      illegalCards: illegalCards,
      bannedCards: bannedCards,
      restrictedCards: restrictedCards,
    );
  }
}

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
```

#### Integration dans `DeckDetailController`

Remplacer `validateDeckRules()` par la vraie verification :

```dart
/// Genere le rapport de legalite complet.
LegalityReport generateLegalityReport() {
  return LegalityService.generateReport(
    deck: state.currentDeck,
    fullCardData: state.fullCardData,
  );
}
```

#### Nouveau widget : `DeckLegalityTab`

```
lib/widgets/decks/deck_legality_tab.dart (~200 lignes)
```

Affiche le rapport sous forme de :
- Liste des 8 formats avec badges (vert/rouge/gris)
- ExpansionTile par format pour voir les violations
- Resume en haut : "Legal dans X formats, Illegal dans Y formats"

---

### 3.3 US-10.4 : Tags Collection

#### Modification de `CollectionController`

Ajouter les methodes de gestion de tags :

```dart
Future<void> updateCardTags(String scryfallId, List<String> tags, bool isFoil) async {
  await _collectionService.upsertCardInCollection(
    scryfallId: scryfallId,
    cardName: '', // pas de changement de nom
    isFoil: isFoil,
    newTags: tags,
  );
  await loadCollection();
}

Future<List<String>> getAllTags() async {
  return _collectionService.getAllUniqueTags();
}
```

#### Modification du filtre collection

Dans le `CollectionController`, ajouter le filtre par tags dans `_applyFilters()` :

```dart
if (state.activeFilters.tags.isNotEmpty) {
  tempCards = tempCards.where((card) {
    return state.activeFilters.tags.every((tag) => card.tags.contains(tag));
  }).toList();
}
```

#### Nouveau widget : `TagEditorDialog`

```
lib/widgets/common/tag_editor_dialog.dart (~120 lignes)
```

Dialog avec :
- Chips des tags actuels de la carte (supprimables)
- Autocomplete TextField pour ajouter un tag
- Suggestions basees sur les tags existants dans la collection

#### Integration UI

| Fichier | Modification |
|---------|-------------|
| `collection_page.dart` ou `collection_list_tab.dart` | Long-press sur carte -> option "Gerer les tags" -> ouvre TagEditorDialog |
| Modal de filtres collection | Ajouter un chip selector pour les tags |

---

## Phase 4 : Architecture Fichiers Modifies/Crees

```
lib/
  services/
    deck_format_service.dart         NOUVEAU (~300 lignes) -- parser/generator multi-format
    legality_service.dart            NOUVEAU (~250 lignes) -- verification legalite

  models/
    legality_report.dart             NOUVEAU (~100 lignes) -- modele rapport legalite

  controllers/
    deck_list_controller.dart        MODIFIE (refactor importDeck, ajouter import file/text)
    deck_detail_controller.dart      MODIFIE (remplacer validateDeckRules, ajouter export)
    collection_controller.dart       MODIFIE (ajouter gestion tags, filtre tags)

  widgets/
    decks/
      deck_import_modal.dart         NOUVEAU (~180 lignes) -- modal import
      deck_legality_tab.dart         NOUVEAU (~200 lignes) -- onglet legalite
    common/
      tag_editor_dialog.dart         NOUVEAU (~120 lignes) -- dialog edition tags

  pages/
    decks/
      deck_list_page.dart            MODIFIE (bouton import, menu export)
      deck_detail_page.dart          MODIFIE (onglet legalite, menu export)
    collections/
      collection_page.dart           MODIFIE (long-press tags, filtre tags)

test/
  services/
    deck_format_service_test.dart    NOUVEAU (~25 tests)
    legality_service_test.dart       NOUVEAU (~20 tests)
  controllers/
    deck_list_controller_test.dart   MODIFIE (tests import refactorise)
    deck_detail_controller_test.dart MODIFIE (tests legalite + export)
    collection_controller_test.dart  MODIFIE (tests tags)
```

---

## Phase 5 : Risques Techniques & Strategie de Test

### Risques

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| Parsing TXT varie entre apps (espaces, set codes, indicateurs foil) | Moyen | Haute | Regex tolerant, nettoyage agressif du nom, ignorer les annotations |
| Resolution noms echoue pour cartes en francais ou avec accents | Moyen | Haute | Essayer le nom original, puis le nom sans accents, puis fallback LOCAL: |
| CSV avec delimiteurs variables (virgule, point-virgule, tab) | Moyen | Moyenne | Auto-detection du delimiteur dans la premiere ligne |
| Legalite incorrecte pour nouvelles cartes (Scryfall pas a jour) | Faible | Faible | Les donnees viennent de Scryfall qui est generalement a jour sous 24h |
| Regression import existant (DeckListController.importDeck) | Haut | Faible | Refactorer en utilisant DeckFormatService, les tests existants valident |
| Performance export gros deck (100 cartes) | Faible | Faible | Generation en memoire, pas de I/O sauf au partage final |

### Strategie de Test

**Nouveaux tests Sprint 10** :

| Fichier test | Tests prevus | Type |
|-------------|-------------|------|
| deck_format_service_test.dart | 15 (parse TXT Moxfield, TXT MTGO, CSV, export TXT, export CSV, edge cases) | Unit |
| legality_service_test.dart | 12 (legal, illegal, banned, restricted, singleton, color identity, taille) | Unit |
| deck_list_controller_test.dart | 5 (import TXT, import CSV, import avec erreurs) | Unit |
| deck_detail_controller_test.dart | 3 (export TXT, export CSV, generateLegalityReport) | Unit |
| collection_controller_test.dart | 3 (updateTags, getAllTags, filtre tags) | Unit |
| **Total nouveaux** | **~38** | |
| **Total cumule** | **~336** | **(298 + 38)** |

---

## Plan d'Execution

### Phase 1 : Service de Formats (2j)

| # | Tache | Effort |
|---|-------|--------|
| 1 | Creer `DeckFormatService` avec parser TXT | 0.5j |
| 2 | Ajouter parser CSV | 0.5j |
| 3 | Ajouter export TXT et CSV | 0.25j |
| 4 | Ajouter auto-detection de format | 0.15j |
| 5 | Tests DeckFormatService (15 tests) | 0.6j |

### Phase 2 : Import Integration (2j)

| # | Tache | Effort |
|---|-------|--------|
| 6 | Refactorer `DeckListController.importDeck()` pour utiliser `DeckFormatService` | 0.5j |
| 7 | Ajouter `_resolveCardNames()` batch | 0.25j |
| 8 | Creer `DeckImportModal` (coller texte + fichier) | 0.5j |
| 9 | Integrer dans `DeckListPage` (bouton import, file picker) | 0.25j |
| 10 | Tests integration import (5 tests) | 0.5j |

### Phase 3 : Export Integration (1j)

| # | Tache | Effort |
|---|-------|--------|
| 11 | Ajouter `exportAsTxt()` et `exportAsCsv()` dans `DeckDetailController` | 0.15j |
| 12 | Modifier `DeckDetailPage` : menu export (TXT, CSV, clipboard) | 0.35j |
| 13 | Utiliser `share_plus` pour le partage de fichiers | 0.25j |
| 14 | Tests export (3 tests) | 0.25j |

### Phase 4 : Legalite (2j)

| # | Tache | Effort |
|---|-------|--------|
| 15 | Creer `LegalityReport` modele | 0.15j |
| 16 | Creer `LegalityService` avec regles 8 formats | 0.5j |
| 17 | Integrer dans `DeckDetailController` (remplacer validateDeckRules) | 0.15j |
| 18 | Creer `DeckLegalityTab` widget | 0.5j |
| 19 | Integrer onglet dans `DeckDetailPage` | 0.2j |
| 20 | Tests legalite (12 tests) | 0.5j |

### Phase 5 : Tags Collection (1j)

| # | Tache | Effort |
|---|-------|--------|
| 21 | Modifier `CollectionController` pour gestion tags | 0.15j |
| 22 | Creer `TagEditorDialog` | 0.35j |
| 23 | Integrer dans la page collection (long-press, filtre) | 0.25j |
| 24 | Tests tags (3 tests) | 0.25j |

### Phase 6 : Integration finale (1j)

| # | Tache | Effort |
|---|-------|--------|
| 25 | Tests regression (flutter test complet) | 0.25j |
| 26 | flutter analyze (0 errors) | 0.15j |
| 27 | Test manuel end-to-end (import -> edit -> export -> legalite) | 0.35j |
| 28 | Documentation : mise a jour ROADMAP | 0.25j |

---

## Metriques Cibles Sprint 10

| Metrique | Sprint 9 (actuel) | Cible Sprint 10 |
|----------|-------------------|-----------------|
| Tests | 298 | **>= 330** |
| Fichiers modifies | - | ~8 |
| Fichiers crees | - | 6 (service, modele, 3 widgets, service) |
| Formats d'import | 1 (TXT basique) | **3** (TXT Moxfield, TXT MTGO, CSV) |
| Formats d'export | 0 (copier texte seul) | **3** (TXT, CSV, clipboard) |
| Formats de legalite | 4 (affichage carte) | **8** (verification deck) |
| Score qualite | 9.0/10 | **9.0/10** (pas de regression, features ajoutees) |

*"Les meilleurs plats sont ceux qui utilisent des ingredients deja dans le garde-manger. Les legalities sont dans ScryfallCard, le parser de decklists existe, les tags sont dans drift, le partage est dans share_plus. Il suffit de cuisiner intelligemment -- et voila 4 features servies en 9 jours. L'import ouvre la porte aux joueurs migrants. L'export les laisse libres. La legalite leur donne confiance. Les tags, c'est le sel qui releve tout le plat."* -- Sanji
