# Chantier C — Bibliothèque de decks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refaire l'écran « Mes decks » : tuiles illustrées par l'art du commandant, grille de 1 à 3 colonnes, barre de filtres avec compteur et tri étendu, tags de deck (« dossiers ») persistés, sans texture de fond.

**Architecture:** Le filtrage et le tri sortent du contrôleur dans une fonction pure testable (`applyDeckFilters`), parce que `DeckListPage` n'est pas montable en test (`LocalCardService` est un singleton qui parse 166 Mo). La page se réduit à de l'assemblage : en-tête, barre de filtres, `DeckLibraryGrid`. Le schéma Drift passe en v5 (`decks.tags`, `decks.updatedAt`).

**Tech Stack:** Flutter 3.9+, Riverpod 3 (`StateNotifier` legacy), Drift 2 (fichiers `.g.dart` commités, régénérés par `dart run build_runner build --delete-conflicting-outputs`), `cached_network_image` via `ScryfallImage`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md` §2 (chantier C), §6.1 et §6.2 (critères de sortie), §7 (hors périmètre). Maquette : canevas de design, artboard `DeckLibrary` (décrit dans « Maquette » ci-dessous : les subagents ne peuvent pas l'ouvrir).

## Global Constraints

- Libellés en français, accentués, sans emoji.
- Couleurs uniquement via `AppColors` / `MagicPalette`. Aucune couleur de joueur en dur : `test/widgets/life_counter/player_skins_test.dart` balaie `lib/`. Le `Colors.red.shade900` du fond de glissement est exempté par chemin de fichier (`shadeGuardExemptions`) : s'il change de fichier, mettre l'exemption à jour.
- Aucune cible tactile sous 48×48.
- Chaque test ajouté est discriminant : casser la ligne de production couverte, constater l'échec, rétablir.
- Le `Dismissible` de suppression est conservé tel quel, libellé compris (« USE THE FORCE », dialogue « Supprimer ? » / « Non » / « Oui », SnackBar « La Force a effacé ce deck. ») — spec §2.1.
- La tuile ne change pas de forme selon les données : avec ou sans commandant, avec ou sans couleurs, même hauteur, mêmes emplacements (spec §2.1).
- Seuils de grille exacts : < 600 dp → 1 colonne ; 600–999 dp → 2 ; ≥ 1000 dp → 3 (spec §2.2), appliqués à la largeur DISPONIBLE (`LayoutBuilder`), pas à l'écran.
- Migration Drift : un deck existant migre avec `tags` vide, et ses cartes ne perdent ni tags ni quantités (spec §2.4, §6.1).
- `flutter test` et `flutter analyze` avant chaque commit. Baseline au départ du chantier : 1524 passés, 6 ignorés ; 166 problèmes d'analyse préexistants, n'en ajouter aucun.
- Worktree neuf : lier `assets/json/oracle-cards.json` en lien dur depuis le dépôt principal, sinon aucun test ne se construit.

## Maquette (artboard `DeckLibrary`, 840×700, deux colonnes)

- En-tête : titre « Mes decks » (Cinzel 24), bouton icône d'import à droite. Champ « Rechercher un deck » dessous.
- Barre de filtres : pilule « Filtres » (icône trois traits, bordure et texte or `AppColors.primary`, badge rond or portant le nombre de filtres actifs), puis une puce neutre par filtre actif (« Commander », « Sous 300 € »), un espace, puis à droite la pilule de tri (« Nom (A-Z) » + chevron).
- Tuile : coins 8, fond `cardBackground`, bordure `borderSubtle`. Zone d'art plein cadre, badge de format en haut à droite (fond or, texte sombre, majuscules, 10 px gras). Dégradé sombre en pied, qui porte : nom (Cinzel 18), rangée de pastilles de couleur (ronds de 13 px aux couleurs de mana), puis « 107 cartes · 289 € » (compte en `textSecondary`, prix en or gras).
- Deck sans commandant : même structure, art remplacé par un fond neutre uni et une icône de deck au trait, rangée de pastilles vide mais gardant sa hauteur.
- Bouton flottant « Nouveau deck » (pilule or, icône +).

## Review Focus

1. **Fourchette de prix et decks sans prix connu** (prix 0 ou absent) : avec une fourchette active, un deck dont le prix est inconnu ne doit pas disparaître silencieusement comme s'il valait 0 € → il reste visible si la borne basse vaut 0 (test en tâche 3).
2. **Filtres qui ne laissent aucun deck** : l'utilisateur doit voir pourquoi la liste est vide et pouvoir tout effacer d'un appui (état vide filtré, tâche 6).
3. **Tag supprimé du dernier deck qui le portait** alors qu'il est sélectionné dans les filtres : le filtre ne doit pas rester actif sur un tag fantôme (tâche 3, `pruneSelectedTags`).
4. **Tri par date de modification avec des decks antérieurs à la migration** (`updatedAt` nul) : ordre stable, les decks datés d'abord, les autres ensuite par nom (tâche 3).
5. **Sauvegarde puis restauration** : les tags et la date de modification survivent à un aller-retour `BackupService` (tâche 2).

---

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/models/deck_model.dart` | **Modifié.** `Deck.tags`, `Deck.updatedAt`. | 1 |
| `lib/data/database/app_database.dart` (+ `.g.dart`) | **Modifié.** v5 : `decks.tags`, `decks.updatedAt` ; `upsertDeckCard` transmet `proxyQuantity`. | 1, 2 |
| `test/data/app_database_migration_v5_test.dart` | **Créé.** Ouvre une base v4 écrite à la main, vérifie la montée en v5. | 1 |
| `lib/services/deck_service.dart` | **Modifié.** Lecture/écriture des tags et de `updatedAt`, horodatage à chaque écriture, `proxyQuantity` et `isFoil` préservés. | 2 |
| `lib/services/backup_service.dart`, `lib/data/migration/migration_service.dart` | **Modifiés.** Tags et `updatedAt` exportés/restaurés. | 2 |
| `lib/controllers/deck_list_filters.dart` | **Créé.** `DeckSort`, `DeckFilterCriteria`, `applyDeckFilters`, compteur de filtres actifs. | 3 |
| `lib/controllers/deck_list_controller.dart` | **Modifié.** État élargi, délègue à `applyDeckFilters`, `updateDeckTags`. | 3, 7 |
| `lib/widgets/decks/deck_list_card.dart` | **Réécrit.** Tuile 16:9. | 4 |
| `lib/widgets/decks/deck_library_grid.dart` | **Créé.** Grille responsive + état vide filtré. | 5 |
| `lib/widgets/decks/deck_filter_bar.dart` | **Créé.** Pilule Filtres + puces actives + tri. | 6 |
| `lib/widgets/decks/deck_filter_sheet.dart` | **Créé.** Feuille de filtres. | 6 |
| `lib/widgets/decks/deck_tags_sheet.dart` | **Créé.** Édition des tags d'un deck. | 7 |
| `lib/pages/decks/deck_list_page.dart` | **Modifié.** Fond opaque, assemblage, suppression des copies inline. | 4, 5, 6 |
| `test/captures/deck_library_captures_test.dart` | **Créé.** Captures §6.2 à 1, 2, 3 colonnes. | 8 |

---

## Task 1: Schéma v5 — tags et date de modification des decks

**Files:**
- Modify: `lib/models/deck_model.dart` (classe `Deck`, l.40-95)
- Modify: `lib/data/database/app_database.dart` (table `Decks` l.45-57, `schemaVersion` l.300, `onUpgrade` l.302-330) + régénérer `app_database.g.dart`
- Create: `test/data/app_database_migration_v5_test.dart`
- Modify: `test/models/deck_model_test.dart`

**Interfaces:**
- Produces: `Deck.tags: List<String>` (défaut `[]`, mutable comme les autres champs) ; `Deck.updatedAt: DateTime?` ; colonnes Drift `Decks.tags` (`text().withDefault(const Constant('[]'))`) et `Decks.updatedAt` (`dateTime().nullable()`) ; `schemaVersion == 5`.

- [ ] **Step 1: Tests du modèle**

Dans `deck_model_test.dart` : `Deck()` a `tags == []` et `updatedAt == null` ; aller-retour `toJson`/`fromJson` avec `tags: ['Casual', 'cEDH']` et `updatedAt: DateTime.utc(2026, 10, 19, 8)` (sérialisé en ISO 8601) ; un JSON SANS les clés `tags` et `updatedAt` se lit `[]` et `null`.

- [ ] **Step 2: Test de migration depuis une vraie base v4**

Aucun test de montée de schéma n'existe dans le projet : celui-ci crée le motif. Construire l'exécuteur avec `NativeDatabase.memory(setup: (raw) { ... })`, qui exécute à la main le DDL v4 des tables `decks` et `deck_cards` (copier les `CREATE TABLE` depuis le `.g.dart` AVANT modification, ou depuis `sqlite_master` d'une base v4 fraîche), insère un deck `('d1', 'Toph', 'Commander', 'cmdr-id', NULL, '["W","R","B"]')` et deux cartes du board `main` (l'une avec `tags='["Ramp"]'`, `quantity=2`, `proxy_quantity=1`, `is_foil=1`), puis pose `PRAGMA user_version = 4`. Ouvrir `AppDatabase(executor)` et vérifier :
  - `getAllDecksRaw()` rend le deck avec `tags == '[]'` et `updatedAt == null` ;
  - les deux cartes gardent `tags`, `quantity`, `proxyQuantity`, `isFoil` à l'identique ;
  - `PRAGMA user_version` vaut 5.
  Si les autres tables v4 sont exigées par `onUpgrade` (marches `< 2`, `< 3`, `< 4` sautées puisque `from == 4`), seules `decks` et `deck_cards` sont nécessaires.

- [ ] **Step 3: Lancer, constater l'échec**

Run: `flutter test test/data/app_database_migration_v5_test.dart test/models/deck_model_test.dart`
Expected: FAIL (champs et colonnes absents).

- [ ] **Step 4: Implémenter**

Modèle : champs, constructeur, `toJson` (`'tags'`, `'updatedAt': updatedAt?.toIso8601String()`), `fromJson` tolérant. Drift : les deux colonnes, `schemaVersion => 5`, marche `if (from < 5) { await m.addColumn(decks, decks.tags); await m.addColumn(decks, decks.updatedAt); }` sur le modèle de la marche `< 3` (`profiles.commanderGalleryJson`). Régénérer : `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Lancer, constater le succès, puis toute la suite**

Run: `flutter test test/data test/models` puis `flutter test` et `flutter analyze`
Expected: PASS ; analyse inchangée.

- [ ] **Step 6: Commit**

```bash
git add lib/models/deck_model.dart lib/data/database/app_database.dart lib/data/database/app_database.g.dart test/data/app_database_migration_v5_test.dart test/models/deck_model_test.dart
git commit -m "feat(decks): schema v5, tags et date de modification des decks"
```

---

## Task 2: Chemins d'écriture — tags, horodatage, proxys préservés

**Files:**
- Modify: `lib/services/deck_service.dart` (`_dbDeckToDeck` l.47-82, `createNewDeck` l.116-135, `updateDeck` l.143-171, `moveCard` l.250-266, `changeCardVersion` l.232-248, et toute méthode qui appelle `updateDeckEntry` ou `upsertDeckCard`)
- Modify: `lib/data/database/app_database.dart` (`upsertDeckCard` l.512-566)
- Modify: `lib/services/backup_service.dart` (export l.54-94, import l.236-258)
- Modify: `lib/data/migration/migration_service.dart` (l.111-117)
- Test: `test/services/deck_service_test.dart`, `test/data/app_database_test.dart` (groupe « Deck DAO »), `test/services/backup_service_test.dart` (créer s'il n'existe pas)

**Interfaces:**
- Consumes: Task 1.
- Produces: `AppDatabase.upsertDeckCard(..., {int? proxyQuantity})` — paramètre ajouté, écrit à l'insertion ET à la mise à jour quand il est fourni ; `DeckService` pose `updatedAt = DateTime.now()` à chaque écriture d'un deck ou de ses cartes ; `Future<void> DeckService.updateDeckTags(String deckId, List<String> tags)`.

Contexte : `updateDeck` vide toutes les cartes puis les réinsère sans `proxyQuantity`, et `moveCard` réinsère sans `isFoil` ni `proxyQuantity`. Un import Moxfield marque pourtant ses proxys. Ces pertes contredisent le critère §6.1 « ses cartes ne perdent ni tags ni quantités ».

- [ ] **Step 1: Tests**
  - Base en mémoire (`AppDatabase(NativeDatabase.memory())`) : `updateDeck` d'un deck dont une carte a `proxyQuantity: 2, isFoil: true, tags: ['Ramp']` → relu à l'identique.
  - `moveCard` main → side de cette carte : relue à l'identique dans `sideboard`.
  - `updateDeckTags('d1', ['Casual'])` → `loadDecks()` rend `tags == ['Casual']`.
  - Chaque écriture (`updateDeck`, `upsertCardInDeck`, `moveCard`, `setCommander`, `updateDeckTags`) fait avancer `updatedAt`. Injecter une horloge (`DateTime Function() now`, défaut `DateTime.now`, paramètre nommé du constructeur de `DeckService`) pour un test déterministe.
  - Sauvegarde : export puis import d'un deck avec `tags` et `updatedAt` → identiques. Un fichier de sauvegarde ANCIEN, sans ces clés, s'importe avec `[]` et `null`.

- [ ] **Step 2: Lancer, constater l'échec.** Run: `flutter test test/services/deck_service_test.dart test/data/app_database_test.dart test/services/backup_service_test.dart`

- [ ] **Step 3: Implémenter** le paramètre `proxyQuantity` de `upsertDeckCard`, sa transmission par `updateDeck`, `moveCard` (avec `isFoil`) et `changeCardVersion`, la lecture de `tags` (`AppDatabase.decodeTags`) et de `updatedAt` dans `_dbDeckToDeck`, l'horodatage via l'horloge injectée, `updateDeckTags`, puis les clés `tags` / `updatedAt` dans l'export, l'import et la migration SharedPreferences → Drift.

- [ ] **Step 4: Suite complète.** Run: `flutter test` puis `flutter analyze` — Expected: PASS, analyse inchangée.

- [ ] **Step 5: Commit**

```bash
git add lib/services/deck_service.dart lib/data/database/app_database.dart lib/services/backup_service.dart lib/data/migration/migration_service.dart test/services test/data
git commit -m "fix(decks): les ecritures preservent proxys, foils et tags, et horodatent le deck"
```

---

## Task 3: Filtres et tri purs

**Files:**
- Create: `lib/controllers/deck_list_filters.dart`
- Modify: `lib/controllers/deck_list_controller.dart` (`DeckListState` l.38-90, `_applyFilters` l.176-210, `updateSort`, `getSortLabel` l.570-576)
- Test: `test/controllers/deck_list_filters_test.dart` (créé), `test/controllers/deck_list_controller_test.dart` (groupe « DeckListState »)

**Interfaces:**
- Consumes: Task 1 (`Deck.tags`, `Deck.updatedAt`, `Deck.format`).
- Produces :
  - `enum DeckSort { name, priceDesc, priceAsc, updated, cardCount }` + `String deckSortLabel(DeckSort)` → « Nom (A-Z) », « Prix décroissant », « Prix croissant », « Modifié récemment », « Nombre de cartes ».
  - `class DeckFilterCriteria { final String query; final String? format; final List<String>? identityColors; final List<String> tags; final (double, double)? priceRange; final DeckSort sort; }` (const, `copyWith`).
  - `List<Deck> applyDeckFilters(List<Deck> decks, Map<String, double> prices, DeckFilterCriteria c)`.
  - `int activeFilterCount(DeckFilterCriteria c)` : un par filtre posé parmi format, identité, tags (un seul pour tous les tags), prix. La recherche et le tri ne comptent pas.
  - `List<String> pruneSelectedTags(List<String> selected, List<Deck> decks)`.
  - `DeckListState` gagne `selectedTags: List<String>` (défaut `[]`), `priceRange: (double, double)?`, et `copyWith(clearPriceRange: false, clearFormat: false, ...)` sur le modèle de `clearIdentity`. `selectedSort` devient un `DeckSort`.
  - `DeckListController` gagne `updateTags(List<String>)`, `updatePriceRange((double, double)?)`, `clearAllFilters()`, et `List<String> get availableTags` (union triée des tags de tous les decks).

Règles, une par test :
- Recherche : sous-chaîne du nom, insensible à la casse (inchangé).
- Format : égalité insensible à la casse avec `deck.format`. Ce n'est PLUS la présence d'un commandant : `Deck.format` est posé par l'import et par `setCommander` (« Commander »). La liste des formats proposés est l'union des `deck.format` présents.
- Identité : égalité exacte d'ensembles ; liste vide = incolore (inchangé).
- Tags : un deck passe s'il porte AU MOINS UN des tags sélectionnés (ce sont des dossiers : on regarde le contenu de plusieurs dossiers).
- Prix : `min <= prix <= max`. Un deck absent de `prices` vaut 0 : il passe donc tant que `min == 0` (Review Focus 1).
- Tri : `name` insensible à la casse ; `priceDesc` et `priceAsc` sur `prices` ; `updated` décroissant, les `null` en fin, départagés par nom (Review Focus 4) ; `cardCount` décroissant sur la somme des quantités du mainboard, départagé par nom.

- [ ] **Step 1: Écrire `deck_list_filters_test.dart`** : un test par règle ci-dessus, plus `activeFilterCount` (0 au départ ; format + 2 tags + prix → 3) et `pruneSelectedTags(['A', 'B'], decks portant seulement 'A')` → `['A']`.
- [ ] **Step 2: Lancer, constater l'échec.** Run: `flutter test test/controllers/deck_list_filters_test.dart`
- [ ] **Step 3: Implémenter** le fichier pur, puis brancher le contrôleur : `_applyFilters` délègue à `applyDeckFilters` ; après chaque `loadDecks`, `selectedTags = pruneSelectedTags(...)`. Adapter les tests existants de `DeckListState` (défaut `selectedSort == DeckSort.name`, `copyWith` des nouveaux champs).
- [ ] **Step 4: Suite complète + analyse** — Expected: PASS.
- [ ] **Step 5: Commit** `feat(decks): filtres par format, tags et prix, tri etendu`

---

## Task 4: La tuile

**Files:**
- Rewrite: `lib/widgets/decks/deck_list_card.dart`
- Modify: `lib/pages/decks/deck_list_page.dart` — supprimer `_buildDeckCard` (l.374-497) et `_getManaIcon` ; la page instancie `DeckListCard`. Le dialogue de confirmation reste fourni par la page.
- Modify: `test/widgets/life_counter/player_skins_test.dart` — exemptions : garder `deck_list_card.dart`, retirer `deck_list_page.dart` si le `Colors.red.shade900` n'y vit plus.
- Test: `test/widgets/decks/deck_list_card_test.dart` (créé)

**Interfaces:**
- Produces: `DeckListCard({required Deck deck, required double totalPrice, required VoidCallback onTap, VoidCallback? onLongPress, required Future<bool?> Function(DismissDirection) confirmDismiss, required VoidCallback onDismissed})`. `onLongPress` est consommé par la tâche 7.

Rendu (spec §2.1 et maquette) : une `AspectRatio(16 / 9)` dont l'art occupe tout le fond (`ScryfallImage(imageUrl: ScryfallApi.artCropRedirectUrl(deck.commanderScryfallId!), fit: BoxFit.cover)`). Sans commandant : fond uni `MagicPalette.of(context).raised` et icône de deck au trait centrée. Badge de format en haut à droite : `deck.format` en majuscules. Le dégradé de pied porte le nom (1 ligne, ellipse), la rangée de pastilles (ronds de 13 px colorés par `AppColors` mana W/U/B/R/G/C, PAS les SVG réseau : la tuile doit rester rendable hors ligne et en test ; hauteur réservée même si `colors` est vide), puis « n cartes · prix ». Le prix est formaté par `PriceHelper` (« ≈ 289 € » → « 289 € », arrondi à l'euro), « — » si inconnu. La pastille ronde de 50 px disparaît. Le `Dismissible` est inchangé.

- [ ] **Step 1: Tests de widget**
  - Avec et sans commandant, la tuile a la MÊME taille (`tester.getSize`) pour une largeur donnée, et le ratio vaut 16:9.
  - Sans commandant : aucun `ScryfallImage`, l'icône de deck est présente.
  - Le badge affiche `deck.format.toUpperCase()` (`'MODERN'` pour un deck Modern sans commandant).
  - « 107 cartes » vient de la somme des quantités du mainboard.
  - Glisser de droite à gauche affiche « USE THE FORCE » et appelle `confirmDismiss`.
  - `onLongPress` est appelé.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter** la tuile et brancher la page.
- [ ] **Step 4: Suite complète + analyse.** Le golden `23_grimoire_deck_list` de `test/captures/grimoire_captures_test.dart` change : le régénérer (`flutter test --tags capture --run-skipped --update-goldens test/captures/grimoire_captures_test.dart`) et le regarder.
- [ ] **Step 5: Commit** `feat(decks): tuile illustree par l'art du commandant`

---

## Task 5: Grille responsive, fond opaque, état vide

**Files:**
- Create: `lib/widgets/decks/deck_library_grid.dart`
- Modify: `lib/pages/decks/deck_list_page.dart` (`SliverList` l.195-203 → grille ; fond)
- Test: `test/widgets/decks/deck_library_grid_test.dart` (créé)

**Interfaces:**
- Consumes: Task 4 (`DeckListCard`), Task 3 (`clearAllFilters`, `activeFilterCount`).
- Produces :
  - `int deckLibraryColumns(double availableWidth)` : `< 600` → 1, `< 1000` → 2, sinon 3.
  - `DeckLibraryGrid({required List<Deck> decks, required Map<String, double> prices, required int activeFilters, required VoidCallback onClearFilters, required Widget Function(Deck) tileBuilder})`, un sliver qui mesure sa largeur avec `SliverLayoutBuilder` (`constraints.crossAxisExtent`).

La grille utilise un `SliverGrid` avec `mainAxisExtent` = largeur d'une colonne × 9 / 16 : la tuile est un 16:9 pur. Gouttières de 14, marges latérales de 20 (maquette). Liste vide :
- AVEC filtres actifs : « Aucun deck ne correspond aux filtres » + bouton « Effacer les filtres » (Review Focus 2).
- SANS filtre et sans deck : « Aucun deck pour l'instant ».

Texture (spec §2.5, application de la spec nav/DA §7.3) : elle est posée par le shell (`app_shell_scaffold.dart:34-39`) derrière tous les onglets. Le retrait se fait comme sur la fiche carte : la page Decks pose un fond opaque `AppColors.scaffoldBackground` sous son `NestedScrollView`. Le shell ne change pas : l'Accueil et le mode Jeu gardent la texture.

- [ ] **Step 1: Tests**
  - `deckLibraryColumns` à 599, 600, 999, 1000, 360 et 841 (Fold déplié) → 1, 2, 2, 3, 1, 2.
  - `DeckLibraryGrid` monté à 390, 840 et 1200 de large rend respectivement 1, 2 et 3 tuiles par rangée (comparer les `dy` des tuiles).
  - Les deux états vides et le bouton qui appelle `onClearFilters`.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter**, puis brancher la page (fond opaque compris).
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): grille de une a trois colonnes, sans texture`

---

## Task 6: Barre de filtres et feuille de filtres

**Files:**
- Create: `lib/widgets/decks/deck_filter_bar.dart`, `lib/widgets/decks/deck_filter_sheet.dart`
- Modify: `lib/pages/decks/deck_list_page.dart` — supprimer les trois pilules (l.160-192), `_buildChoiceChip`, `_buildIdentityFilterChip` et la copie inline `_openIdentityFilterModal` (l.292-372) ; la page utilise `showDeckIdentityFilterModal` (`lib/widgets/decks/deck_identity_filter_modal.dart`, aujourd'hui jamais appelé).
- Test: `test/widgets/decks/deck_filter_bar_test.dart`, `test/widgets/decks/deck_filter_sheet_test.dart` (créés)

**Interfaces:**
- Consumes: Task 3.
- Produces :
  - `DeckFilterBar({required DeckFilterCriteria criteria, required int activeCount, required VoidCallback onOpenFilters, required ValueChanged<DeckSort> onSort, required void Function(DeckFilterKind) onClear})`.
  - `enum DeckFilterKind { format, identity, tags, price }`.
  - `Future<void> showDeckFilterSheet(BuildContext, {required DeckListState state, required DeckListController controller, required List<String> formats, required List<String> tags, required double maxPrice})`.

La barre (maquette) : pilule « Filtres » avec badge = `activeCount` (badge masqué à 0), puis une puce par filtre actif. Chaque puce porte une croix qui appelle `onClear(kind)`. Libellés des puces : le format tel quel ; le nom de l'identité ; un tag seul → son nom, plusieurs → « 3 tags » ; prix → « Sous 300 € » si `min == 0`, « Dès 50 € » si `max` est le plafond, sinon « 50–300 € ». À droite, la pilule de tri ouvre un menu des cinq `DeckSort`.

La feuille : quatre sections.
1. Format : puces à choix unique, « Tous » + formats présents.
2. Identité couleur : un bouton qui ouvre `showDeckIdentityFilterModal`, réutilisée telle quelle.
3. Tags : `FilterChip` multi-sélection sur `availableTags`, texte « Aucun tag : appui long sur un deck pour en poser » si la liste est vide.
4. Prix : `RangeSlider` de 0 à `maxPrice` arrondi au multiple de 50 supérieur, pas de 10 €.

Plus un bouton « Tout effacer ». Les changements s'appliquent au fil de l'eau.

- [ ] **Step 1: Tests**
  - Badge absent à 0, « 2 » avec deux filtres.
  - Chaque libellé de puce de prix.
  - La croix d'une puce appelle `onClear` avec le bon `DeckFilterKind`.
  - Le menu de tri liste les cinq libellés et rend le choix.
  - Feuille : sélectionner un tag appelle `controller.updateTags` ; « Tout effacer » appelle `clearAllFilters`. Contrôleur réel, `DeckService` factice comme dans les tests `importDeck` existants.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter et brancher.**
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): barre et feuille de filtres avec compteur`

---

## Task 7: Poser des tags sur un deck

La spec §2.4 crée les tags mais ne dit pas où on les pose. Sans cette tâche, les filtres de la tâche 6 n'auraient jamais rien à filtrer. Décision du plan : un appui long sur une tuile ouvre une feuille « Dossiers ». C'est le seul geste libre sur la tuile : le tap ouvre le deck et le glissement le supprime.

**Files:**
- Create: `lib/widgets/decks/deck_tags_sheet.dart`
- Modify: `lib/controllers/deck_list_controller.dart` (`updateDeckTags`), `lib/pages/decks/deck_list_page.dart` (`onLongPress`)
- Test: `test/widgets/decks/deck_tags_sheet_test.dart` (créé)

**Interfaces:**
- Consumes: Task 2 (`DeckService.updateDeckTags`), Task 4 (`onLongPress`).
- Produces :
  - `Future<List<String>?> showDeckTagsSheet(BuildContext, {required String deckName, required List<String> current, required List<String> known})` rend la nouvelle liste, ou `null` si annulé.
  - `Future<void> DeckListController.updateDeckTags(String deckId, List<String> tags)` persiste, recharge et élague les tags sélectionnés.

Feuille : titre « Dossiers de <nom> », `FilterChip` sur les tags connus (union de tous les decks), champ « Nouveau dossier » + bouton « Ajouter ». Le texte est rogné ; un doublon est refusé sans tenir compte de la casse (le tag existant est sélectionné). Bouton « Enregistrer ».

- [ ] **Step 1: Tests**
  - Ajouter « cEDH » puis enregistrer → rend `['cEDH']`.
  - Ajouter « Casual » quand « casual » existe → sélectionne l'existant, sans doublon.
  - Fermer sans enregistrer → `null`.
  - Contrôleur : `updateDeckTags` puis `availableTags` contient le tag.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter et brancher.**
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): poser des dossiers sur un deck`

---

## Task 8: Captures §6.2

**Files:**
- Create: `test/captures/deck_library_captures_test.dart` (tag `capture`). Copier le préambule de polices de `test/captures/grimoire_captures_test.dart`.

`DeckListPage` n'est pas montable (singleton `LocalCardService`). On capture donc `DeckLibraryGrid` + `DeckFilterBar` dans un `Scaffold` au fond de l'application, à 390×844, 840×700 et 1280×800 : 1, 2 et 3 colonnes. Contenu : six decks fictifs, dont un sans commandant, un incolore, un avec deux tags, et deux filtres actifs. Le réseau étant indisponible en test, la tuile avec commandant montre son repli `ScryfallImage` : c'est attendu, à noter dans le rapport. Capture supplémentaire : l'état vide filtré.

- [ ] **Step 1: Écrire les captures et générer** — Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/deck_library_captures_test.dart`
- [ ] **Step 2: Regarder chaque image** : nombre de colonnes, tuiles de même hauteur avec et sans commandant, badge, puces, compteur. Une capture n'est pas validée tant qu'elle n'a pas été regardée.
- [ ] **Step 3: Commit** `test(captures): bibliotheque de decks a une, deux et trois colonnes`

---

## Hors de ce plan

- La gouttière alignée sur la charnière du Fold : chantier B.
- Le badge de format montre `deck.format` tel que stocké. Les decks créés à la main valent « Standard » tant qu'on ne leur pose pas de commandant (`setCommander` les passe en « Commander »). Corriger les formats existants n'est pas demandé.
