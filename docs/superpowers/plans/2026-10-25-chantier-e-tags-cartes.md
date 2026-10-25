# Chantier E — Tags de cartes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les catégories fixes du chantier D par des tags de cartes à la Moxfield : des tags proposés automatiquement, modifiables, avec un tag principal qui sert au regroupement. Une liste de tags universels se gère dans un écran dédié, et chaque deck peut avoir ses propres tags.

**Architecture :**
- **Les tags restent ce qu'ils sont déjà :** la liste de chaînes `DeckCard.tags`, stockée en JSON dans `deck_cards.tags`.
  - Le **premier** élément est le tag principal. Aucune colonne n'est ajoutée pour lui.
  - Un drapeau `tagsEdited` remplace `category` / `categoryLocked`, et le schéma Drift passe en v7.
- **Le catalogue des tags universels** est une liste ordonnée stockée en JSON dans `AppSettings`.
  - Les huit tags par défaut portent une **clé stable** (`ramp`, `blink`…), si bien qu'un tag renommé reste proposé sous son nouveau nom.
  - Un tag présent sur une carte mais absent du catalogue est un **tag du deck** : on ne le stocke nulle part ailleurs.
- **La suggestion** est une fonction pure, `suggestTagKeys`, qui succède à `classifyCard`. Elle peut proposer plusieurs rôles, dans un ordre de priorité fixe.

**Tech Stack :** Flutter 3.9+, Riverpod 3 (`StateNotifier` legacy), Drift 2 (fichiers `.g.dart` commités, régénérés par `dart run build_runner build --delete-conflicting-outputs`), GoRouter, `flutter_test`.

**Spec :** il n'y a pas de document de spec. Les décisions de l'utilisateur, prises en recette de la 1.12.0 le 25/10/2026, sont recopiées ci-dessous et font foi.

**Prérequis :** la 1.12.1 est sur `main`, avec le lot X1 :
- regroupement par type par défaut ;
- tri par mana value dans chaque section (`sortByManaValue` dans `lib/utils/deck_metrics.dart`) ;
- interrupteurs dans `lib/widgets/decks/deck_view_toggles.dart`.

Le schéma est en v6.

## Décisions de l'utilisateur (font foi)

1. **Tags pré-remplis :** le regroupement « Catégorie » devient « Tags ». L'app propose des tags à la première ouverture du deck, et l'utilisateur les garde, les change ou les retire. Il n'y a plus de catégorie figée. Ephemerate doit recevoir **Blink**.
2. **Tag principal :** il sert au regroupement. Les autres tags d'une carte s'affichent en pastilles.
3. **Écran « Tags » :**
   - Il est accessible depuis le menu et gère les **tags universels**, pré-remplis avec Ramp, Pioche, Removal, Wipe, Blink, Protection, Tuteur et Win-con.
   - On peut y renommer, colorer, supprimer et réordonner.
   - Un tag créé depuis une carte est **propre au deck**, avec une option pour le rendre universel.
4. **Inchangé :** le regroupement par type reste le défaut, et le tri reste par mana value croissante. La quantité et les boutons −/+ de la vignette ne bougent pas.

## Global Constraints

- **Libellés :** en français, accentués, sans emoji.
- **Couleurs :** uniquement via `AppColors` / `MagicPalette`, sauf la palette des tags, définie une fois dans `lib/models/card_tag.dart`.
  - Le `primary` du thème est lilas : tout bouton ou segment or pose `foregroundColor` et `backgroundColor` explicitement.
- **Cibles tactiles :** aucune sous 48×48, sauf les boutons −/+ de la vignette, qui restent tels quels.
- **Tests :** chaque test ajouté est discriminant. Casser la ligne de production, constater l'échec, rétablir.
- **Tags par défaut :** dans cet ordre, avec ces clés et ces noms :
  - `ramp` « Ramp »
  - `draw` « Pioche »
  - `removal` « Removal »
  - `wipe` « Wipe »
  - `blink` « Blink »
  - `protection` « Protection »
  - `tutor` « Tuteur »
  - `wincon` « Win-con »
- **Nom de tag :** espaces de bord retirés, espaces internes réduits à un, longueur de 1 à 24 caractères.
  - L'égalité est **insensible à la casse** : une carte ne porte jamais deux tags égaux à la casse près.
  - Un nom saisi qui égale un tag du catalogue à la casse près prend l'orthographe du catalogue.
- **Ordre des tags :** `tags.first` est le principal. Toute écriture préserve l'ordre.
- **`tagsEdited` :** vrai dès que l'utilisateur a touché aux tags d'une carte, même pour les vider. Aucune suggestion n'écrit alors sur cette carte.
  - Une suggestion n'écrit que sur une carte aux tags **vides** et `tagsEdited == false`.
  - La condition est dans la requête SQL, comme le fait aujourd'hui `applyDeducedDeckCardCategories`.
- **Écritures de suggestion :** elles ne font pas avancer `Deck.updatedAt` (règle du chantier C).
- **Fusion de deux piles** (déplacement de board, changement de version, `mergeVariants`) : la pile cible garde ses tags et son `tagsEdited`, comme la catégorie aujourd'hui.
- **Tags de deck ≠ tags de cartes :** `Deck.tags` (les « dossiers » de la bibliothèque, chantier C) ne change pas.
- **Avant chaque commit :** `flutter test` et `flutter analyze`. Relever la baseline au départ et n'ajouter aucun problème d'analyse.
- **Goldens :** ne commiter que ceux du fichier de capture concerné. Les goldens 01, 02, 03, 05 et 30 dérivent en local et ne se commitent jamais.
- **Worktree neuf :** lier `assets/json/oracle-cards.json` en lien dur depuis le dépôt principal, avec `New-Item -ItemType HardLink` dans PowerShell.

## Review Focus

1. **Mise à jour depuis la v6 :**
   - Une carte à catégorie verrouillée et une carte avec d'anciens tags libres arrivent avec des tags justes, l'ancien rôle en principal.
   - Aucune carte n'est perdue. Test dans la tâche 3.
2. **Sauvegarde d'avant la 1.13 restaurée :** `category` et `categoryLocked`, sans catalogue, donnent les mêmes tags qu'une migration, et le catalogue courant reste intact. Test dans la tâche 3.
3. **Renommer un tag universel vers un nom qu'une carte porte déjà en tag de deck :**
   - La carte ne garde qu'un exemplaire, à la position du premier.
   - Le renommage vers un autre tag **universel** est refusé.
   - Test dans la tâche 1.
4. **Vider tous les tags d'une carte, puis rouvrir le deck :** rien n'est re-proposé. Test dans la tâche 3.
5. **Supprimer « Blink » du catalogue :**
   - Ephemerate n'est plus tagué à l'ouverture d'un deck neuf.
   - Le catalogue ne se re-remplit pas. On ne réensemence que si la clé de réglage est absente, pas si la liste est vide.
   - Test dans les tâches 1 et 3.

---

### Task 1: Catalogue des tags universels

**Files:**
- Create: `lib/models/card_tag.dart`, `lib/services/card_tag_catalog.dart`, `lib/controllers/card_tag_catalog_controller.dart`
- Modify: `lib/data/database/app_database.dart` (requêtes sur les tags de toutes les cartes de deck), `lib/services/backup_service.dart` (export/restauration du catalogue)
- Test: `test/models/card_tag_test.dart`, `test/services/card_tag_catalog_test.dart`, `test/services/backup_service_test.dart`

**Interfaces:**
- Produces:
  - `class CardTagDef { final String? key; final String name; final int color; }`
    - `key` vaut nul pour un tag créé par l'utilisateur.
    - Ajouter `toJson` / `fromJson` et `copyWith`.
  - `const List<CardTagDef> kDefaultCardTags` : les huit tags des Global Constraints, chacun avec une couleur de `kCardTagPalette`.
  - `const List<int> kCardTagPalette` : dix couleurs ARGB, les huit des défauts plus deux.
  - `String? normalizeTagName(String raw)` : nul si le nom est invalide.
  - `bool sameTag(String a, String b)` : comparaison insensible à la casse.
  - `class CardTagCatalog` (service, constructeur `CardTagCatalog(AppDatabase db)`) :
    - `Future<List<CardTagDef>> load()` : renvoie `kDefaultCardTags` **et l'écrit** si la clé `card_tags:universal` est absente ou illisible. Une liste vide stockée reste vide.
    - `Future<void> save(List<CardTagDef> tags)`
    - `Future<RenameResult> rename(String from, String to)`, avec `enum RenameResult { ok, invalid, duplicate }`. Elle propage le renommage dans `deck_cards.tags` de **tous** les decks, avec dédoublonnage par carte.
    - `Future<int> delete(String name)` : retire le tag du catalogue et de toutes les cartes, puis renvoie le nombre de lignes `deck_cards` touchées.
    - `Future<int> usageCount(String name)` : nombre de lignes `deck_cards` qui portent le tag.
    - `Future<bool> add(String rawName, {int? color})` : faux si le nom est invalide ou déjà présent.
  - `final cardTagCatalogProvider = StateNotifierProvider<CardTagCatalogController, List<CardTagDef>>`. Le contrôleur expose `load`, `add`, `rename`, `delete`, `reorder(int oldIndex, int newIndex)` et `setColor(String name, int color)`, chacun persistant via `CardTagCatalog`. Suivre le câblage de `lib/providers/service_providers.dart` pour obtenir la base.
- Consumes: `AppDatabase.getSetting` / `setSetting` (`app_database.dart:792-803`).

- [ ] **Step 1: Write the failing tests** : `card_tag_test.dart`
  - `normalizeTagName('  Pioche   rapide ')` donne `'Pioche rapide'`.
  - `normalizeTagName('   ')` donne nul.
  - `normalizeTagName('a' * 25)` donne nul.
  - `sameTag('blink', 'Blink')` est vrai.
  - `kDefaultCardTags.map((t) => t.key)` donne `['ramp','draw','removal','wipe','blink','protection','tutor','wincon']`.
  - Leurs noms donnent `['Ramp','Pioche','Removal','Wipe','Blink','Protection','Tuteur','Win-con']`.
- [ ] **Step 2: Write the failing tests** : `card_tag_catalog_test.dart`, sur une base en mémoire (`NativeDatabase.memory()`)
  - `load seeds defaults once` : premier `load()` égal à `kDefaultCardTags`. Après `save([])`, `load()` rend `[]`.
  - `load falls back on unreadable json` : `setSetting('card_tags:universal', '{x')` puis `load()` donne les défauts.
  - `rename propagates and dedupes` :
    - Données : une carte avec `['Ma pioche','Pioche']`, une autre avec `['Pioche']`.
    - `rename('Pioche','Ma pioche')` donne `RenameResult.ok`.
    - Les tags lus en base deviennent `['Ma pioche']` et `['Ma pioche']`.
    - Le catalogue garde `key: 'draw'` sous le nom `Ma pioche`.
  - `rename to another universal name is refused` : `rename('Pioche','removal')` donne `duplicate`, et rien ne change.
  - `delete removes from cards and counts` :
    - Données : deux cartes `['Blink','Ramp']` et `['Ramp']`.
    - `delete('Ramp')` renvoie 2.
    - La première carte passe à `['Blink']`, la seconde à `[]`.
  - `usageCount('Blink')` vaut 1.
- [ ] **Step 3: Run tests to verify they fail**
  Run : `flutter test test/models/card_tag_test.dart test/services/card_tag_catalog_test.dart`
  Attendu : FAIL (fichiers absents).
- [ ] **Step 4: Implement** `card_tag.dart`, `card_tag_catalog.dart`, `card_tag_catalog_controller.dart`
  - Le parcours des tags de toutes les cartes passe par une méthode de `AppDatabase` qui lit `deckCards` en entier, puis réécrit les lignes modifiées dans **une** transaction.
  - Clé primaire d'une ligne : `deckId`, `board`, `scryfallId`.
- [ ] **Step 5: Backup** : test puis code
  - Test `backup exports and restores the tag catalog`. Le catalogue sauvegardé sous la clé `card_tags_universal` (liste JSON de `CardTagDef`) est restauré à l'identique.
  - Test `old backup without catalog keeps current catalog`.
- [ ] **Step 6: Run** `flutter test` et `flutter analyze` : tout vert, aucun nouveau problème.
- [ ] **Step 7: Commit** : `feat(tags): catalogue des tags universels, renommage et suppression propagés`

### Task 2: Suggestion de tags

**Files:**
- Create: `lib/services/card_tag_suggester.dart`, `test/services/card_tag_suggester_test.dart`
- Ne pas encore supprimer `card_category_service.dart` : la tâche 3 s'en charge.

**Interfaces:**
- Produces: `List<String> suggestTagKeys({required String typeLine, required String oracleText})`. Elle renvoie des clés du catalogue par défaut, sans doublon, dans l'ordre de priorité `wipe, removal, blink, ramp, tutor, draw, protection, wincon`. Le premier élément est le futur tag principal.
- Consumes: les motifs de `lib/services/card_category_service.dart`, à reprendre tels quels, car ils ont été corrigés contre de vraies cartes pendant le chantier D.

**Règles :**
- Chaque règle de `classifyCard` devient un test **indépendant**, sans « première qui gagne ».
- Terrain en face avant (créature-terrain comprise) : `[]`.
- Une créature sans motif : `[]`.
- Nouveau motif `blink` : `_blink` (déjà défini) **et** (`exile target` ou `exile up to`) dans le texte.
- Une carte peut cumuler plusieurs clés. Par exemple « Draw a card » plus « Add {G} » donne `['ramp','draw']`.

- [ ] **Step 1: Write the failing tests** : reprendre la table de `test/services/card_category_service_test.dart` et traduire chaque attendu.
  - `ramp` → `['ramp']`.
  - `lands`, `creatures` et `other` → `[]`.
  - Lignes en plus :
    - `('Ephemerate','Instant','Exile target creature you control, then return it to the battlefield under its owner\'s control.\nRebound')` → `['blink']`.
    - `('Cloudshift','Instant','Exile target creature you control, then return that card to the battlefield under your control.')` → `['blink']`.
    - `('Growth Spiral','Instant','Draw a card. You may put a land card from your hand onto the battlefield.')` → `['ramp','draw']`. Nouveau motif de ramp : `put a land card from your hand onto the battlefield`.
    - `('Prismatic Vista', 'Land', '{T}, Pay 1 life: Add {C}.')` → `[]`.
- [ ] **Step 2: Run** `flutter test test/services/card_tag_suggester_test.dart`
  Attendu : FAIL.
- [ ] **Step 3: Implement** `suggestTagKeys`.
- [ ] **Step 4: Run** le test.
  Attendu : PASS.
- [ ] **Step 5: Commit** : `feat(tags): suggestion de tags multi-rôles, Blink compris`

### Task 3: Bascule des données, de la catégorie aux tags

C'est la plus grosse tâche. Elle doit compiler d'un bloc, puisque `category` disparaît partout.

**Files:**
- Modify: `lib/models/deck_model.dart`, `lib/data/database/app_database.dart` (+ `.g.dart` régénéré), `lib/services/deck_service.dart`, `lib/controllers/deck_detail_controller.dart`, `lib/services/backup_service.dart`, `lib/data/migration/migration_service.dart`, `lib/services/deck_view_prefs.dart`, `lib/widgets/decks/deck_view_toggles.dart`, `lib/widgets/decks/deck_card_list_tab.dart`
- Delete: `lib/models/card_category.dart`, `lib/services/card_category_service.dart` et leurs tests
- Test: `test/data/app_database_migration_v7_test.dart` (nouveau), `test/controllers/deck_detail_tags_test.dart`, qui remplace `deck_detail_categories_test.dart`, et les tests existants à adapter : `deck_service_test`, `backup_service_test`, `deck_view_prefs_test`, `deck_card_list_tab_test`, `deck_model_test`, `app_database_test`

**Interfaces:**
- Consumes: `CardTagCatalog.load()` et `cardTagCatalogProvider` (tâche 1), `suggestTagKeys` (tâche 2).
- Produces:
  - `DeckCard` : `category` et `categoryLocked` sont supprimés. `bool tagsEdited` (défaut `false`) et `String? get primaryTag` (`tags` vide → nul) sont ajoutés.
    - JSON : `'tagsEdited'`.
    - Lecture d'un JSON ancien : la règle de migration ci-dessous, via `legacyCategoryTags`.
  - `List<String> legacyCategoryTags(String? category, bool locked, List<String> tags)`, dans `card_tag.dart` :
    - Si `category` vaut `ramp`, `draw`, `removal`, `wipe`, `protection`, `tutor` ou `wincon`, et que le tag n'est pas déjà dans `tags` (`sameTag`), on renvoie `[label, ...tags]`.
    - Sinon, `tags` inchangé.
    - Labels : ceux des défauts.
    - `locked` ne change pas les tags. Il donne `tagsEdited`.
  - Drift v7 : colonne `tagsEdited` (bool, défaut faux). Colonnes `category` et `categoryLocked` **supprimées**.
    - Migration 6→7 : ajouter `tagsEdited`, puis, en Dart via `customSelect`, pour chaque ligne : `tags = legacyCategoryTags(...)` et `tags_edited = category_locked`.
    - Ensuite, `m.alterTable(TableMigration(deckCards))` retire les anciennes colonnes.
  - `AppDatabase.upsertDeckCard` : les paramètres `category` et `categoryLocked` sont remplacés par `bool? tagsEdited`. La règle de fusion reste « la cible garde ses tags et son drapeau ».
  - `AppDatabase.setDeckCardTags({deckId, board, scryfallId, required List<String> tags, required bool tagsEdited})`.
  - `AppDatabase.applySuggestedDeckCardTags(String deckId, List<({String board, String scryfallId, List<String> tags})>)` : n'écrit que là où `tags = '[]' AND tags_edited = 0`.
  - `DeckService.setCardTags(deckId, board, scryfallId, List<String> tags, {required bool edited})` et `applySuggestedTags(...)` remplacent `setCardCategory` et `applyDeducedCategories`. Aucun `_touch` dans `applySuggestedTags`.
  - `DeckDetailController` :
    - `_suggestTagsForUntagged()` remplace `_categorizeUncategorized()`, aux deux mêmes points d'appel (lignes 164 et 452).
    - Les clés sont traduites en noms via le catalogue : une clé absente du catalogue (tag supprimé) est sautée.
    - `setCardTags(DeckCard, DeckBoard, List<String>)` normalise, dédoublonne et met `edited: true`.
    - `resetCardTags(DeckCard, DeckBoard)` : nouvelle suggestion et `edited: false`, ou `[]` si la carte est `LOCAL:` ou sans données.
    - `updateTags` (ancien dialogue) est supprimé, et ses appelants passent par `setCardTags`.
    - Ajouter `Future<void> refreshAfterTagChanges()` public, qui recharge le deck. La tâche 6 l'appelle.
  - `DeckGrouping { tag, type }` remplace `{ category, type }`. Une valeur stockée `'category'` est relue comme `tag`. Le défaut reste `type`.
  - `DeckViewToggles` : le segment est libellé « Tags ».
  - `DeckCardListTab` :
    - `_buildCategoryList` devient `_buildTagList(List<DeckCard>, List<CardTagDef> catalog)`, qui regroupe par `primaryTag`.
    - Ordre des sections : les tags du catalogue dans leur ordre, puis les tags de deck par ordre alphabétique, puis « Sans tag » en dernier.
    - Dans chaque section, `sortByManaValue`.
    - L'en-tête garde le format actuel : « NOM · n · CMC moyen x,y ».
    - Les entrées de menu « Catégorie… » et « Gérer les Tags » sont **provisoirement** remplacées par une seule entrée « Tags… », qui ouvre l'ancien `_showTagEditor` câblé sur `onSetTags`. La tâche 4 remplace ce dialogue.
    - Les callbacks `onSetCategory` et `onResetCategory` deviennent `onSetTags(DeckCard, List<String>)` et `onResetTags(DeckCard)`.
    - Le cadenas de catégorie sur la vignette est supprimé.

- [ ] **Step 1: Write the failing tests**
  - `app_database_migration_v7_test.dart`, sur une base v6 construite à la main comme dans `app_database_migration_v6_test.dart` :
    - (a) `category: 'removal'`, tags `[]`, non verrouillée : tags `['Removal']`, `tagsEdited` faux.
    - (b) `category: 'ramp'`, verrouillée, tags `['Commander']` : `['Ramp','Commander']`, `tagsEdited` vrai.
    - (c) `category: 'lands'` : `[]`.
    - (d) `category: 'draw'`, tags `['pioche']` : `['pioche']`. La casse est déjà présente, rien n'est ajouté.
    - (e) Même nombre de lignes avant et après.
  - `deck_detail_tags_test.dart` :
    - `opening a deck tags Ephemerate Blink and Sol Ring Ramp`.
    - `a card emptied by hand is not re-suggested` : `setCardTags(c, main, [])`, rouvrir, tags `[]`.
    - `a deleted catalogue tag is not suggested` : catalogue sans Blink, Ephemerate donne `[]`.
    - `opening does not bump updatedAt`.
    - `resetCardTags restores the suggestion and clears tagsEdited`.
  - `backup_service_test` : `restoring a pre-1.13 backup converts category to tags`. Avec `{'category':'wipe','categoryLocked':true,'tags':[]}`, on obtient tags `['Wipe']` et `tagsEdited` vrai.
  - `deck_view_prefs_test` : `stored category grouping reads as tag`.
  - `deck_card_list_tab_test` : `tag grouping orders catalogue, deck tags, then Sans tag`. Avec des cartes à principal `Pioche`, `Ramp`, `Zèbre` (tag de deck), `Alpha` (tag de deck) et une sans tag, on obtient les en-têtes dans l'ordre `RAMP`, `PIOCHE`, `ALPHA`, `ZÈBRE`, `SANS TAG`.
- [ ] **Step 2: Run** les tests ci-dessus.
  Attendu : FAIL.
- [ ] **Step 3: Implement**
  - Commencer par le schéma, puis régénérer avec `dart run build_runner build --delete-conflicting-outputs`.
  - Suivre ensuite les erreurs de compilation jusqu'à `flutter analyze` propre.
  - Supprimer `card_category.dart`, `card_category_service.dart` et leurs tests en dernier.
- [ ] **Step 4: Run** `flutter test` (suite complète) et `flutter analyze`.
  Attendu : vert, pas de nouveau problème.
  Les captures de `test/captures/deck_page_captures_test.dart` qui affichent « Catégorie » seront mises à jour en tâche 7 : ne pas régénérer de golden ici.
- [ ] **Step 5: Commit** : `feat(tags): les tags remplacent les catégories (schéma v7, migration, suggestion à l'ouverture)`

### Task 4: Feuille d'édition des tags d'une carte

**Files:**
- Create: `lib/widgets/decks/card_tags_sheet.dart`, `lib/utils/card_tag_edit.dart`
- Modify: `lib/widgets/decks/deck_card_list_tab.dart` (l'entrée « Tags… » ouvre la feuille ; supprimer `_showTagEditor`), `lib/pages/decks/deck_detail_page.dart` (câblage)
- Test: `test/utils/card_tag_edit_test.dart`, `test/widgets/decks/card_tags_sheet_test.dart`

**Interfaces:**
- Consumes: `cardTagCatalogProvider`, `normalizeTagName`, `sameTag`, `DeckDetailController.setCardTags` / `resetCardTags`.
- Produces:
  - Dans `card_tag_edit.dart`, des fonctions pures sur `List<String>` qui rendent une nouvelle liste :
    - `addTag(tags, name, catalog)` : ajoute en fin, prend l'orthographe du catalogue, ne fait rien sur un doublon.
    - `removeTag(tags, name)`.
    - `makePrimary(tags, name)` : déplace en tête.
    - `deckOnlyTags(Deck deck, List<CardTagDef> catalog)` : l'union des tags des quatre boards absents du catalogue, triée.
  - `Future<void> showCardTagsSheet(BuildContext, {required DeckCard card, required List<String> deckTags, required bool canSuggest, required ValueChanged<List<String>> onSave, required VoidCallback onReset})`.

**Contenu de la feuille, de haut en bas :**
- Titre : le nom de la carte.
- **« Tags de la carte » :**
  - Une puce par tag, dans l'ordre, colorée par le catalogue, neutre pour un tag de deck.
  - Une étoile 48 px : pleine sur le principal, vide sur les autres. Un tap rend le tag principal.
  - Une croix 48 px retire le tag.
  - Sur une puce de tag de deck, un bouton « Rendre universel » (icône `public`, tooltip) appelle `cardTagCatalogProvider.notifier.add(name)`.
- **« Tags universels » :** les tags du catalogue absents de la carte. Un tap les ajoute.
- **« Tags de ce deck » :** `deckTags` absents de la carte. Un tap les ajoute. La section est masquée si elle est vide.
- **Création :** un champ « Nouveau tag » et un bouton « Ajouter ».
  - Un nom invalide affiche « Un tag fait de 1 à 24 caractères. »
  - Un doublon ne fait rien.
- **Pied :**
  - « Suggestion auto », visible seulement si `canSuggest` : appelle `onReset` et ferme.
  - « Annuler ».
  - « Enregistrer », or, texte sombre explicite : appelle `onSave(tags)` et ferme.

- [ ] **Step 1: Write the failing tests** : `card_tag_edit_test.dart`
  - `addTag(['Ramp'], 'pioche', kDefaultCardTags)` donne `['Ramp','Pioche']`.
  - `addTag(['Ramp'], 'RAMP', …)` donne `['Ramp']`.
  - `makePrimary(['Ramp','Blink'], 'Blink')` donne `['Blink','Ramp']`.
  - `deckOnlyTags` sur un deck dont le main porte `['Ramp','Combo']` et le side `['Hate']` donne `['Combo','Hate']`.
- [ ] **Step 2: Write the failing tests** : `card_tags_sheet_test.dart`
  - Taper l'étoile de « Blink », puis Enregistrer : `onSave` reçoit `['Blink','Ramp']`.
  - Ajouter « Combo » par le champ, puis Enregistrer : `onSave` reçoit `[…,'Combo']`.
  - Avec `canSuggest: false`, « Suggestion auto » est absent.
  - Le bouton Enregistrer a un `foregroundColor` sombre.
- [ ] **Step 3: Run**, constater l'échec, puis **Implement**.
- [ ] **Step 4: Câbler** depuis le menu de la carte : `deckTags: deckOnlyTags(deck, catalog)` et `canSuggest` vrai pour une carte non `LOCAL:` présente dans `fullCardData`.
  Test de câblage dans `test/pages/decks/deck_detail_page_wiring_test.dart` : appui long sur une carte, « Tags… », la feuille s'ouvre.
- [ ] **Step 5: Run** la suite complète et `flutter analyze`. **Commit** : `feat(tags): feuille d'édition des tags d'une carte`

### Task 5: Pastilles et en-têtes colorés

**Files:**
- Modify: `lib/widgets/decks/deck_card_list_tab.dart` (vignette de grille et en-têtes de section), `lib/widgets/decks/deck_card_title.dart` (liste compacte)
- Test: `test/widgets/decks/deck_card_list_tab_test.dart`, `test/widgets/decks/deck_card_title_test.dart`

**Interfaces:** Consumes `cardTagCatalogProvider`, `DeckCard.primaryTag`.

**Comportement :**
- **En-tête d'une section par tag :** une pastille ronde de 10 px à la couleur du tag (neutre `AppColors.textMuted` pour un tag de deck ou « Sans tag »), avant le nom.
- **Vignette de grille :**
  - Les tags **secondaires** (`tags.skip(1)`) s'affichent en coin haut-gauche, en points de 8 px, trois au plus, plus « +n » s'il en reste.
  - Ils sont enveloppés d'un `Semantics(label: 'Tags : Blink, Pioche')`.
  - Le coin haut-droit garde le coût de mana.
- **Liste compacte :** les puces de texte existantes (`deck_card_title.dart:132`) montrent les tags secondaires, colorés, le principal étant déjà l'en-tête. En regroupement par type, elles montrent tous les tags.

- [ ] **Step 1: Write the failing tests**
  - `grid tile shows secondary tag dots with semantics`. Avec une carte `['Ramp','Blink','Pioche']`, on trouve `Semantics` 'Tags : Blink, Pioche', et aucun point pour Ramp.
  - `type grouping list shows all tags`.
  - `tag header dot uses catalogue colour`.
- [ ] **Step 2: Run**, constater l'échec, **Implement**, puis **Run** la suite.
- [ ] **Step 3: Commit** : `feat(tags): pastilles des tags secondaires et en-têtes colorés`

### Task 6: Écran « Tags de cartes »

**Files:**
- Create: `lib/pages/settings/card_tags_page.dart`
- Modify:
  - `lib/router/app_routes.dart` (`static const String cardTags = '/settings/card-tags';`) et `lib/router/settings_routes.dart` ;
  - `lib/pages/settings/settings_page.dart` (une `ListTile` « Tags de cartes », sous-titre « Tags universels proposés dans tous les decks », sous « Gestion des Profils ») ;
  - `lib/pages/decks/deck_detail_page.dart` (une entrée de menu ⋮ « Gérer les tags », icône `label`, qui fait `await context.push(AppRoutes.cardTags)` puis `_ctrl.refreshAfterTagChanges()`).
- Test: `test/pages/settings/card_tags_page_test.dart`, `test/pages/decks/deck_detail_page_wiring_test.dart`

**Interfaces:** Consumes `cardTagCatalogProvider` (`add`, `rename`, `delete`, `reorder`, `setColor`), `CardTagCatalog.usageCount`.

**Contenu :**
- AppBar « Tags de cartes ».
- `ReorderableListView` du catalogue, une ligne par tag :
  - poignée de déplacement ;
  - pastille de couleur 48 px, dont le tap ouvre une feuille avec les dix couleurs de `kCardTagPalette` ;
  - nom ;
  - sous-titre « n cartes » (`usageCount`) ;
  - bouton renommer ;
  - bouton supprimer.
- **Renommer :** dialogue avec champ.
  - `invalid` affiche « Un tag fait de 1 à 24 caractères. »
  - `duplicate` affiche « Un tag porte déjà ce nom. »
- **Supprimer :** dialogue « Supprimer le tag Blink ? Il sera retiré de 12 cartes. », avec les boutons « Annuler » et « Supprimer » (en couleur d'erreur).
- **Ajouter :** bouton « Nouveau tag », or, texte sombre.

- [ ] **Step 1: Write the failing tests**
  - `lists the catalogue in order`.
  - `rename to an existing universal name shows the duplicate message`.
  - `delete asks with the usage count then removes`.
  - `reorder persists`, en appelant directement le contrôleur ou par un glisser sur la poignée.
  - Câblage :
    - Depuis Paramètres, la tuile « Tags de cartes » ouvre la page.
    - Depuis le menu ⋮ d'un deck, « Gérer les tags » ouvre la page.
    - Au retour, un tag renommé apparaît renommé dans les en-têtes du deck.
- [ ] **Step 2: Run**, constater l'échec, **Implement**, puis **Run** la suite.
- [ ] **Step 3: Commit** : `feat(tags): écran de gestion des tags universels`

### Task 7: Imports, export et captures

**Files:**
- Modify: `lib/services/deck_format_service.dart`, `lib/controllers/deck_list_controller.dart` (`importDeck` vers la ligne 345, et le chemin Moxfield via `moxfield_deck_mapper.dart`), `lib/services/moxfield_deck_mapper.dart`
- Test: `test/services/deck_format_service_test.dart`, `test/services/moxfield_deck_mapper_test.dart`, `test/controllers/deck_list_controller_test.dart`, `test/captures/deck_page_captures_test.dart` (+ goldens de ce fichier seulement)

**Constat :**
- `DecklistParseResult.cardTags` (tags d'un CSV Archidekt) est rempli, mais **personne ne le lit** : les tags importés sont perdus.
- `exportToCsv` écrit les tags séparés par `;`, alors que le parseur découpe sur `,` : un aller-retour export puis import fusionne les tags.

**Règles :**
- **Parseur CSV :** il découpe les tags sur `,` **et** `;`. Il retire les noms de section qu'Archidekt range parmi les catégories (`Commander`, `Sideboard`, `Maybeboard`, à la casse près).
- **`importDeck` :** `DeckCard.tags = normalisés(parseResult.cardTags[entry.name] ?? [])`, et `tagsEdited = tags.isNotEmpty`.
- **Moxfield :**
  - `MoxfieldDeckData` gagne `Map<String, List<String>> authorTags`, lu depuis `json['authorTags']` (carte → liste de chaînes, par nom de carte).
  - Toute autre forme donne `{}`, sans exception, conformément à la politique de dégradation du mapper.
  - L'import Moxfield pose ces tags comme pour Archidekt.
  - **Attention :** la présence de `authorTags` dans la réponse Moxfield n'a pas été relevée sur un vrai deck, contrairement au reste du mapper. Le code reste défensif et l'utilisateur vérifiera en recette.

- [ ] **Step 1: Write the failing tests**
  - `csv round trip keeps separate tags` : `exportToCsv` d'un deck `['Ramp','Combo']`, puis `autoDetectAndParse`, donne `cardTags['Sol Ring'] == ['Ramp','Combo']`.
  - `archidekt section categories are not tags`.
  - `importDeck applies csv tags and marks them edited`.
  - `moxfield authorTags are mapped` : `{'authorTags': {'Sol Ring': ['Ramp']}}`.
  - `moxfield authorTags of unexpected shape give none` : liste, nombre, valeurs non textuelles.
- [ ] **Step 2: Run**, constater l'échec, **Implement**, puis **Run** la suite.
- [ ] **Step 3: Captures**
  - Mettre à jour `test/captures/deck_page_captures_test.dart` avec le regroupement « Tags » et une carte à tags secondaires.
  - Ajouter une capture 390 px de la feuille de tags et une de l'écran « Tags de cartes ».
  - Commande : `flutter test --tags capture --run-skipped --update-goldens test/captures/deck_page_captures_test.dart`.
  - **Regarder** chaque PNG produit avant de commiter.
- [ ] **Step 4: Commit** : `feat(tags): import des tags Archidekt et Moxfield, aller-retour CSV, captures`
