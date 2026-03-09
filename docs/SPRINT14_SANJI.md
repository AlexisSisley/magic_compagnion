# Sprint 14 -- Architecture & Audit Complet | Sanji

**Date :** 8 mars 2026
**Architecte :** Sanji (Architecte Logiciel Senior)
**Sprint :** 14 (cible v1.10)
**Base auditee :** 147 fichiers Dart, ~34 000 lignes, 640 tests, 39 fichiers test

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Reformulation

Magic Companion est une application Flutter mobile mature (v1.9, 12 sprints d'historique) pour joueurs de Magic: The Gathering. Le Sprint 14 est un **sprint d'assemblage et d'integration** -- l'infrastructure existe a 70-80%, il faut la brancher dans l'UI.

### Perimetre fonctionnel

**Inclus (Sprint 14) :**
- US-14.1 : Prix Scryfall affiches (detail, collection list, scanner overlay) -- 3 SP
- US-14.2 : Valeur collection temps reel (total, top cartes, historique quotidien) -- 3 SP
- US-14.3 : Animations life counter (pulse +vie, shake -vie, glow monarch) -- 2 SP
- US-14.4 : Onboarding 3 ecrans avec skip et persistence -- 2 SP
- US-14.5 : Batch fix firstWhere + CI pipeline PR Check -- 2 SP

**Exclu :**
- Dashboard Home (reporte Sprint 15)
- Historique prix 30j/90j (necessite backend)
- Animations supplementaires (5 restantes reportees)
- Migration complete SharedPreferences vers drift

### Exigences non-fonctionnelles (NFR)

| NFR | Cible | Justification |
|-----|-------|---------------|
| Performance animations | 60fps stable | Life counter utilise pendant les parties, tout jank est visible |
| Temps calcul valeur | <2s pour 1000 cartes | UX acceptable pour affichage collection |
| Rate limit Scryfall | 10 req/s max, 75ms entre requetes | Respect des guidelines API, eviter le ban |
| CI pipeline | Bloquant sur PR | Detecter les regressions avant merge |
| Coverage tests | >40% (seuil CI) | Objectif progressif depuis 30% actuel |
| Lint warnings | 0 sur nouveaux fichiers | Standards de qualite Sprint 14+ |

### Contraintes extraites de l'analyse Zorro

| Contrainte | Impact | Mitigation |
|------------|--------|------------|
| 77 firstWhere sans orElse dans 29 fichiers | Crash potentiel en production (StateError) | Batch fix mecanique avec `.where().firstOrNull` |
| 107 catch(e) generiques dans 46 fichiers | Masquage d'erreurs, debugging difficile | Hors scope Sprint 14, backlog Sprint 15-16 |
| 59 Color(0x...) hardcodes dans 14 fichiers | Inconstance visuelle, maintenance difficile | Hors scope Sprint 14, backlog Sprint 15 |
| API Scryfall = source unique prix | Pas de fallback si API down | Cache local agressif TTL 24h deja en place |
| 1 developpeur, 10 jours | Capacite limitee | Phasage Must/Should strict |

---

## Phase 2 : Choix de Stack & Justification

### Tableau decisionnel

Le projet existe deja en Flutter/Dart. L'evaluation porte sur la **pertinence de continuer avec cette stack** pour le Sprint 14.

| Critere | Flutter/Dart | React Native/TS | Kotlin/Swift Natif |
|---------|-------------|-----------------|-------------------|
| Pertinence projet | 5/5 (deja en place, 147 fichiers) | 2/5 (migration totale) | 3/5 (2 codebases) |
| Performance requise | 5/5 (animations 60fps, Skia) | 3/5 (bridge JS overhead) | 5/5 (natif) |
| Ecosysteme & libs | 5/5 (Riverpod, drift, Dio, go_router) | 4/5 (React ecosystem) | 4/5 (platform specific) |
| Facilite recrutement | 3/5 (niche mais croissant) | 5/5 (large pool) | 4/5 (par plateforme) |
| Time-to-market | 5/5 (0j migration, existant) | 1/5 (mois de migration) | 2/5 (double effort) |
| **Total** | **23/25** | **15/25** | **18/25** |

**Decision finale :** Flutter/Dart -- Le projet est mature avec 12 sprints d'historique. Migrer serait absurde. Toute l'infrastructure Sprint 14 (PriceHelper, CollectionValueProvider, AnimationControllers, OnboardingPage) est deja codee en Dart.

### Couches technologiques en place

| Couche | Technologie | Version | Justification |
|--------|------------|---------|---------------|
| Langage | Dart 3.9+ | SDK ^3.9.2 | Pattern matching, sealed classes, records |
| Framework | Flutter stable | latest | Animations natives, Skia rendering |
| State management | Riverpod 3.0 | ^3.0.3 | 12 controllers, 7 providers, injection propre |
| Routing | go_router | ^17.1.0 | Shell routes, redirect conditionnel onboarding |
| Base de donnees | drift (SQLite) | ^2.22.1 | 8 tables, migration service, typed queries |
| HTTP Client | Dio | ^5.9.0 | Cache, rate limiting, intercepteurs |
| CI/CD | GitHub Actions | -- | Build, release, Firebase App Distribution |
| Observabilite | Firebase Crashlytics + Analytics | -- | Crash reporting, event tracking |

---

## Phase 3 : Architecture Systeme

### Style d'architecture

**Monolithe modulaire** avec separation en couches et injection de dependances via Riverpod.

### Diagramme de composants

```
[Flutter UI (Pages/Widgets)]
       |
       v
[Controllers (12 Riverpod Notifiers)]
       |
       v
[Services (21 services metier)]
       |
       +---> [ScryfallApiService] ---> [API Scryfall (HTTPS)]
       |           |
       |           +---> [Cache memoire TTL]
       |
       +---> [LocalCardService] ---> [assets/json/oracle-cards.json (27k cartes)]
       |
       +---> [AppDatabase (drift)] ---> [SQLite local]
       |
       +---> [Firebase] ---> [Auth, Cloud Functions (Oracle IA), Crashlytics]
```

### Flux de donnees Sprint 14

```
=== US-14.1 : Prix Scryfall ===
ScryfallCard.prices (Map<String,dynamic>)
    --> PriceHelper.parsePrice() / .format() / .bestPrice()
    --> PriceTag widget (compact | detailed)
    --> Affiche dans : CardDetailPage, CollectionListTab, ScannerPage

=== US-14.2 : Valeur Collection ===
CollectionProvider (List<DeckCard>)
    --> CollectionValueNotifier._computeValue()
        --> Phase 1 : LocalCardService (cache local)
        --> Phase 2 : ScryfallApiService.fetchCollection() (batch 75 cartes)
    --> CollectionValueState (totalEur, topCards, lastUpdated)
    --> CollectionService.recordDailyValue() --> drift CollectionValueHistory

=== US-14.3 : Animations Life Counter ===
PlayerZone._triggerChange(+N)
    --> _pulseController.forward() (AnimatedBuilder, scale 1.0->1.15->1.0, 200ms)
PlayerZone._triggerChange(-N)
    --> _shakeController.forward() (AnimatedBuilder, translateX oscillation, 300ms)
Player.isMonarch = true
    --> _glowController.repeat() (AnimatedBuilder, border+shadow opacity pulse, 1.5s)

=== US-14.4 : Onboarding ===
main.dart --> GoRouter.redirect --> _onboardingRedirect()
    --> SharedPreferences.getBool('has_seen_onboarding')
    --> Si false : redirect /onboarding
    --> OnboardingPage (3 PageView, skip, complete)
    --> SharedPreferences.setBool(true) --> redirect /life-counter
```

### Patterns de communication

- **UI -> Controller** : Appels directs via `ref.read(controllerProvider.notifier)`
- **Controller -> Service** : Injection via constructeur ou `ref.read(serviceProvider)`
- **Service -> API** : Dio HTTP (async, cache, rate limiting)
- **State management** : Riverpod `Notifier<T>` avec `state = newState` (unidirectionnel)
- **Reactif** : `ref.watch()` dans les widgets pour rebuild automatique

---

## Phase 4 : Modele de Donnees & API Design

### Entites cles Sprint 14

| Entite | Stockage | Attributs cles |
|--------|----------|----------------|
| ScryfallCard | In-memory (JSON 27k) + API | id, prices (Map), imageUrl, name, setCode |
| DeckCard (collection) | drift CollectionCards | scryfallId, quantity, isFoil, tags |
| CollectionValueState | In-memory (Riverpod) | totalValueEur, pricedCards, lastUpdated |
| CollectionValueHistory | drift | date, totalValue (snapshot quotidien) |
| Player | In-memory | life, poison, energy, isMonarch, colorValue |
| OnboardingFlag | SharedPreferences | has_seen_onboarding (bool) |

### API Scryfall utilisee

| Endpoint | Methode | Usage Sprint 14 |
|----------|---------|-----------------|
| `/cards/search?q=...` | GET | Recherche par nom (scanner, search) |
| `/cards/collection` | POST | Batch prix pour collection (max 75 identifiers) |
| `/sets` | GET | Liste des sets (collection sets tab) |

Rate limiting respecte via `ScryfallApiService._requestTimestamps` (max 10/s).

---

## Phase 5 : Securite, Scalabilite & Risques

### Securite

| Point | Statut | Action |
|-------|--------|--------|
| API keys Firebase | OK | Generees dans firebase_options.dart |
| upload-keystore.jks a la racine | ATTENTION | Verifier .gitignore |
| SharedPreferences | OK | Pas de donnees sensibles (flags uniquement) |
| dependency_overrides ML Kit | RISQUE FAIBLE | Bloque patches securite, Sprint 16 |
| HTTPS partout | OK | Dio + Scryfall HTTPS only |

### Scalabilite

| Dimension | Cible | Strategie |
|-----------|-------|-----------|
| Collection <5000 cartes | OK | Batch 75 cartes, cache local prioritaire |
| Collection >5000 cartes | A surveiller | Indicateur de progression manquant (dette N2) |
| Cache Scryfall | TTL 10min GET, 24h batch | Evite les appels repetitifs |
| SQLite local | Illimite pratiquement | drift gere les migrations automatiquement |

### Risques techniques Sprint 14

| Risque | Impact | Probabilite | Mitigation |
|--------|--------|-------------|------------|
| R1 : Surcharge 12 SP / 10j / 1 dev | Eleve | Moyenne | Phasage Must/Should strict, Dashboard reporte |
| R2 : Regression sur integration PriceTag dans 26+ fichiers | Moyen | Moyenne | 640 tests existants, review visuel |
| R3 : Performance calcul valeur >3000 cartes | Moyen | Moyenne | Batch 75 deja en place, ajouter progress indicator |
| R4 : 77 firstWhere corrections introduisent regressions | Moyen | Basse | Approche mecanique, tests unitaires existants |
| R5 : Animations jank sur vieux devices | Moyen | Basse | Controllers natifs Flutter (pas Lottie/Rive), 200-300ms |
| R6 : Onboarding SharedPreferences = reset si clear data | Basse | Basse | Acceptable v1.10, migration drift Sprint 15 |
| R7 : API Scryfall down pendant calcul valeur | Eleve | Basse | Cache local prioritaire, fallback gracieux |

### Strategie de tests

| Niveau | Fichiers | Tests actuels | Cible Sprint 14 |
|--------|----------|--------------|-----------------|
| Unitaires (services, models) | 17 fichiers | ~280 tests | +20 tests PriceHelper |
| Controllers (Riverpod) | 11 fichiers | ~280 tests | +10 tests CollectionValue |
| Widgets | 2 fichiers | ~30 tests | +5 tests PriceTag (minimum) |
| Integration (pages) | 1 fichier (onboarding) | ~20 tests | Maintenir |
| Router | 1 fichier | ~20 tests | Maintenir |
| **Total** | **39 fichiers** | **~640** | **~675+** |

---

## AUDIT COMPLET DU CODE EXISTANT

---

### A1. Metriques Globales Verifiees

| Metrique | Valeur verifiee | Methode de verification |
|----------|----------------|------------------------|
| Fichiers Dart (lib/) | 147 | `find lib -name "*.dart"` |
| Fichiers test | 39 | `find test -name "*.dart"` |
| firstWhere sans orElse | **80 occurrences** dans ~30 fichiers | `grep -c "\.firstWhere("` + verification manuelle orElse |
| catch(e) generique | **107 occurrences** dans 46 fichiers | `grep -c "catch (e)"` |
| Color(0x...) hardcode | **59 occurrences** dans 14 fichiers (dont 19 dans app_colors.dart = normal) | `grep -c "Color(0x"` |
| PriceHelper/PriceTag utilise dans | 26 fichiers | `grep "price_helper\|PriceHelper\|PriceTag"` |
| print() dans lib/ | 0 | Verifie |
| Navigator.push | 0 | go_router exclusif |
| TODO/FIXME/HACK | 1 | Acceptable |

### A2. Architecture -- Analyse Detaillee

#### Forces architecturales

1. **Separation des couches exemplaire** : `models/` (10+), `services/` (21), `providers/` (7), `controllers/` (12), `pages/` (23), `widgets/` (40+), `router/` (9), `theme/` (2), `utils/` (3).

2. **Riverpod mature** : 12 controllers avec des Notifier typees, pas de God Widget. Les controllers extraient la logique metier des pages. `service_providers.dart` centralise l'injection.

3. **Router decoupe** : `app_router.dart` = 87 lignes. 7 sous-routeurs domaine. Route onboarding avec redirect conditionnel et cache memoire.

4. **PriceHelper centralise (Sprint 14)** : 210 lignes, 4 methodes de parsing, 3 methodes de formatage, 1 methode de comparaison. Widget `PriceTag` avec variantes compact/detailed. **Deja utilise dans 26 fichiers.**

5. **CollectionValueProvider operationnel** : 197 lignes, batch Scryfall de 75 cartes, cache local prioritaire, enregistrement quotidien via `recordDailyValue`.

6. **Animations life counter implementees** : 3 AnimationControllers dans `player_zone.dart` (pulse 200ms, shake 300ms, glow 1.5s loop). Gestion propre du cycle de vie (initState, dispose, didUpdateWidget).

7. **Base drift complete** : 8 tables (CollectionCards, Decks, DeckCards, Wishlists, WishlistCards, Profiles, GameHistory, ScanHistory, CollectionValueHistory). Migration service depuis SharedPreferences.

#### Faiblesses architecturales

1. **God Files persistants** (10 fichiers >500 lignes) :
   - `set_detail_page.dart` : 1015 lignes
   - `player_zone.dart` : 784 lignes (mais contient le modal artwork = separable)
   - `deck_card_picker.dart` : 777 lignes
   - `deck_suggestions_tab.dart` : 736 lignes
   - `collection_list_tab.dart` : 670 lignes
   - `deck_stats_tab.dart` : 615 lignes
   - `deck_detail_page.dart` : 605 lignes
   - `card_search_page.dart` : 565 lignes
   - `card_detail_page.dart` : 542 lignes
   - `game_setup_modal.dart` : 511 lignes

2. **SharedPreferences residuelles** : 17 fichiers importent encore SharedPreferences malgre drift. Usages : onboarding flag, backup preferences, migration service, life counter settings, glossary last read, tournament state.

3. **Couplage horizontal dans les widgets** : Les widgets deck/collection passent `fullCardData` (List<ScryfallCard>) en parametre au lieu d'utiliser un provider. Cela cause des `firstWhere` a repetition pour resoudre scryfallId -> ScryfallCard.

### A3. Analyse des Anti-patterns

#### AP1 : firstWhere sans orElse -- CRITIQUE

**80 occurrences verifiees** dans ~30 fichiers. Patterns les plus frequents :

```dart
// Pattern 1 : Resolution DeckCard -> ScryfallCard (50+ occurrences)
final scryfallCard = fullCardData.firstWhere((sc) => sc.id == deckCard.scryfallId);
// Crash si la carte a ete supprimee du dataset local ou si scryfallId est corrompu

// Pattern 2 : Resolution Deck par ID (10+ occurrences)
final d = (await _deckService.loadDecks()).firstWhere((d) => d.id == deckId);
// Crash si le deck a ete supprime pendant l'operation async

// Pattern 3 : Resolution collection card (5+ occurrences)
final card = widget.fullCardData.firstWhere((c) => c.id == id);
// Crash si la collection est desynchronisee
```

**Fichiers les plus affectes :**
- `deck_detail_controller.dart` : 11 occurrences
- `deck_stats_tab.dart` : 7 occurrences
- `collection_list_tab.dart` : 7 occurrences
- `deck_stats_controller.dart` : 6 occurrences
- `wishlist_detail_page.dart` : 5 occurrences
- `set_detail_controller.dart` : 4 occurrences

**Recommandation** : Remplacer par `.where((c) => c.id == id).firstOrNull` (Dart 3.0 collection extensions) puis gerer le cas null. Pour les cas ou l'absence est anormale, utiliser `firstWhere(test, orElse: () => throw SpecificException('msg'))`.

#### AP2 : catch(e) generique -- HAUTE

**107 occurrences** dans 46 fichiers. Le pattern le plus courant :

```dart
try {
  // operation
} catch (e) {
  debugPrint('Error: $e');
  // ou: state = state.copyWith(error: '$e');
}
```

**Impact** : Les DioException, StateError, FormatException, et autres sont tous traites de la meme facon. Impossible de distinguer une erreur reseau d'une erreur de parsing. Le debugging en production est compromis.

**Top fichiers** : `deck_detail_controller.dart` (8), `deck_stats_tab.dart` (6), `card_detail_controller.dart` (6), `set_detail_controller.dart` (5).

#### AP3 : Color(0x...) hardcode -- MOYENNE

**59 occurrences** dans 14 fichiers. 19 sont dans `app_colors.dart` (= definitions, normal). Les **40 restantes** sont dans des widgets/pages qui n'utilisent pas encore `AppColors`.

**Top fichiers** : `set_detail_page.dart` (7), `deck_stats_tab.dart` (7), `chat_screen.dart` (6), `collection_list_controller.dart` (5).

### A4. Performance

#### Points forts
- **Cache Scryfall Dio** : TTL 10min pour GET, evite les appels repetitifs.
- **Isolate compute()** : Parsing des 27k cartes oracle en isolate.
- **Router late final** : Fix Sprint 14, GoRouter instancie une seule fois.
- **TapGestureRecognizer dispose** : Fix Sprint 14, pool de recognizers avec dispose correct.
- **Animations natives** : AnimationController Flutter (pas Lottie/Rive = empreinte CPU minimale).

#### Points d'attention
- **27k cartes en memoire** : `LocalCardService` charge oracle-cards.json au boot. ~50-80 Mo RAM. Sur devices entree de gamme (<2 Go RAM), risque de pression memoire.
- **fullCardData passe en parametre** : Les widgets recoivent une `List<ScryfallCard>` complete au lieu de resoudre via provider. Chaque `firstWhere` est O(n) sur une liste potentiellement grande.
- **CollectionValueProvider sans progress** : Le calcul batch pour >3000 cartes peut prendre plusieurs secondes sans retour visuel.

### A5. CI/CD

#### Pipeline existant (`build-main.yml`)

| Etape | Status | Commentaire |
|-------|--------|-------------|
| Checkout + Flutter setup | OK | Cache Flutter active |
| Python backend lint (Flake8) | OK | Backend RAG verifie |
| `flutter analyze` | PROBLEME | `--no-fatal-infos --no-fatal-warnings` masque des problemes |
| `flutter test --coverage` | OK | Coverage calculee |
| Seuil coverage 30% | INSUFFISANT | Warning seulement, ne bloque pas |
| Build APK release | OK | Semantic versioning automatique |
| GitHub Release + Firebase App Distrib | OK | Pipeline complet |

#### Manques critiques

| Manque | Impact | Effort fix |
|--------|--------|-----------|
| **Pas de PR Check workflow** | Regressions detectees apres merge dans main | 0.5j -- creer `pr-check.yml` |
| **Warnings non fataux** | Problemes d'analyse masques en CI | 5min -- retirer `--no-fatal-warnings` |
| **Seuil coverage = warning** | Regression coverage non bloquante | 5min -- exit 1 si <40% |

### A6. Tests

#### Repartition actuelle

| Domaine | Fichiers test | Tests estimes | Couverture |
|---------|--------------|--------------|------------|
| Controllers | 11/12 | ~300 | ~65% |
| Services | 13/21 | ~210 | ~50% |
| Models | 5/10+ | ~80 | ~50% |
| Utils | 3/3 | ~30 | ~70% |
| Router | 1/1 | ~20 | ~80% |
| Pages | 1/23 (onboarding) | ~10 | ~2% |
| Widgets | 2/40+ | ~20 | ~3% |
| Data | 1/3 | ~10 | ~30% |
| **Total** | **39/110+** | **~680** | **~35-40%** |

#### Tests Sprint 14 existants

- `test/utils/price_helper_test.dart` : Tests PriceHelper (parsing, format, compare)
- `test/providers/collection_value_provider_test.dart` : Tests CollectionValueNotifier
- `test/pages/onboarding_page_test.dart` : Tests OnboardingPage
- `test/controllers/player_zone_controller_test.dart` : Tests PlayerZone controller

### A7. Scoring Qualite

| Dimension | Score | Poids | Justification |
|-----------|-------|-------|---------------|
| Architecture | 9.0/10 | 25% | Separation excellente, 12 controllers, Riverpod mature. -1 pour God Files widgets. |
| Tests | 7.0/10 | 20% | 640+ tests, bonne couverture controllers/services. -3 pour 0% couverture UI/pages. |
| Code proprete | 7.0/10 | 15% | 0 print, 0 Navigator.push. -3 pour 80 firstWhere non securises, 107 catch generiques. |
| Performance | 8.5/10 | 15% | Cache, isolate, router fixe, animations natives. -1.5 pour fullCardData O(n) lookups. |
| CI/CD | 6.5/10 | 10% | Pipeline complet sur main. -3.5 pour absence PR check, warnings non fataux, seuil permissif. |
| Securite | 8.0/10 | 5% | Firebase config ok, HTTPS. -2 pour keystore racine et dependency_overrides. |
| Documentation | 9.0/10 | 5% | 57+ fichiers docs, roadmaps multi-sprints, audits multi-agents. |
| DX | 8.0/10 | 5% | Riverpod + go_router + drift + Dio. -2 pour SharedPrefs residuelles et lint permissif. |
| **Score global** | **8.1/10** | **100%** | **Progression 5.5 (Sprint 0) -> 8.1 (Sprint 14). Cible 9.5 post-Sprint 15.** |

---

## Diagnostic d'infrastructure Sprint 14

### Ce qui est DEJA en place

| Composant | Fichier | Lignes | Status |
|-----------|---------|--------|--------|
| PriceHelper (parsing, format, compare) | `lib/utils/price_helper.dart` | 119 | OK, utilise dans 26 fichiers |
| PriceTag widget (compact + detailed) | `lib/utils/price_helper.dart` | 88 | OK, PriceTag + _DetailedPriceTag |
| CollectionValueNotifier | `lib/providers/collection_value_provider.dart` | 197 | OK, batch Scryfall + cache local |
| Animations pulse/shake/glow | `lib/widgets/life_counter/player_zone.dart` | Integre | OK, 3 AnimationControllers + AnimatedBuilder |
| OnboardingPage (3 ecrans) | `lib/pages/onboarding/onboarding_page.dart` | 233 | OK, PageView + skip + SharedPrefs |
| Onboarding redirect router | `lib/router/app_router.dart` | 87 | OK, cache memoire + redirect conditionnel |
| Router late final | `lib/main.dart:85` | 1 | OK, fix deja applique |
| TapGestureRecognizer pool | `lib/pages/cards/card_detail_page.dart` | Integre | OK, dispose correct |

### Ce qui RESTE a faire

| Tache | Effort | Dependances |
|-------|--------|-------------|
| Integrer PriceTag dans collection list (set_detail_card_tile, collection_list_tab) | 0.5j | PriceHelper (OK) |
| Integrer PriceTag dans scanner overlay/result | 0.5j | PriceHelper (OK) |
| Afficher CollectionValueState dans collection_page.dart (header valeur totale) | 0.5j | CollectionValueProvider (OK) |
| Top cartes par valeur (UI widget) | 0.5j | CollectionValueProvider (OK) |
| Valider animations 60fps sur device physique | 0.5j | Animations (OK) |
| Batch fix 80 firstWhere -> firstOrNull | 1j | Aucune |
| Creer `pr-check.yml` GitHub Actions | 0.5j | Aucune |
| Tests supplementaires PriceTag, CollectionValue | 0.5j | Implementations (OK) |

**Total restant : ~4.5j de travail effectif** (sur 10j prevus). Le sprint est bien avance.

---

## Chemin critique d'implementation

```
=== JOUR 1-3 : Prix Scryfall dans l'UI (US-14.1) ===
  PriceTag dans card_detail_page.dart           [FAIT]
  PriceTag dans collection_list_tab.dart         [A FAIRE]
  PriceTag dans set_detail_card_tile.dart        [A FAIRE]
  PriceTag dans scanner_page.dart overlay        [A FAIRE]

=== JOUR 4-5 : Valeur Collection UI (US-14.2) ===
  Header valeur dans collection_page.dart        [A FAIRE]
  Top cartes widget                              [A FAIRE]
  recordDailyValue integration                   [FAIT]

=== JOUR 5-6 : Animations validation (US-14.3) ===
  Pulse, shake, glow                             [FAIT - code en place]
  Test 60fps device physique                     [A FAIRE]

=== JOUR 7-8 : Onboarding (US-14.4) ===
  3 ecrans, skip, persistence                    [FAIT]
  Routing conditionnel                           [FAIT]
  Test end-to-end                                [A FAIRE]

=== JOUR 9-10 : firstWhere + CI (US-14.5) ===
  Batch fix 80 firstWhere                        [A FAIRE]
  Creer pr-check.yml                             [A FAIRE]
  Tests finaux                                   [A FAIRE]
```

---

## Dette technique residuelle (backlog Sprint 15-16)

| # | Dette | Effort | Priorite |
|---|-------|--------|----------|
| D1 | 10 God Files >500 lignes a decomposer | 8j | P1 |
| D2 | 107 catch(e) generiques a typer | 2j | P2 |
| D3 | 40 Color(0x) restants a migrer vers AppColors | 1j | P2 |
| D4 | 40 GoogleFonts.* directs a migrer vers AppTextStyles | 1j | P2 |
| D5 | 17 SharedPreferences a migrer vers drift | 2j | P2 |
| D6 | 2 dependency_overrides ML Kit | 0.5j | P3 |
| D7 | 0% couverture tests widgets/pages | 5j | P2 |
| D8 | fullCardData passe en parametre (couplage) | 3j | P2 |
| **Total** | | **22.5j** | Sprint 15-16 |

---

*Audit realise par Sanji -- Architecte Logiciel Senior*
*Sprint 14 -- Magic Companion v1.10 -- 8 mars 2026*
*Base : 147 fichiers Dart, ~34 000 lignes, 640+ tests, 39 fichiers test*
*Infrastructure Sprint 14 : ~70% deja en place, ~4.5j restants*
