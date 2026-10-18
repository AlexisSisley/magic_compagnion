# Chantier D — Page d'un deck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refaire la page d'un deck pour préparer une partie : un bandeau du commandant avec les stats clés, des cartes groupées par catégorie de jeu en grille d'artworks, et quatre onglets au lieu de huit, sans perdre le dépôt de carte entre boards.

**Architecture:**
- **Catégorie :** une taxonomie fermée (`CardCategory`) déduite par une fonction pure (`classifyCard`) depuis le type line et le texte oracle ANGLAIS. Elle est stockée sur `DeckCard` (`category`, `categoryLocked`), et chaque chemin d'écriture la préserve.
- **Préférences d'affichage :** stockées par deck dans la table clé/valeur existante `AppSettings`.
- **Board :** sélectionné par des puces qui sont aussi les cibles de dépôt.

**Tech Stack:** Flutter 3.9+, Riverpod 3 (`StateNotifier` legacy), Drift 2 (fichiers `.g.dart` commités, régénérés par `dart run build_runner build --delete-conflicting-outputs`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md` §3 (chantier D), §6.1 et §6.2 (critères de sortie), §7 (hors périmètre). Maquette : canevas de design, artboard `DeckDetail`, décrit plus bas parce que les subagents ne peuvent pas l'ouvrir.

**Prérequis :** le chantier C est mergé. Le schéma part de la v5 et `upsertDeckCard` transmet déjà `proxyQuantity` (C, tâche 2).

## Global Constraints

- **Libellés :** en français, sans emoji. La page deck écrit aujourd'hui sans accents (« Legalite ») : tout texte NOUVEAU ou réécrit prend ses accents (« Légalité », « Créatures »).
- **Couleurs :** uniquement via `AppColors` / `MagicPalette`. Un test balaie `lib/` contre les couleurs de joueur en dur.
- **Cibles tactiles :** aucune sous 48×48.
- **Tests :** chaque test ajouté est discriminant. Casser la ligne de production, constater l'échec, rétablir.
- **Catégories (spec §3.2) :** la taxonomie est fermée et exacte, dans cet ordre d'affichage : Ramp, Pioche, Removal, Wipe, Protection, Tuteur, Terrains, Créatures, Win-con, Autres.
- **Catégorie ≠ tags :** la catégorie est distincte de `DeckCard.tags`, qui restent des étiquettes libres. Une catégorie corrigée à la main (`categoryLocked: true`) n'est JAMAIS réécrite par une déduction.
- **Affichage par défaut (spec §3.2 bis) :** la grille d'artworks est et reste le défaut. La liste compacte s'obtient d'un tap et n'est jamais le défaut. Les catégories sont des en-têtes AU-DESSUS de grilles.
- **Contenu d'une vignette :** quantité et coût de mana, pas de prix. Le prix reste dans l'onglet Stats et dans `DeckFinancialSheet`, qui ne changent pas.
- **Géométrie stable (spec §3.1) :** la page ne change pas de géométrie selon les données. Le bandeau a la même hauteur avec un commandant, deux ou aucun.
- **Onglets (spec §3.3) :** Liste, Stats, Suggestions, Infos. Rien n'est supprimé, tout est regroupé.
- **Dépôt entre boards (spec §3.3) :** le dépôt d'une carte sur un autre board doit marcher sur le sélecteur exactement comme sur l'ancien onglet. C'est le point de régression le plus probable du chantier.
- **Migration :** les cartes existantes arrivent avec `category: null` et `categoryLocked: false`, et reçoivent leur catégorie à la première ouverture du deck.
- **Avant chaque commit :** `flutter test` et `flutter analyze`. Relever la baseline au départ et n'ajouter aucun problème d'analyse.
- **Worktree neuf :** lier `assets/json/oracle-cards.json` en lien dur depuis le dépôt principal.

## Maquette (artboard `DeckDetail`, 840×700)

- **Bandeau :** 180 px de haut, l'art du commandant plein cadre, un dégradé sombre en pied.
  - Il porte le nom du deck (Cinzel 26).
  - Dessous, une rangée : pastilles de couleur (14 px), « 107 cartes », « · », « CMC moyen 3,2 », « · », une pilule « Power 7 » à bordure or, et, poussé à droite et en couleur atténuée, « 289 € ».
- **Onglets :** quatre de largeur égale, « Liste », « Stats », « Suggestions », « Infos ». L'onglet actif est en or et souligné d'or.
- **Sous les onglets, une rangée :**
  - les puces de board « Main 107 », « Side 0 », « Considering 4 », « Wishlist 2 » (l'active pleine or, les autres neutres) ;
  - à droite, un interrupteur segmenté « Catégorie | Type » ;
  - un interrupteur à deux icônes, grille et liste.
- **Catégories :**
  - Chaque catégorie a un en-tête en capitales or (« RAMP »), suivi de « 12 · CMC moyen 1,9 » et d'un filet qui file jusqu'au bord.
  - Dessous, une grille d'artworks : 6 colonnes à 840 de large, vignettes de 150 px de haut.
  - Chaque vignette porte sa quantité en pastille en haut à droite, et son nom et son coût de mana en pied.
  - Une carte dont la catégorie a été corrigée à la main porte un liseré or et une petite icône de cadenas à côté de sa quantité (libellé « Catégorie corrigée à la main »).

## Review Focus

1. **Carte double face, split ou aventure.** Le texte oracle est sur les faces, pas sur la racine. La classer sur un texte vide la jetterait dans « Autres ». → `oracleText` agrège les faces (tâche 2).
2. **Carte `LOCAL:`, sans données Scryfall.** Pas de déduction possible : elle s'affiche dans « Autres » sans qu'une catégorie soit persistée. Elle reste corrigeable à la main (tâche 3).
3. **Déplacement, changement d'illustration, sauvegarde ou restauration d'une carte corrigée à la main.** La correction et le verrou survivent (tâche 1).
4. **Dépôt sur le board courant ou sur un board vide.** Le premier est refusé sans effet. Le second accepte, puis le sélecteur bascule dessus (tâche 6).
5. **Suppression d'un deck.** Ses préférences d'affichage sont effacées avec lui, sans clé orpheline dans `AppSettings` (tâche 3).

---

## Structure des fichiers

| Fichier | Responsabilité | Tâche |
|---|---|---|
| `lib/models/card_category.dart` | **Créé.** `enum CardCategory` + libellés + ordre. | 1 |
| `lib/models/deck_model.dart` | **Modifié.** `DeckCard.category`, `DeckCard.categoryLocked`. | 1 |
| `lib/data/database/app_database.dart` (+ `.g.dart`) | **Modifié.** v6 : `deck_cards.category`, `deck_cards.categoryLocked`. | 1 |
| `lib/services/deck_service.dart`, `backup_service.dart`, `migration_service.dart`, `lib/utils/card_list_upsert_mixin.dart` | **Modifiés.** Catégorie préservée sur tous les chemins. | 1 |
| `lib/models/scryfall_card_model.dart` | **Modifié.** `oracleText` anglais, faces comprises. | 2 |
| `lib/services/card_category_service.dart` | **Créé.** `classifyCard`, fonction pure. | 2 |
| `lib/controllers/deck_detail_controller.dart` | **Modifié.** Catégorisation à l'ouverture, correction manuelle, préférences d'affichage, power level. | 3, 5 |
| `lib/services/deck_view_prefs.dart` | **Créé.** `DeckViewPrefs` et leur lecture/écriture dans `AppSettings`. | 3 |
| `lib/widgets/decks/deck_card_list_tab.dart`, `deck_card_title.dart` | **Modifiés.** Groupement par catégorie, grille par défaut, interrupteurs, cadenas, prix retiré. | 4 |
| `lib/utils/deck_metrics.dart` | **Créé.** `averageManaValue`. | 4, 5 |
| `lib/widgets/decks/deck_commander_header.dart` | **Réécrit.** Bandeau. | 5 |
| `lib/pages/decks/deck_detail_page.dart` | **Modifié.** Bandeau, quatre onglets, sélecteur de board. | 5, 6 |
| `lib/widgets/decks/deck_board_selector.dart` | **Créé.** Puces de board, cibles de dépôt. | 6 |
| `lib/widgets/decks/deck_info_tab.dart` | **Créé.** Tokens + Légalité. | 6 |
| `test/captures/deck_page_captures_test.dart` | **Créé.** Captures §6.2. | 7 |

---

## Task 1: Catégorie stockée sur la carte, schéma v6

**Files:**
- Create: `lib/models/card_category.dart`
- Modify: `lib/models/deck_model.dart` (`DeckCard`, l.3-37)
- Modify: `lib/data/database/app_database.dart` (table `DeckCards` l.60-71, `schemaVersion`, `onUpgrade`, `upsertDeckCard`) et régénérer `.g.dart`
- Modify: `lib/services/deck_service.dart` (`_dbDeckToDeck`, `upsertCardInDeck`, `updateDeck`, `moveCard`, `changeCardVersion`)
- Modify: `lib/utils/card_list_upsert_mixin.dart` (l.~60), `lib/services/backup_service.dart` (export + import des cartes de deck), `lib/data/migration/migration_service.dart` (`_migrateDeckCards`)
- Create: `test/data/app_database_migration_v6_test.dart`
- Modify: `test/models/deck_model_test.dart`, `test/services/deck_service_test.dart`

**Interfaces:**
- Produces:
  - `enum CardCategory { ramp, draw, removal, wipe, protection, tutor, lands, creatures, wincon, other }`. L'ordre de déclaration EST l'ordre d'affichage.
  - `String cardCategoryLabel(CardCategory c)` rend « Ramp », « Pioche », « Removal », « Wipe », « Protection », « Tuteur », « Terrains », « Créatures », « Win-con », « Autres ».
  - `CardCategory? cardCategoryFromName(String? s)` : `null` si inconnu.
  - `DeckCard.category: CardCategory?` (défaut `null`) et `DeckCard.categoryLocked: bool` (défaut `false`). JSON : `'category': category?.name`, `'categoryLocked'`.
  - Colonnes Drift `DeckCards.category` (`text().nullable()`) et `DeckCards.categoryLocked` (`boolean().withDefault(const Constant(false))`). `schemaVersion == 6`.
  - `AppDatabase.upsertDeckCard(..., {String? category, bool? categoryLocked})` : chaque paramètre fourni est écrit. Un paramètre absent laisse la valeur en place à la mise à jour, et prend le défaut à l'insertion.
  - `Future<void> DeckService.setCardCategory(String deckId, DeckBoard board, String scryfallId, CardCategory? category, {required bool locked})` (`DeckBoard` est l'enum de `deck_service.dart:12`).

- [ ] **Step 1: Tests**
  - **Modèle :** les défauts, l'aller-retour JSON, et un JSON ancien sans les clés qui se lit `null`/`false`. Un nom de catégorie inconnu se lit `null`.
  - **Migration v5→v6 :** même motif que `test/data/app_database_migration_v5_test.dart` du chantier C (DDL v5 écrit à la main, `PRAGMA user_version = 5`). Vérifier :
    - les cartes existantes ont `category == null` et `categoryLocked == false` ;
    - elles gardent `tags`, `quantity`, `proxyQuantity` et `isFoil` ;
    - `user_version` vaut 6.
  - **Service :** une carte en `CardCategory.removal`, verrouillée, garde sa catégorie et son verrou après chacun de ces chemins (Review Focus 3) :
    - `updateDeck` ;
    - `moveCard` main → side ;
    - `changeCardVersion` ;
    - `upsertCardInDeck(quantityToAdd: 1)` ;
    - un aller-retour export puis import de sauvegarde.
- [ ] **Step 2: Lancer, constater l'échec.** Run: `flutter test test/data test/models test/services/deck_service_test.dart`
- [ ] **Step 3: Implémenter.**
  - Marche `if (from < 6) { await m.addColumn(deckCards, deckCards.category); await m.addColumn(deckCards, deckCards.categoryLocked); }`. Régénérer le `.g.dart`.
  - Propager les deux champs sur CHAQUE chemin d'écriture listé dans **Files**. `changeCardVersion` crée une nouvelle ligne pour le nouvel identifiant : il doit recopier la catégorie et le verrou de l'ancienne.
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): categorie de jeu stockee sur la carte, schema v6`

---

## Task 2: Déduire la catégorie

**Files:**
- Modify: `lib/models/scryfall_card_model.dart` (parsing l.105-176)
- Create: `lib/services/card_category_service.dart`
- Test: `test/models/scryfall_card_oracle_text_test.dart` (créé), `test/services/card_category_service_test.dart` (créé)

**Interfaces:**
- Produces:
  - `ScryfallCard.oracleText: String`. Il vaut `json['oracle_text']` s'il est présent. Sinon, c'est la concaténation des `oracle_text` de `card_faces`, séparés par `'\n'`, et `''` à défaut.
  - Ne JAMAIS lire `printed_text` pour ce champ. `rulesText` le préfère et peut donc être en français, d'où un champ distinct.
  - `CardCategory classifyCard({required String typeLine, required String oracleText})`. C'est une fonction pure, sans état, insensible à la casse.

Règles, appliquées dans cet ordre (la première qui correspond gagne). Le motif « terrain d'abord » vient du fait qu'un terrain qui produit du mana n'est pas du ramp.

1. **Terrains :** `typeLine` contient « land » et pas « creature ». Les terrains-créatures relèvent de la règle 9.
2. **Wipe :** le texte contient « destroy all », « exile all », « each creature », « all creatures get -», « return all » ou « deals x damage to each creature ».
3. **Removal :** le texte contient l'un de ces motifs :
   - « destroy target », « exile target » ;
   - « counter target spell », « counter target » ;
   - « return target nonland permanent », « deals damage to target creature », « deals x damage to target » ;
   - « fights target », « target creature gets -» ;
   - « target player sacrifices », « each opponent sacrifices ».
4. **Ramp :**
   - le texte contient « add {», « add one mana », « add two mana » ou « mana of any color » ;
   - OU le texte contient « search your library for » et « land » et « onto the battlefield ».
5. **Tuteur :** le texte contient « search your library for a » et n'est pas classé à la règle 4.
6. **Pioche :** le texte contient « draw a card », « draw two cards », « draw three cards », « draws a card », « draw cards » ou « draw x cards ».
7. **Protection :** le texte contient « hexproof », « indestructible », « protection from », « phase out », « phases out » ou « can't be countered » ET le sort donne cette protection (« gain », « gains » ou « have »). Le seul mot-clé sur une créature ne suffit pas.
8. **Win-con :** le texte contient « you win the game », « loses the game », « each opponent loses », « extra combat » ou « infinite ».
9. **Créatures :** `typeLine` contient « creature ».
10. **Autres :** tout le reste.

- [ ] **Step 1: Tests de `oracleText`.** Utiliser des JSON Scryfall réduits.
  - Une carte simple.
  - Une carte double face : texte de la face avant et du verso, séparés par un saut de ligne.
  - Une carte split, dont les `card_faces` n'ont pas d'`image_uris` et dont la racine n'a pas d'`oracle_text`.
  - Une carte dont le `printed_text` est français : `oracleText` reste anglais.
- [ ] **Step 2: Tableau de cas pour `classifyCard`.** Un test par ligne, avec le texte oracle réel recopié de Scryfall :
  - « Sol Ring » (Artifact, « {T}: Add {C}{C}. ») → ramp ;
  - « Cultivate » → ramp ;
  - « Command Tower » → lands ;
  - « Dryad Arbor » (Land Creature) → creatures ;
  - « Swords to Plowshares » → removal ;
  - « Counterspell » → removal ;
  - « Wrath of God » → wipe ;
  - « Toxic Deluge » (« All creatures get -X/-X ») → wipe ;
  - « Demonic Tutor » → tutor ;
  - « Harmonize » → draw ;
  - « Heroic Intervention » → protection ;
  - « Thassa's Oracle » (« you win the game ») → wincon ;
  - « Llanowar Elves » (Creature, « Add {G} ») → ramp, parce que la règle 4 passe avant la 9 ;
  - « Grizzly Bears » → creatures ;
  - « Swiftfoot Boots » → protection ;
  - « Darksteel Colossus » (indestructible, mais ne le donne à rien) → creatures ;
  - « Dark Ritual » → ramp ;
  - « Brainstorm » → draw ;
  - un enchantement sans motif → other.

  Ces cas fixent la règle : en cas de désaccord, le tableau l'emporte sur un ajustement des motifs.
- [ ] **Step 3: Lancer, constater l'échec.**
- [ ] **Step 4: Implémenter.**
- [ ] **Step 5: Suite complète + analyse.**
- [ ] **Step 6: Commit** `feat(decks): deduire la categorie de jeu d'une carte depuis son texte oracle`

---

## Task 3: Catégoriser à l'ouverture, corriger à la main, mémoriser l'affichage

**Files:**
- Create: `lib/services/deck_view_prefs.dart`
- Modify: `lib/controllers/deck_detail_controller.dart` (`DeckDetailState` l.50-100, `loadInitialData` l.~125-136)
- Modify: `lib/services/deck_service.dart` (suppression d'un deck : effacer ses préférences)
- Test: `test/controllers/deck_detail_categories_test.dart` (créé), `test/services/deck_view_prefs_test.dart` (créé)

**Interfaces:**
- Consumes: Task 1 (`setCardCategory`, champs) et Task 2 (`classifyCard`, `oracleText`).
- Produces:
  - `enum DeckGrouping { category, type }`, `enum DeckLayout { grid, list }`.
  - `class DeckViewPrefs { final DeckGrouping grouping; final DeckLayout layout; }`. Défauts : `category` et `grid`.
  - `Future<DeckViewPrefs> loadDeckViewPrefs(AppDatabase db, String deckId)` et `Future<void> saveDeckViewPrefs(AppDatabase db, String deckId, DeckViewPrefs prefs)`. Ils utilisent la clé `'deck_view:<deckId>'`, une valeur JSON `{"grouping":"category","layout":"grid"}`, et `getSetting`/`setSetting`. Une valeur illisible rend les défauts.
  - `Future<void> deleteDeckViewPrefs(AppDatabase db, String deckId)`. Elle est appelée par la suppression d'un deck (Review Focus 5).
  - `DeckDetailState.viewPrefs: DeckViewPrefs`.
  - Sur `DeckDetailController` : `setGrouping(DeckGrouping)` et `setLayout(DeckLayout)`, qui persistent ; `setCategory(DeckCard card, DeckBoard board, CardCategory category)`, qui verrouille ; `resetCategory(DeckCard card, DeckBoard board)`, qui déverrouille, re-déduit et persiste.
  - `CardCategory displayCategory(DeckCard card)` (méthode ou fonction) rend `card.category ?? CardCategory.other`.

C'est ici que la spec dit « à l'ajout et à l'import ». Tous les chemins d'ajout convergent vers `upsertDeckCard`, qui n'a que l'identifiant et le nom, pas le texte de la carte. La déduction a donc lieu là où le texte est disponible : dans `loadInitialData`, juste après `_loadFullCardData`. Chaque carte qui remplit les trois conditions suivantes reçoit `classifyCard(...)` en un lot, persisté :
- `category == null` ;
- `!categoryLocked` ;
- présente dans `fullCardData`.

Cela couvre le premier affichage après n'importe quel ajout ou import, ainsi que la migration (cartes à `null`). Le sélecteur de cartes de la page (`addCardsFromPicker`) relance déjà `loadInitialData`. Les cartes `LOCAL:` ne sont pas déduites (Review Focus 2).

- [ ] **Step 1: Tests.** Contrôleur réel, base `NativeDatabase.memory()`, `fullCardData` injecté.
  - L'ouverture catégorise les cartes à `null` et persiste ; une seconde ouverture ne réécrit rien.
  - Une carte verrouillée en `wincon`, dont le texte dirait `removal`, reste `wincon` après ouverture.
  - Après `setCategory`, la carte est verrouillée. Après `resetCategory`, elle est déverrouillée et re-déduite.
  - Une carte `LOCAL:` reste à `null` et `displayCategory` rend `other`.
  - Préférences : défauts, aller-retour, JSON corrompu → défauts, et la suppression du deck efface la clé.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter.**
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): categoriser a l'ouverture, corriger a la main, memoriser l'affichage par deck`

---

## Task 4: La liste — catégories au-dessus de grilles d'artworks

**Files:**
- Create: `lib/utils/deck_metrics.dart`
- Modify: `lib/widgets/decks/deck_card_list_tab.dart`
  - `_gridColumns` l.61, le slider l.~186 et le pincement l.101-104 ;
  - `_buildGroupedList` l.~519-532 ;
  - `_showCardOptions` l.~285.
- Modify: `lib/widgets/decks/deck_card_title.dart`
  - `DeckCardTile` : retirer `price` (l.42) et sa ligne de sous-titre ;
  - `DeckCardGridTile` : paramètre `categoryLocked`.
- Modify: `lib/widgets/decks/deck_stats_tab.dart` : le CMC moyen passe par `averageManaValue`.
- Test: `test/utils/deck_metrics_test.dart`, `test/widgets/decks/deck_card_list_tab_test.dart` (étendu), `test/widgets/decks/deck_card_title_test.dart` (étendu)

**Interfaces:**
- Consumes: Task 3 (`viewPrefs`, `setGrouping`, `setLayout`, `setCategory`, `resetCategory`, `displayCategory`).
- Produces:
  - `double averageManaValue(Iterable<DeckCard> cards, List<ScryfallCard> fullCardData)`. La règle existante de `DeckStatsTab._calculateStats` (deck_stats_tab.dart:61-92) devient la seule source :
    - pondérée par la quantité ;
    - terrains exclus (`typeLine` contient « land ») ;
    - identifiants `LOCAL:` ignorés ;
    - `0.0` s'il n'y a aucune carte comptée.
  - `int deckCardGridColumns(double width)` rend `(width / 130).floor().clamp(3, 8)`.
  - Nouveaux paramètres de `DeckCardListTab` :
    - `required DeckViewPrefs viewPrefs` ;
    - `required ValueChanged<DeckGrouping> onGrouping` ;
    - `required ValueChanged<DeckLayout> onLayout` ;
    - `required void Function(DeckCard, CardCategory) onSetCategory` ;
    - `required ValueChanged<DeckCard> onResetCategory`.

Changements :
- **Barre d'outils :** le slider 1..5 et le pincement disparaissent. Ils sont remplacés par les deux interrupteurs de la maquette (« Catégorie | Type », grille | liste, cibles de 48 px de haut). Le compte de cartes et les boutons d'export existants restent.
- **Mode `category` :**
  - une section par `CardCategory` non vide, dans l'ordre de l'enum ;
  - en-tête en capitales or, puis « n · CMC moyen x,y » (n = somme des quantités ; `averageManaValue` de la section, virgule décimale ; mention omise si 0) ;
  - tri par nom dans la section.
- **Mode `type` :** le groupement actuel est inchangé.
- **Mode `grid` :** grille de `deckCardGridColumns(largeur disponible)` colonnes, avec `DeckCardGridTile`, dont la quantité et le coût de mana sont déjà portés. Une carte `categoryLocked` reçoit un liseré `AppColors.primary` de 2 px et une icône `Icons.lock` de 11 px avec le `Semantics` « Catégorie corrigée à la main ».
- **Mode `list` :** `DeckCardTile`, désormais sans prix.
- **Options d'une carte :**
  - une entrée « Catégorie… » ouvre la liste des dix libellés et appelle `onSetCategory` ;
  - si la carte est verrouillée, une entrée « Déduire automatiquement » appelle `onResetCategory`.
- Le `LongPressDraggable` et ses données `{'card', 'sourceBoard'}` ne changent pas : la tâche 6 en dépend.

- [ ] **Step 1: Tests**
  - **`averageManaValue` :** pondération, terrains exclus, `LOCAL:` ignoré, 0,0 sans carte.
  - **`deckCardGridColumns` :** 390 → 3, 840 → 6, 1280 → 8.
  - **Onglet monté avec des préférences par défaut :**
    - c'est une grille, aucun `DeckCardTile` n'est présent ;
    - les en-têtes apparaissent dans l'ordre Ramp, puis Removal, puis Créatures, pour des cartes de ces catégories ;
    - l'en-tête porte « 2 · CMC moyen 1,5 » pour deux cartes de CMC 1 et 2.
  - **Bascules :**
    - l'interrupteur « Type » appelle `onGrouping(DeckGrouping.type)` ;
    - avec `type`, on retrouve les en-têtes actuels (Créatures, Sorts…) ;
    - l'icône liste appelle `onLayout(DeckLayout.list)`.
  - **Vignettes et tuiles :**
    - une carte verrouillée porte l'icône de cadenas ;
    - `DeckCardTile` n'affiche plus de « € ».
  - **Options :** « Catégorie… » puis « Pioche » appelle `onSetCategory(card, CardCategory.draw)`.
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter.**
- [ ] **Step 4: Suite complète + analyse.** Les goldens 10 à 13 de `test/captures/identite_tirage_langue_captures_test.dart` changent, puisque le prix quitte `DeckCardTile`. Les régénérer et les regarder.
- [ ] **Step 5: Commit** `feat(decks): cartes groupees par categorie en grille d'artworks`

---

## Task 5: Le bandeau du commandant

**Files:**
- Rewrite: `lib/widgets/decks/deck_commander_header.dart`. Le fichier n'a aujourd'hui aucun appelant.
- Modify: `lib/pages/decks/deck_detail_page.dart`
  - supprimer `_buildCommanderHeader` / `_buildSingleCommander` (l.520-595) et monter `DeckCommanderHeader` ;
  - le titre de l'AppBar se vide : le nom vit dans le bandeau. Le retour et les actions restent.
- Modify: `lib/controllers/deck_detail_controller.dart` : `powerLevel` dans l'état, calculé après `_loadFullCardData`.
- Test: `test/widgets/decks/deck_commander_header_test.dart` (créé)

**Interfaces:**
- Consumes: Task 4 (`averageManaValue`), `DeckPowerLevelService.estimatePowerLevel({deck, fullCardData, commanderScryfallId})` (lib/services/deck_power_level_service.dart:15, rend `null` sans commandant), `ScryfallImage` (lib/widgets/cards/scryfall_image.dart).
- Produces:
  - `DeckDetailState.powerLevel: DeckPowerLevel?` ;
  - `DeckCommanderHeader({required Deck deck, required List<ScryfallCard> fullCardData, required int cardCount, required double averageManaValue, required DeckPowerLevel? powerLevel, required double totalPrice})`.

Rendu (maquette et spec §3.1) :
- **Hauteur :** fixe de 180 dans les trois cas.
- **Un commandant :** son art (`artCropUrl ?? imageUrl` de la `ScryfallCard`, sinon `ScryfallApi.artCropRedirectUrl(id)`) en `ScryfallImage` plein cadre.
- **Partenaire :** deux arts côte à côte, chacun sur la moitié de la largeur.
- **Aucun commandant :** fond uni `MagicPalette.of(context).raised` et le message « Aucun commandant défini », à la même hauteur.
- **Pied :**
  - dégradé sombre ;
  - le nom du deck ;
  - la rangée : pastilles de couleur (ronds de mana `AppColors`, comme la tuile du chantier C), « n cartes », « CMC moyen x,y », la pilule « Power n » si `powerLevel` n'est pas nul, et le prix en dernier, aligné à droite, couleur atténuée (`textMuted`).
- **Rangée sur petite largeur :** à 390 de large, elle passe à la ligne sans déborder (`Wrap`), le prix restant en dernier.

Le power level est calculé sans données EDHREC. Le service rend alors des facteurs par défaut (synergie et qualité à 5,0) : c'est une estimation. Le badge affiche le score entier, sans prétendre à plus.

- [ ] **Step 1: Tests**
  - même hauteur (180) avec un commandant, deux et aucun ;
  - sans commandant : « Aucun commandant défini » ;
  - partenaire : deux `ScryfallImage` ;
  - l'ordre des textes de la rangée finit par le prix (comparer les `dx` à 840 de large) ;
  - « CMC moyen 3,2 » avec la virgule ;
  - pas de pilule Power sans power level ;
  - pas de débordement à 390 de large (`tester.takeException()` nul).
- [ ] **Step 2: Lancer, constater l'échec.**
- [ ] **Step 3: Implémenter et brancher.**
- [ ] **Step 4: Suite complète + analyse.**
- [ ] **Step 5: Commit** `feat(decks): bandeau du commandant avec les stats de jeu`

---

## Task 6: Quatre onglets, sélecteur de board qui accepte le dépôt

**Files:**
- Create: `lib/widgets/decks/deck_board_selector.dart`, `lib/widgets/decks/deck_info_tab.dart`
- Modify: `lib/pages/decks/deck_detail_page.dart`
  - `TabController(length: 8)` l.43 ;
  - `TabBar`/`TabBarView` l.385-512 ;
  - `_buildDragTargetTab` l.597-628 et ses index de board codés en dur l.606-612.
- Modify: `lib/widgets/decks/deck_tokens_tab.dart` : une variante sans `ListView` propre, pour vivre dans le défilement d'Infos.
- Test: `test/widgets/decks/deck_board_selector_test.dart` (créé)

**Interfaces:**
- Consumes: Task 4 (`DeckCardListTab` et ses données glissées `Map<String, dynamic>` `{'card': DeckCard, 'sourceBoard': DeckBoard}`).
- Produces:
  - `DeckBoardSelector({required DeckBoard selected, required Map<DeckBoard, int> counts, required ValueChanged<DeckBoard> onSelect, required void Function(DeckCard card, DeckBoard from, DeckBoard to) onDrop})` ;
  - `DeckInfoTab({required List<TokenInfo> tokens, required LegalityReport report})`.

Onglets, quatre de largeur égale (`isScrollable: false`) :
- **Liste :** le `DeckBoardSelector`, puis le `DeckCardListTab` du board sélectionné. L'état `_selectedBoard` est dans la page, défaut `main`.
- **Stats :** `DeckStatsTab`, inchangé.
- **Suggestions :** `DeckSuggestionsTab`, inchangé.
- **Infos :** `DeckInfoTab`, un seul défilement : section « Tokens (n) », puis section « Légalité » (le contenu de `DeckLegalityTab`).

L'entrée de menu « Légalité » (`_showValidationResults`) reste, puisque rien n'est supprimé.

Chaque puce du sélecteur est un `DragTarget<Map<String, dynamic>>` qui reprend EXACTEMENT la logique de l'ancien `_buildDragTargetTab` :
- il refuse si `sourceBoard == board` ;
- sinon il appelle `onDrop(card, source, board)`. La page y branche `_handleMoveCard` puis `setState(() => _selectedBoard = board)`, qui remplace l'ancien `animateTo` par index ;
- le survol fait apparaître un fond `primaryShade900` à 50 % d'opacité ;
- le libellé est « Main 107 », etc. ;
- la puce active est pleine or ;
- chaque puce mesure au moins 48 px de haut.

C'est le point de régression le plus probable du chantier : le test de dépôt passe par de VRAIS gestes, pas par un appel direct à `onDrop`.

- [ ] **Step 1: Test dédié du dépôt.** Monter `DeckBoardSelector` au-dessus d'un `LongPressDraggable<Map<String, dynamic>>` qui porte `{'card': c, 'sourceBoard': DeckBoard.main}`. Motif de geste : `test/pages/life_counter/reorder_rotation_test.dart`, appui long, déplacement, relâcher.
  - Déposé sur « Side », `onDrop(c, main, side)` est appelé une fois.
  - Déposé sur « Main » (même board), rien n'est appelé (Review Focus 4).
  - Déposé sur « Wishlist 0 » (board vide), l'appel a lieu.
  - Pendant le survol, la puce visée affiche son fond de survol.
- [ ] **Step 2: Test de page.**
  - `DeckDetailPage` monté : quatre onglets exactement, dans l'ordre « Liste », « Stats », « Suggestions », « Infos » ;
  - un dépôt réel d'une carte du main sur « Side » la déplace (relue dans `sideboard` via le contrôleur) et sélectionne « Side ».
  - Si la page n'est pas montable en test (vérifier ses dépendances avant d'écrire le test), le dire dans le rapport et tester le câblage page → `_handleMoveCard` au plus près.
- [ ] **Step 3: Test d'Infos.** Les deux sections sont présentes dans un seul défilement, sans exception de défilements imbriqués.
- [ ] **Step 4: Lancer, constater l'échec.**
- [ ] **Step 5: Implémenter.**
- [ ] **Step 6: Suite complète + analyse.**
- [ ] **Step 7: Commit** `feat(decks): quatre onglets, selecteur de board qui accepte le depot`

---

## Task 7: Captures §6.2

**Files:**
- Create: `test/captures/deck_page_captures_test.dart` (tag `capture`). Copier le préambule de polices de `test/captures/grimoire_captures_test.dart`.

La spec §6.2 exige :
- la page deck avec un commandant, avec un partenaire, et sans commandant ;
- la grille d'artworks groupée par catégorie, qui est le défaut, ET la liste compacte.

Capturer à 840×700 et 390×844 :
- le bandeau dans ses trois états ;
- l'onglet Liste en grille par catégorie, avec une carte verrouillée ;
- la même liste en mode liste compacte.

Monter la page entière si la tâche 6 a établi qu'elle l'est, sinon l'assemblage `DeckCommanderHeader` + `DeckBoardSelector` + `DeckCardListTab`. Sans réseau en test, les arts affichent leurs replis : c'est attendu, à noter.

- [ ] **Step 1: Écrire et générer.** Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/deck_page_captures_test.dart`
- [ ] **Step 2: Regarder chaque image.** Vérifier la hauteur du bandeau identique dans les trois états, l'ordre des stats avec le prix en dernier, les en-têtes de catégorie, le cadenas, l'absence de prix sur les vignettes et le sélecteur de board.
- [ ] **Step 3: Commit** `test(captures): page d'un deck, bandeau, categories et liste compacte`

---

## Hors de ce plan

- Les catégories EDHREC de l'onglet Suggestions (« Pick spécifique », « Staple générique ») : ce sont des en-têtes de suggestions, pas des rôles de cartes. Elles ne changent pas.
- La duplication du calcul de type :
  - `DeckStatsController.getPrimaryType` ;
  - `DeckStatsTab._getPrimaryType` ;
  - `DeckCardListTab._getPrimaryType`.

  Le mode « Type » conserve celui de la liste, inchangé. L'unification n'est pas demandée.
- `DeckStatsController` est du code mort, utilisé seulement par son test : il est laissé en place.
