# Sprint 8 - Analyse Business : Widgets, Qualite & Polish
> Agent : Zorro (Business Analyst) | Date : 28/02/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG.

**Point de douleur central** : Apres 7 sprints de refactoring progressif (score qualite 5.5 -> 9.0/10), le projet presente encore **17 fichiers > 500 lignes** dont 5 widgets et 5 pages qui melangent logique et UI. De plus, **1041 infos** flutter analyze polluent la sortie (583 prefer_single_quotes, 181 deprecated_member_use/withOpacity, 78 prefer_const_constructors, 57 curly_braces), 333 appels GoogleFonts et 1536 Color/Colors hardcodes ne sont pas centralises dans le ThemeData, et le routeur app_router.dart est un monolithe de 713 lignes.

**Objectif Sprint 8** : Decomposer les 4 God Widgets en extrayant des controllers, refactorer app_router.dart en sous-routeurs, extraire les sous-widgets des pages volumineuses pour les ramener sous 400 lignes, resoudre les 1041 infos flutter analyze, et centraliser GoogleFonts + Colors dans le theme. Objectif : **0 fichier applicatif > 500 lignes**, score qualite **9.5/10**, >300 tests.

---

## 2. Analyse de la Cause Racine

1. **Extraction incomplete au Sprint 7** : Les controllers Riverpod ont ete extraits pour les pages, mais le code UI pur reste volumineux (modals, tile builders, action bars inline dans les pages). Les widgets n'ont pas ete traites. Resultat : 5 pages restent >500 lignes malgre la logique extraite.

2. **Pas de centralisation du style** : Les 333 GoogleFonts.cinzel, 150 Color() hardcodes et 1386 Colors.xxx ne passent pas par le ThemeData. Chaque widget redefinit ses styles localement, ce qui augmente les lignes et rend le changement de theme impossible.

3. **Widgets autonomes trop gros** : collection_list_tab (716), player_zone (674), deck_card_picker (774), deck_stats_tab (612), game_setup_modal (507) contiennent de la logique metier (filtrage, recherche, calculs stats) melangee avec le rendu UI, sans controller Riverpod associe.

4. **Routeur monolithique** : app_router.dart (713 lignes) definit 23 routes, le ShellRoute, le Drawer, et des factory builders dans un seul fichier, rendant l'ajout de routes difficile.

5. **Infos analyse non resolues** : Les 1041 infos (prefer_single_quotes, withOpacity deprecated, curly_braces) ont ete ignorees durant les sprints precedents car elles n'empechaient pas la compilation, mais elles degradent la lisibilite et masquent les vrais problemes.

---

## 3. Inventaire des fichiers cibles

### Widgets God Files (>500 lignes)

| # | Fichier | Lignes | Responsabilites melangees |
|---|---------|--------|---------------------------|
| 1 | `deck_card_picker.dart` | 774 | Recherche API/locale, pagination, selection multi, filtres, cache, UI |
| 2 | `collection_list_tab.dart` | 716 | Affichage liste, filtres, tri, tags, selection, actions contextuelles, finance, UI |
| 3 | `player_zone.dart` | 674 | Compteurs (vie/poison/energie/commanderTax), couleurs, skins, gestes, menus, image picker, UI |
| 4 | `deck_stats_tab.dart` | 612 | Calculs mana curve, repartition types, pip count, source count, color by type, graphiques fl_chart, UI |
| 5 | `game_setup_modal.dart` | 507 | Configuration partie, profils, formats, timer, nombre joueurs, UI |

### Pages encore >500 lignes (UI volumineuse post-Sprint 7)

| # | Fichier | Lignes | Cause |
|---|---------|--------|-------|
| 1 | `set_detail_page.dart` | 1039 | Modals de filtres (~150 lignes), wishlist picker (~80 lignes), tile builder, bottom bar inline |
| 2 | `deck_detail_page.dart` | 597 | TabBar multi-zones, modals partage, UI complexe |
| 3 | `deck_list_page.dart` | 539 | Search bar, list tiles, dialogs, FAB menu |
| 4 | `card_search_page.dart` | 537 | Barre recherche, resultats, pagination, filtres inline |
| 5 | `card_detail_page.dart` | 508 | Affichage carte double-face, rulings, actions, UI |

### Routeur

| Fichier | Lignes | Probleme |
|---------|--------|----------|
| `app_router.dart` | 713 | 23 routes + ShellRoute + Drawer + builders dans un seul fichier |

### Infos flutter analyze

| Regle | Occurrences | Type correction |
|-------|-------------|-----------------|
| prefer_single_quotes | 583 | Script automatique (search/replace `"` -> `'`) |
| deprecated_member_use (withOpacity) | 181 | `.withValues(alpha: x)` (Flutter 3.27+) |
| prefer_const_constructors | 78 | Ajouter `const` devant les constructeurs eligibles |
| unnecessary_non_null_assertion | 74 | Retirer les `!` inutiles |
| curly_braces_in_flow_control_structures | 57 | Ajouter `{}` aux if/for/while |
| use_build_context_synchronously | 23 | Verifier `mounted` avant utilisation |
| unnecessary_underscores | 19 | Renommer les variables inutilisees |
| empty_catches | 10 | Ajouter un commentaire ou un log |
| Divers (5 regles) | 16 | Corrections ponctuelles |

---

## 4. User Stories

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points |
|----------|----|----------------|------------|------------|--------|-------------|
| 1 | US-8.1 | Developpeur | resoudre les 1041 infos flutter analyze (quotes, withOpacity, const, braces, non_null_assertion) | avoir un `flutter analyze` propre (0 infos) et ne plus masquer les vrais problemes | Must | 3 |
| 2 | US-8.2 | Developpeur | extraire la logique metier des 4 widgets God Files (deck_card_picker, collection_list_tab, player_zone, deck_stats_tab) dans des controllers Riverpod | separer logique et UI, rendre les widgets testables unitairement | Must | 8 |
| 3 | US-8.3 | Developpeur | extraire les sous-widgets des 5 pages encore >500 lignes pour les ramener sous 400 lignes | ameliorer la lisibilite et la maintenabilite des pages | Must | 5 |
| 4 | US-8.4 | Developpeur | decouper app_router.dart (713 lignes) en sous-routeurs thematiques | faciliter l'ajout de nouvelles routes et reduire la taille du fichier | Should | 2 |
| 5 | US-8.5 | Developpeur | centraliser les 333 GoogleFonts et les 1536 Color/Colors hardcodes dans le ThemeData | permettre le theming et reduire la duplication de style | Should | 5 |

**Total : 23 Story Points (~15 jours)**

---

## 5. Criteres d'Acceptation (Gherkin/BDD)

### US-8.1 : Resolution infos flutter analyze

```gherkin
Fonctionnalite: Analyse statique propre
  Scenario: Zero info apres nettoyage
    Etant donne que le projet contient 1041 infos flutter analyze
    Quand le developpeur execute flutter analyze
    Alors le resultat affiche 0 issues (0 errors, 0 warnings, 0 infos)

  Scenario: Pas de regression des tests
    Etant donne que 273 tests passent avant le nettoyage
    Quand le nettoyage est applique (quotes, withOpacity, const, braces)
    Alors tous les 273 tests passent toujours

  Scenario: withOpacity remplace par withValues
    Etant donne qu'il y a 148 appels .withOpacity() dans lib/
    Quand le remplacement est effectue vers .withValues(alpha: x)
    Alors 0 appel .withOpacity() subsiste dans lib/
```

### US-8.2 : Extraction controllers widgets

```gherkin
Fonctionnalite: Controllers pour widgets God Files
  Scenario: DeckCardPickerController extrait
    Etant donne que deck_card_picker.dart contient 774 lignes avec logique de recherche/pagination
    Quand le DeckCardPickerController est cree
    Alors deck_card_picker.dart ne contient que du code UI
    Et lib/controllers/deck_card_picker_controller.dart existe
    Et au moins 5 tests unitaires couvrent le controller

  Scenario: CollectionListController extrait
    Etant donne que collection_list_tab.dart contient 716 lignes avec logique de filtrage/tri
    Quand le CollectionListController est cree
    Alors collection_list_tab.dart ne contient que du code UI
    Et lib/controllers/collection_list_controller.dart existe
    Et au moins 5 tests unitaires couvrent le controller

  Scenario: PlayerZoneController extrait
    Etant donne que player_zone.dart contient 674 lignes avec logique de compteurs/skins
    Quand le PlayerZoneController est cree
    Alors player_zone.dart ne contient que du code UI
    Et lib/controllers/player_zone_controller.dart existe
    Et au moins 4 tests unitaires couvrent le controller

  Scenario: DeckStatsController extrait
    Etant donne que deck_stats_tab.dart contient 612 lignes avec calculs statistiques
    Quand le DeckStatsController est cree
    Alors deck_stats_tab.dart ne contient que du code UI
    Et lib/controllers/deck_stats_controller.dart existe
    Et au moins 4 tests unitaires couvrent le controller
```

### US-8.3 : Extraction sous-widgets des pages volumineuses

```gherkin
Fonctionnalite: Pages sous 400 lignes
  Scenario: set_detail_page decomposee
    Etant donne que set_detail_page.dart contient 1039 lignes de code UI
    Quand les modals de filtres, le wishlist picker, le tile builder et la bottom bar sont extraits en sous-widgets
    Alors set_detail_page.dart contient moins de 400 lignes
    Et les sous-widgets sont dans lib/widgets/collections/

  Scenario: Toutes les pages sous 500 lignes
    Etant donne que 5 pages depassent 500 lignes
    Quand les sous-widgets sont extraits
    Alors aucune page dans lib/pages/ ne depasse 500 lignes

  Scenario: Pas de regression
    Etant donne que les sous-widgets sont extraits mecaniquement
    Quand flutter test est execute
    Alors tous les tests passent
```

### US-8.4 : Decoupage app_router.dart

```gherkin
Fonctionnalite: Routeur modulaire
  Scenario: Sous-routeurs thematiques
    Etant donne que app_router.dart contient 713 lignes et 23 routes
    Quand les routes sont decoupees en sous-routeurs (life_counter_routes, cards_routes, decks_routes, collections_routes, settings_routes)
    Alors app_router.dart contient moins de 200 lignes
    Et chaque sous-routeur contient ses propres routes
    Et toute la navigation fonctionne identiquement

  Scenario: Pas de regression navigation
    Etant donne que 23 routes sont definies
    Quand le routeur est decoupe
    Alors chaque route reste accessible avec le meme path
    Et le deep linking fonctionne toujours
```

### US-8.5 : Centralisation Theme

```gherkin
Fonctionnalite: Theme centralise
  Scenario: GoogleFonts centralise
    Etant donne qu'il y a 333 appels GoogleFonts.cinzel disperses dans 40+ fichiers
    Quand un AppTextTheme est cree dans lib/theme/
    Alors les styles texte sont definis dans le ThemeData
    Et les widgets utilisent Theme.of(context).textTheme au lieu de GoogleFonts directement
    Et les appels GoogleFonts dans les fichiers applicatifs sont reduits de >80%

  Scenario: Couleurs centralisees
    Etant donne qu'il y a 150 Color() hardcodes et 1386 Colors.xxx dans lib/
    Quand un AppColorScheme est cree dans lib/theme/
    Alors les couleurs principales sont definies dans ColorScheme
    Et les couleurs specifiques MTG (mana, rarete) sont dans une extension de ThemeData
    Et les Colors hardcodes sont reduits de >50%
```

---

## 6. Contraintes & Hypotheses

### Contraintes
- **Stack figee** : Flutter/Dart, Riverpod, drift, go_router, Dio -- pas de changement de stack
- **Tests existants** : Les 273 tests doivent rester verts a chaque etape
- **Retrocompatibilite** : Aucune regression fonctionnelle pour l'utilisateur
- **Flutter 3.27+** : Necessaire pour `.withValues()` (remplacement de `.withOpacity()`)
- **Pas d'i18n** : L'internationalisation est repoussee a un sprint ulterieur
- **Pas de chiffrement BDD** : Le chiffrement SQLite est repoussee a un sprint ulterieur

### Hypotheses
- Le Sprint 7 est entierement termine et stable (273 tests verts confirmes)
- Les 6 controllers existants (Sprint 7) ne necessitent pas de modification
- Le pattern StateNotifier utilise au Sprint 7 sera reutilise pour les nouveaux controllers
- L'extraction de sous-widgets est principalement mecanique (copier/coller + parametrage)
- Le remplacement withOpacity -> withValues est safe car Flutter >=3.27 est utilise (sdk ^3.9.2)

---

## 7. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|-------------------------|
| R-8.1 | Regression UI lors de l'extraction des sous-widgets des pages | Moyenne | Haut | Extraire un widget a la fois, verifier visuellement apres chaque extraction |
| R-8.2 | Script replace_single_quotes modifie des strings contenant des apostrophes | Faible | Moyen | Utiliser `dart fix` ou un script aware du contexte (pas un sed aveugle) |
| R-8.3 | withValues() non disponible sur la version Flutter en cours | Faible | Haut | Verifier la version Flutter avant de commencer (>= 3.27 requis) |
| R-8.4 | Le decoupage du routeur casse la navigation Shell | Moyenne | Haut | Tester chaque route manuellement apres decoupage, garder les tests existants |
| R-8.5 | La centralisation du theme cree des conflits de style dans certains widgets | Moyenne | Moyen | Migrer fichier par fichier, comparer visuellement avant/apres |
| R-8.6 | Sprint trop ambitieux (23 SP, ~15j) | Moyenne | Moyen | US-8.5 (theme) est repoussable en Sprint 9 si le sprint prend du retard |
| R-8.7 | Les controllers widgets cassent l'interaction avec les controllers pages existants | Faible | Haut | Les controllers widgets ne doivent pas dependre des controllers pages, seulement des services |

---

## 8. Dependances & Carte des Parties Prenantes

### Dependances internes
- **US-8.1 doit etre fait en premier** : resoudre les infos analyse avant de toucher le code (evite les conflits de merge)
- **US-8.2 depend de US-8.1** : les controllers extraits doivent etre propres des le depart
- **US-8.3 depend de US-8.2** : certaines pages volumineuses le sont a cause de logique qui sera dans les controllers widgets
- **US-8.4 est independant** : peut etre fait en parallele avec US-8.2/8.3
- **US-8.5 depend de US-8.1** : le remplacement des couleurs doit se faire apres le nettoyage des quotes/const

### Ordre d'execution recommande

```
US-8.1 (Quick wins analyse) ─┬─> US-8.2 (Controllers widgets) ──> US-8.3 (Sous-widgets pages)
                              │
                              └─> US-8.4 (Routeur) [parallele]
                              │
                              └─> US-8.5 (Theme) [dernier]
```

### Parties prenantes

| Partie prenante | Role | Interet | Influence |
|----------------|------|---------|-----------|
| Alexis (dev) | Developpeur unique, mainteneur | Tres haut | Tres haute |
| Utilisateurs MTG | Utilisateurs finaux | Moyen (pas de nouvelles fonctionnalites) | Faible |
| CI/CD (GitHub Actions) | Pipeline automatise | Haut (doit rester vert) | Haute |

---

## 9. Estimation

| User Story | Effort | Priorite | Dependances |
|------------|--------|----------|-------------|
| US-8.1 : Quick wins flutter analyze | 2j | P0 | Aucune |
| US-8.2 : Extraction 4 controllers widgets | 5j | P0 | US-8.1 |
| US-8.3 : Extraction sous-widgets pages | 3j | P0 | US-8.2 |
| US-8.4 : Decoupage app_router.dart | 1.5j | P1 | Aucune |
| US-8.5 : Centralisation theme | 3.5j | P2 | US-8.1 |
| **Total** | **15j** | -- | -- |

### Scope ajustable (si retard)

Si le sprint prend du retard, les US peuvent etre repoussees dans cet ordre :
1. **US-8.5** (theme) -> Sprint 9 (P2, 3.5j) -- le plus gros effort non-critique
2. **US-8.4** (routeur) -> Sprint 9 (P1, mais independant)
3. Les US-8.1 a US-8.3 sont **P0 et non negociables**

---

## 10. Hors Scope Sprint 8

- Internationalisation (i18n) avec fichiers ARB -> Sprint 9+
- Chiffrement BDD SQLite -> Sprint 9+
- Mise a jour automatique base locale (Bulk Data Scryfall) -> Sprint 9+
- Optimisation scanner ML Kit -> Sprint 9+
- Resolution dependency overrides ML Kit -> Sprint 9+
- Syntaxe de recherche Scryfall avancee -> Sprint 9+
- Notifications push (Firebase Messaging) -> Sprint 9+

*"Cinq widgets, cinq coupes. Chaque controller sera aussi tranchant que Wado Ichimonji. Les 1041 infos vont tomber comme les feuilles sous Ittoryu Iai."* -- Zorro
