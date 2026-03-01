# Magic Companion - Roadmap & Plan d'Action Global

> Genere le 26/02/2026 par Mugiwara (Pipeline de Construction)
> Mis a jour le 01/03/2026 -- Sprint 8 en pause (backlog technique), Sprint 9 lance (Quick Wins Features)
> Synthetise les travaux de Brook (Doc), Doc-Hunt (API Scryfall), Nami (Audit QA), Yamato (Veille Features)

---

## 1. Vision et Contexte

Magic Companion est une application Flutter riche en fonctionnalites pour les joueurs de Magic: The Gathering. L'app couvre un large spectre : compteur de vie, scanner de cartes, recherche, gestion de decks, collection, wishlists, oracle IA, et plus encore.

Cependant, l'audit Nami revele que l'architecture souffre de dettes techniques significatives qui freinent l'evolution, la testabilite et la robustesse. Ce plan d'action vise a consolider les fondations tout en preparant l'app pour les fonctionnalites futures.

**Chiffres cles du projet** :
- 74 fichiers Dart, 19 675 lignes de code
- 12 services, 10 modeles, 19 pages, 15+ widgets
- Score qualite : 5.5/10
- Couverture tests : 0%

---

## 2. Etat des Lieux (Synthese des Agents)

### Ce qui fonctionne bien
- Fonctionnalites riches et variees couvrant tous les besoins d'un joueur MTG
- Separation claire des couches (models/services/pages/widgets)
- Recherche locale performante via Isolate (compute) sur ~27 000 cartes
- Cache d'images Scryfall centralise (widget ScryfallImage + CachedNetworkImage)
- Sauvegarde automatique Google Drive avec scope minimal (driveFileScope)
- Migration automatique des donnees legacy (wishlists v1 -> v2)
- Integration multi-API (Scryfall, EDHRec, Firebase Cloud Functions)
- CI/CD existant (GitHub Actions : build, release, Firebase App Distribution)
- Semantic versioning automatique dans le pipeline

### Ce qui doit etre corrige (valeurs exactes)
- **Riverpod declare mais non utilise** : 0 Provider defini malgre ProviderScope en place
- **SharedPreferences comme BDD** : 27 acces dans 12 fichiers -- serialisation O(n) a chaque operation
- **Zero tests** : 1 fichier test qui ne compile pas (reference `MyApp` au lieu de `MagicCompanionApp`)
- **Pas d'injection de dependances** : Services instancies manuellement dans chaque page
- **Anti-patterns Dart** : 66 firstWhere dont ~15 avec catch comme flow control, 37 catch generiques
- **God Files** : 12 fichiers > 500 lignes (max 998 lignes pour set_detail_page.dart)
- **Logging absent** : 17 print() dans 11 fichiers, regle avoid_print desactivee
- **Navigation imperative** : 152 appels Navigator.push/pop dans 30 fichiers
- **Dependance inutilisee** : dio declare mais jamais importe (tous les appels utilisent http)
- **Pipeline CI incomplet** : ni `flutter analyze` ni `flutter test` dans le workflow

### Documentation API disponible
La reference complete de l'API Scryfall a ete documentee (voir `docs/SCRYFALL_API_REFERENCE.md`), couvrant :
- Tous les endpoints Cards (search, named, collection, etc.)
- Structure complete de l'objet Card et ses variantes (double-face, etc.)
- Endpoints Sets, Rulings, Symbology, Catalogs, Bulk Data
- Rate limiting et bonnes pratiques d'utilisation
- Correspondance app <-> API

---

## 3. Roadmap par Sprints

### Sprint 1 : Fondations (Semaines 1-2)

**Objectif** : Rendre le projet testable et eliminer les anti-patterns critiques.

| Tache                                     | Type        | Effort | Priorite | Fichiers concernes |
|-------------------------------------------|-------------|--------|----------|--------------------|
| Corriger `widget_test.dart` (MyApp -> MagicCompanionApp) | Fix | 0.5j | P0 | `test/widget_test.dart` |
| Corriger l'anti-pattern firstWhere/catch dans les services | Refactor | 1j | P1 | `collection_service.dart`, `deck_service.dart`, `wishlist_service.dart` |
| Corriger les catch generiques dans les pages (37 occurrences) | Refactor | 1j | P1 | `deck_detail_page.dart` (3), `card_detail_page.dart` (5), +12 fichiers |
| Activer `avoid_print` + regles strictes dans `analysis_options.yaml` | DevOps | 0.5j | P1 | `analysis_options.yaml` |
| Remplacer les 17 print() par dart:developer log() | Cleanup | 0.5j | P2 | 11 fichiers (voir audit C2) |
| Nettoyer le code mort (`_isValidating`, `_manaRegex`, etc.) | Cleanup | 0.5j | P2 | `deck_detail_page.dart`, `card_search_page.dart` |
| Extraire les constantes dupliquees (couleurs, fonts) dans `lib/theme/` | Refactor | 1j | P2 | 125 Color() hardcodes dans 44 fichiers |
| Verifier que `functions/service-account.json` n'est pas commit | Secu | 0.25j | P1 | `.gitignore`, `functions/` |
| Ajouter `flutter analyze` + `flutter test` au pipeline CI | DevOps | 0.5j | P1 | `.github/workflows/build-main.yml` |

**Delivrable** : Codebase propre, compilable, avec analyse statique stricte et CI qui teste.

---

### Sprint 2 : State Management Riverpod (Semaines 3-4)

**Objectif** : Migrer vers un vrai state management et injecter les dependances proprement.

| Tache                                     | Type        | Effort | Priorite | Detail |
|-------------------------------------------|-------------|--------|----------|--------|
| Creer les Providers Riverpod pour les services core | Architecture | 2j | P1 | `lib/providers/` (8+ providers) |
| Migrer `CollectionService` vers un AsyncNotifierProvider | Migration | 1j | P1 | Eliminer les 4 acces SharedPrefs directs |
| Migrer `DeckService` vers un AsyncNotifierProvider | Migration | 1j | P1 | Eliminer les 2 acces SharedPrefs directs |
| Migrer `WishlistService`, `ProfileService`, `GameHistoryService` | Migration | 1.5j | P1 | 8 acces SharedPrefs |
| Charger `LocalCardService` au demarrage via Provider global | Optim | 0.5j | P1 | Eviter le chargement multiple |
| Refactorer les pages pour consommer les Providers (ConsumerStatefulWidget) | Migration | 2j | P1 | Touche 19 pages + widgets |
| Retirer les instanciations manuelles de services | Cleanup | 0.5j | P1 | Eliminer tous les `= DeckService()` |

**Delivrable** : State management centralise, services injectes, donnees reactives cross-pages.

---

### Sprint 3 : Tests et CI/CD (Semaines 5-6)

**Objectif** : Atteindre une couverture de tests minimale et automatiser la qualite.

| Tache                                     | Type        | Effort | Priorite |
|-------------------------------------------|-------------|--------|----------|
| Tests unitaires `CollectionService` (CRUD, upsert, import batch) | Test | 1j | P1 |
| Tests unitaires `DeckService` (CRUD, zones, commandant, moveCard) | Test | 1j | P1 |
| Tests unitaires `WishlistService` (migration legacy, CRUD) | Test | 0.5j | P1 |
| Tests unitaires `LocalCardService` (search, smart match, filtres) | Test | 0.5j | P1 |
| Tests unitaires `BackupService` (generation JSON, restauration) | Test | 0.5j | P2 |
| Tests serialisation/deserialisation modeles (DeckCard, Deck, ScryfallCard, Profile) | Test | 0.5j | P2 |
| Ajouter la couverture de tests au pipeline CI (`--coverage` + seuil) | DevOps | 0.5j | P1 |

**Delivrable** : >40% couverture services, CI avec tests obligatoires.

---

### Sprint 4 : Base de Donnees Locale (Semaines 7-9)

**Objectif** : Remplacer SharedPreferences par une base de donnees performante.

| Tache                                     | Type        | Effort | Priorite |
|-------------------------------------------|-------------|--------|----------|
| Choisir la technologie (drift recommande pour le typage fort) | Decision | 0.5j | P1 |
| Definir le schema BDD (tables: collections, decks, wishlists, profiles, game_history, scan_history) | Architecture | 1j | P1 |
| Implementer le DAL (Data Access Layer) pour Collection (index sur scryfallId) | Migration | 2j | P1 |
| Implementer le DAL pour Decks (4 zones : mainboard, sideboard, considering, wishlist) | Migration | 2j | P1 |
| Implementer le DAL pour Wishlists, Profils, Historiques | Migration | 2j | P1 |
| Script de migration transparente SharedPreferences -> BDD (one-shot au premier lancement) | Migration | 1j | P1 |
| Mettre a jour les Providers Riverpod pour utiliser les DAOs | Migration | 1j | P1 |
| Tests d'integration de la couche donnees | Test | 1j | P1 |

**Delivrable** : Stockage performant, requetes indexees, migration transparente pour l'utilisateur.

---

### Sprint 5 : Navigation, HTTP et UX (Semaines 10-11)

**Objectif** : Moderniser la navigation, unifier les appels HTTP et ameliorer l'UX.

| Tache                                     | Type        | Effort | Priorite |
|-------------------------------------------|-------------|--------|----------|
| Implementer `go_router` pour la navigation declarative | Architecture | 2j | P2 |
| Definir les routes et le deep linking (152 Navigator.push a migrer) | Architecture | 1j | P2 |
| Migrer les appels HTTP de `http` vers `Dio` (unifier le client) | Architecture | 1.5j | P2 |
| Ajouter `dio_cache_interceptor` pour cache HTTP Scryfall | Performance | 0.5j | P2 |
| Implementer le rate limiting API global (Dio interceptor, max 10 req/sec) | Robustesse | 0.5j | P2 |
| Ajouter un systeme de logging structure (package `logger`) | Qualite | 1j | P2 |
| Ameliorer la gestion du mode offline (banner, fallback gracieux) | UX | 1j | P3 |
| Retirer la dependance `dio` actuelle inutilisee ou la remplacer | Cleanup | 0.25j | P2 |

**Delivrable** : Navigation moderne, HTTP unifie avec cache/throttle, logging, mode offline.

---

### Sprint 6 : Migration HTTP Pages (Semaines 12-13) -- TERMINE

**Objectif** : Eliminer tous les appels HTTP directs des pages/widgets et migrer vers ScryfallApiService.

| Tache                                     | Type        | Effort | Priorite | Statut |
|-------------------------------------------|-------------|--------|----------|--------|
| Migrer 13 appels HTTP directs dans 9 fichiers vers ScryfallApiService | Migration | 2.5j | P0 | FAIT |
| Adapter widgets non-Consumer (versions_selector_sheet, set_detail_page) | Refactor | 0.5j | P0 | FAIT |
| Valider 0 import `package:http/` dans lib/ | QA | - | P0 | FAIT |

**Resultat** : 13/13 appels migres, 0 import http, 165 tests verts. Score : 8.5 → **9.0/10**.

---

### Sprint 7 : Refactoring God Files & Qualite (Semaines 14-17) -- TERMINE

**Objectif** : Decomposer les 6 God Files pages en extrayant des controllers Riverpod, supprimer les dependances obsoletes, migrer les Navigator.push, atteindre >60% couverture.

| Tache                                     | Type        | Effort | Priorite | Statut |
|-------------------------------------------|-------------|--------|----------|--------|
| Extraire SetDetailController | Refactor | 2j | P0 | FAIT |
| Extraire DeckDetailController | Refactor | 2j | P0 | FAIT |
| Extraire CardSearchController | Refactor | 1.5j | P0 | FAIT |
| Extraire CardDetailController | Refactor | 1.5j | P0 | FAIT |
| Extraire DeckListController + CollectionController | Refactor | 1.5j | P0 | FAIT |
| Mixin CardListUpsert (3 services) | Refactor | 1j | P1 | FAIT |
| Migrer 23 Navigator.push vers go_router | Migration | 1.5j | P1 | FAIT |
| Supprimer package `http` du pubspec.yaml | Cleanup | 0.25j | P1 | FAIT |
| Tests controllers (108 nouveaux) | Test | 2j | P2 | FAIT |

**Resultat** : 6 controllers, 273 tests, 0 Navigator.push, 0 import http, mixin upsert. Score : 8.5 -> **9.0/10**.

---

### Sprint 8 : Widgets, Qualite & Polish (Semaines 18-20) -- EN PAUSE

**Objectif** : Extraire 4 controllers widgets, resoudre 1041 infos flutter analyze, extraire sous-widgets pages, decouper routeur, centraliser GoogleFonts. Cible : 0 fichier applicatif >500 lignes, >300 tests, score 9.5/10.

| Tache                                     | Type        | Effort | Priorite | Statut |
|-------------------------------------------|-------------|--------|----------|--------|
| Supprimer 77 unnecessary_non_null_assertion | Cleanup | 0.5j | P0 | FAIT |
| Resoudre ~890 issues flutter analyze restantes | Cleanup | 1.5j | P0 | BACKLOG |
| Extraire DeckCardPickerController (774 lignes) | Refactor | 1.5j | P0 | BACKLOG |
| Extraire CollectionListController (716 lignes) | Refactor | 1j | P0 | BACKLOG |
| Extraire PlayerZoneController (674 lignes) | Refactor | 1j | P0 | BACKLOG |
| Extraire DeckStatsController (612 lignes) | Refactor | 1j | P0 | BACKLOG |
| Extraire sous-widgets pages (5 pages >500 lignes -> <400) | Refactor | 3j | P0 | BACKLOG |
| Decouper app_router.dart (713 lignes -> <200 + sous-routeurs) | Refactor | 1.5j | P1 | BACKLOG |
| Centraliser GoogleFonts.cinzel (333 -> <60) dans AppTextStyles | Refactor | 2j | P2 | BACKLOG |

**Etat actuel** : 77 non_null_assertions corriges (commit 8035d46). Reste 965 issues (75 warnings + 890 infos). Le backlog technique sera repris apres le Sprint 9.

**Delivrable cible** : 10 controllers, 0 fichier page/widget >500 lignes, >305 tests, 0 issue analyse, GoogleFonts centralise. Score cible : **9.5/10**.

---

### Sprint 9 : Quick Wins Features (Semaines 21-22) -- EN COURS

**Objectif** : Implementer les 5 features a forte valeur ajoutee identifiees par l'audit Yamato (veille concurrentielle). Premier sprint de features utilisateur apres 8 sprints techniques.

| Tache                                     | Type        | Effort | Priorite | Ref Yamato | Statut |
|-------------------------------------------|-------------|--------|----------|------------|--------|
| Ajouter RelatedCard + allParts dans ScryfallCard + maxPrice dans SearchFilters | Modele | 0.5j | P0 | -- | FAIT |
| Indicateur de collection (badge owned/foil/wishlist sur recherche + set + detail) | Feature | 1.5j | P0 | M10 | FAIT |
| Bouton "Ajouter au deck" depuis la page detail carte (reutilise DeckPickerModal) | Feature | 0.5j | P1 | E-A4 | FAIT |
| Tri par prix (EUR croissant/decroissant) dans recherche API + locale + collection | Feature | 0.5j | P1 | M9 | FAIT |
| Filtre budget (prix max EUR) dans le modal de filtres | Feature | 0.5j | P1 | E4 | FAIT |
| Affichage des tokens requis par le deck (onglet Tokens dans deck detail) | Feature | 1.5j | P2 | M13 | FAIT |

**Resultat** : 5 features deployees, 298 tests (273 -> 298), 0 errors analyze. Score : **9.0/10** (stable).

---

### Sprint 10 : Import/Export & Legalite (Semaines 23-25)

**Objectif** : Combler le gap critique n°1 (import/export) et n°3 (legalite) identifies par l'audit Yamato.

| Tache                                     | Type        | Effort | Priorite | Ref Yamato |
|-------------------------------------------|-------------|--------|----------|------------|
| Import/export multi-format (CSV, TXT, Moxfield, Archidekt, MTGO) | Feature | 4j | P0 | M2 |
| Verification de legalite par format (Standard, Modern, Commander, Pioneer, etc.) | Feature | 3j | P0 | M4 |
| Tags personnalises sur les cartes (etiquettes utilisateur libres) | Feature | 2j | P1 | M3 |

**Delivrable** : Interoperabilite avec les autres apps MTG, verification legalite automatique. Effort : ~9j.

---

### Sprint 11 : EDHREC Deep Integration (Semaines 26-28)

**Objectif** : Exploiter l'API EDHREC pour des recommandations avancees de deckbuilding Commander.

| Tache                                     | Type        | Effort | Priorite | Ref Yamato |
|-------------------------------------------|-------------|--------|----------|------------|
| Themes et tribes EDHREC (suggestions par archetype/tribu) | Feature | 3j | P1 | E2 |
| Synergy score (score de synergie entre cartes d'un deck) | Feature | 3j | P1 | E5 |
| Detection de combos (identification automatique des combos dans un deck) | Feature | 3j | P2 | E6 |

**Delivrable** : Recommandations intelligentes pour le deckbuilding Commander. Effort : ~9j.

---

### Sprint 12 : Features Avancees, Refactoring & Backlog Technique (Semaines 29-33)

**Objectif** : Implementer les features avancees Yamato Tier A/B restantes et solder le backlog technique.

| Tache                                     | Type        | Effort | Priorite | Ref Yamato |
|-------------------------------------------|-------------|--------|----------|------------|
| Deck power level (estimation automatique de la puissance d'un deck Commander) | Feature | 3j | P1 | E1 |
| Syntaxe de recherche avancee Scryfall (filtres en ligne type `c:red cmc<=3`) | Feature | 3j | P1 | A7 |
| Recherche multilangue (nom de carte en FR, DE, JP, etc.) | Feature | 2j | P2 | A4 |
| Salt score EDHREC (indicateur de cartes "frustrantes") | Feature | 2j | P2 | E3 |
| Centraliser Colors hardcodes (1536) dans AppColors/ThemeData | Refactor | 3j | P2 | -- |
| GameSetupModalController (507 lignes) | Refactor | 1j | P2 | -- |
| Internationalisation (i18n avec fichiers ARB) | Feature | 5j | P3 | -- |
| Chiffrement BDD SQLite (sqlite3_flutter_libs + encryption) | Secu | 2j | P3 | -- |
| Resoudre les dependency overrides ML Kit (google_mlkit_commons, google_mlkit_text_recognition) | Fix | 1j | P3 | -- |
| Optimiser le scanner (ML Kit derniere version) | Optim | 2j | P3 | -- |
| Mise a jour automatique base locale (oracle-cards.json via Bulk Data Scryfall) | Feature | 3j | P2 | -- |
| Ajouter les notifications push (Firebase Messaging) | Feature | 2j | P3 | -- |
| Integrer les Rulings Scryfall dans le detail de carte | Feature | 1j | P3 | -- |
| Ajouter les Catalogs Scryfall pour les filtres dynamiques | Feature | 2j | P3 | -- |

**Delivrable** : Features avancees + dette technique soldee, app complete et competitive. Effort : ~32j.

---

## 4. Architecture Cible

```
lib/
  main.dart                      # Initialisation, ProviderScope, GoRouter
  router.dart                    # Configuration go_router

  theme/
    app_theme.dart               # ThemeData complet (elimine les 125 Color() hardcodes)
    app_fonts.dart               # Centralisation GoogleFonts (elimine les 313 GoogleFonts.cinzel)

  constants/
    scryfall_api.dart            # URLs et constantes API (deja existant)
    storage_keys.dart            # Cles de stockage

  models/                        # Data classes (inchange)
    deck_model.dart
    scryfall_card_model.dart
    profile_model.dart
    game_history_model.dart
    ...

  data/
    database/
      app_database.dart          # Configuration drift/isar
      daos/                      # Data Access Objects par entite
        collection_dao.dart
        deck_dao.dart
        wishlist_dao.dart
        profile_dao.dart
        game_history_dao.dart

  services/                      # Logique metier pure
    collection_service.dart      # Utilise CollectionDao (plus de SharedPrefs directes)
    deck_service.dart            # Utilise DeckDao
    scryfall_api_service.dart    # Client Dio avec cache + rate limit
    backup_service.dart          # Export/import via DAOs
    ...

  providers/                     # Riverpod Providers
    collection_provider.dart     # AsyncNotifierProvider
    deck_provider.dart           # AsyncNotifierProvider
    profile_provider.dart        # AsyncNotifierProvider
    local_card_provider.dart     # FutureProvider (chargement au boot)
    auth_provider.dart           # Google Drive auth state

  controllers/                   # Logique UI extraite des God Files
    card_search_controller.dart  # Extrait de card_search_page.dart (838 lignes)
    life_counter_controller.dart # Extrait de life_counter_page.dart
    deck_detail_controller.dart  # Extrait de deck_detail_page.dart (856 lignes)
    set_detail_controller.dart   # Extrait de set_detail_page.dart (998 lignes)
    card_detail_controller.dart  # Extrait de card_detail_page.dart (779 lignes)

  pages/                         # UI pure (consomme Providers via ConsumerWidget)
    ...

  widgets/                       # Composants reutilisables
    ...

  utils/
    card_list_operations.dart    # Mixin pour logique upsert partagee
    logger.dart                  # Wrapper logging structure
```

---

## 5. Metriques de Succes

| Metrique                      | Sprint 1      | Sprint 7      | Cible S8        | Cible Finale |
|-------------------------------|---------------|---------------|-----------------|--------------|
| Tests                         | 0 (1 casse)   | **273**       | **>= 305**      | >400         |
| Couverture tests              | 0%            | ~55%          | **> 65%**       | >75%         |
| flutter analyze issues        | ~1000+        | 1041          | **0**           | 0            |
| Fichiers pages >500 lignes    | 6             | 5             | **0**           | 0            |
| Fichiers widgets >500 lignes  | 5             | 5             | **0**           | 0            |
| Controllers Riverpod          | 0             | 6             | **10**          | >12          |
| Providers Riverpod actifs     | 0             | 20+           | **24+**         | >25          |
| Navigator.push                | 152           | 0             | 0               | 0            |
| app_router.dart lignes        | -             | 713           | **<200**        | <200         |
| GoogleFonts directs           | 333           | 333           | **<60**         | 0            |
| Pipeline CI execute tests     | Non           | Oui           | Oui + fatal-infos | Oui + CD   |
| Stockage donnees              | SharedPrefs   | drift SQLite  | drift SQLite    | drift + chiffrement |
| Client HTTP                   | http (brut)   | Dio+cache     | Dio+cache       | Dio+cache    |
| Score qualite                 | 5.5/10        | **9.0/10**    | **9.5/10**      | 10/10        |

---

## 6. Risques et Mitigations

| Risque                                    | Probabilite | Impact | Mitigation                                |
|-------------------------------------------|-------------|--------|-------------------------------------------|
| Migration SharedPrefs -> BDD perd des donnees | Moyen    | Critique | Script de migration + backup prealable + test d'integration |
| Refactoring Riverpod casse des fonctionnalites | Moyen    | Haut    | Tests unitaires AVANT la migration (Sprint 3 avant Sprint 2 si besoin) |
| Incompatibilite ML Kit (dependency overrides) | Faible   | Moyen   | Isoler le scanner derriere une interface (strategy pattern) |
| Base oracle-cards.json devient trop volumineuse | Faible  | Moyen   | Telechargement incremental via Bulk Data Scryfall |
| Rate limit Scryfall en production         | Moyen       | Moyen   | Cache HTTP + throttling Dio (max 10 req/sec) |
| functions/service-account.json expose     | Faible      | Critique | Verifier immediatement + ajouter au .gitignore global |
| Migration go_router casse la navigation   | Moyen       | Haut    | Migrer page par page, pas en une fois |
| Regression UI lors du refactoring God Files | Eleve     | Moyen   | Widget tests AVANT le refactoring |

---

## 7. Prochaines Etapes Immediates (Sprint 9)

1. **Etape 1** : Ajouter `RelatedCard` + `allParts` dans `ScryfallCard.fromJson` (default `const []`) + `maxPrice` dans `SearchFilters` + 5 tests modeles
2. **Etape 2** : Creer `CollectionBadgeWidget` + index `Map<String,int>` dans `CardSearchState` + integrer badges dans recherche, set detail, et detail carte + 6 tests
3. **Etape 3** : Ajouter bouton "Ajouter au deck" dans `card_detail_page.dart` connecte au `DeckPickerModal` existant
4. **Etape 4** : Ajouter options tri `price_asc`/`price_desc` + filtre `maxPrice` cote client + champ prix max dans le modal de filtres + 5 tests
5. **Etape 5** : Implementer `_computeTokens()` dans `DeckDetailController` + creer `DeckTokensTab` + onglet Tokens dans `deck_detail_page.dart` + 3 tests

---

## 8. Estimation Globale

| Sprint | Duree | Effort Total | Complexite | Statut |
|--------|-------|--------------|------------|--------|
| Sprint 1 : Fondations | 2 semaines | 5.75j | Faible | TERMINE |
| Sprint 2 : Riverpod | 2 semaines | 8.5j | Elevee | TERMINE |
| Sprint 3 : Tests + CI | 2 semaines | 5j | Moyenne | TERMINE |
| Sprint 4 : Base de donnees | 3 semaines | 10.5j | Elevee | TERMINE |
| Sprint 5 : Navigation + HTTP | 2 semaines | 7.75j | Moyenne | TERMINE |
| Sprint 6 : Migration HTTP Pages | 2 semaines | 3j | Moyenne | TERMINE |
| Sprint 7 : Refactoring God Files | 3 semaines | 13.25j | Elevee | TERMINE |
| Sprint 8 : Widgets, Qualite & Polish | 3 semaines | 15j | Moyenne-Elevee | **EN PAUSE** |
| **Sprint 9 : Quick Wins Features** | **2 semaines** | **5j** | **Faible** | **EN COURS** |
| Sprint 10 : Import/Export & Legalite | 3 semaines | 9j | Moyenne | BACKLOG |
| Sprint 11 : EDHREC Deep Integration | 3 semaines | 9j | Elevee | BACKLOG |
| Sprint 12 : Features Avancees & Backlog | 5 semaines | 32j | Elevee | BACKLOG |
| **Total Sprints 1-8** | **20 semaines** | **68.75j** | -- | -- |
| **Total Sprints 1-12 (projection)** | **33 semaines** | **123.75j** | -- | -- |

*Ce plan est evolutif. Les priorites et les efforts estimes doivent etre revus a la fin de chaque sprint en fonction de l'avancement reel et des retours utilisateurs.*

---

## 9. Audit Veille Concurrentielle (Yamato)

> Synthese de l'audit Yamato -- analyse des features concurrentes (Moxfield, EDHREC, ManaBox, Dragon Shield, Bugko, MTG Companion officiel).

### Gaps critiques identifies

| # | Gap | Impact | Sprint cible |
|---|-----|--------|--------------|
| 1 | **Import/Export multi-format** : aucun import/export de decks (CSV, TXT, Moxfield, Archidekt, MTGO). Bloque l'adoption par les joueurs venant d'autres apps. | Critique | Sprint 10 |
| 2 | **Indicateur de collection** : pas d'indication visuelle si une carte est possedee ou manquante lors du deckbuilding ou de la recherche. | Critique | Sprint 9 |
| 3 | **Verification de legalite** : aucune verification automatique de la legalite d'un deck par format (Standard, Modern, Commander, Pioneer, etc.). | Critique | Sprint 10 |

### Avantages differenciants a conserver

Magic Companion dispose de features uniques absentes ou rares chez les concurrents :
- **Oracle IA** : assistant intelligent pour les regles et interactions (aucun concurrent direct)
- **Mode tournoi integre** : gestion de tournois dans l'app (rare chez les concurrents)
- **Calculateur hypergeometrique** : probabilites de tirage integrees au deckbuilder (unique)
- **Scanner OCR multi-langues** : reconnaissance de cartes en plusieurs langues

### Features prioritaires (Tiers Yamato)

| Tier | Features | Sprint |
|------|----------|--------|
| **S (Must-Have)** | Import/export (M2), Legalite (M4), Indicateur collection (M10), Tri prix (M9), Tags (M3) | 9-10 |
| **A (High Value)** | Bouton ajout deck (E-A4), Budget filter (E4), Tokens (M13), Power level (E1), Syntaxe Scryfall (A7) | 9, 12 |
| **B (Nice-to-Have)** | Themes EDHREC (E2), Synergy score (E5), Combos (E6), Multilangue (A4), Salt score (E3) | 11-12 |
| **C (Long-Term)** | Playtesting, social features, marketplace integration | Post-Sprint 12 |

### Sources de veille

| App | Forces principales analysees |
|-----|------------------------------|
| Moxfield | Import/export, deckbuilding collaboratif, UI/UX reference |
| EDHREC | Recommandations Commander, themes, synergies, combos, salt score |
| ManaBox | Scanner, collection, UX mobile-first |
| Dragon Shield | Collection tracking, prix, indicateurs visuels |
| Bugko | Tournois, social features |
| MTG Companion (WotC) | Life counter, regles officielles, integration evenements |

> Rapport complet : voir documentation Yamato (agent veille concurrentielle).
