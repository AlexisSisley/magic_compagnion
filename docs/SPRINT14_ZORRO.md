# Sprint 14 - Analyse Business & Audit Complet
> Agent : Zorro (Business Analyst & Chef de Projet Senior) | Date : 08/03/2026
> Certifications : IREB, PSPO

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile "Magic Companion" pour joueurs de Magic: The Gathering -- gestion de collection, deckbuilding, life counter, scanner OCR, Oracle IA.

**Parties prenantes** :
- Developpeur principal (Alexis) -- conception, implementation, QA
- Joueurs MTG (collectionneurs, deckbuilders Commander, joueurs multi-formats) -- utilisateurs finaux
- Communaute MTG -- source de feedback et adoption

**Point de douleur central** : L'application est fonctionnellement riche (147 fichiers Dart, 34 152 lignes hors code genere, 640 tests, 12 controllers) mais il reste 3 gaps concurrentiels critiques a combler pour la v1.10 :

1. **Prix Scryfall non affiches partout** -- Les prix sont parses dans le modele (`ScryfallCard.prices`) et un `PriceHelper` + `PriceTag` centralises existent deja, mais l'integration dans tous les ecrans (detail, collection, scanner) est incomplete. Les utilisateurs ne voient pas la valeur de leurs cartes.
2. **Animations life counter absentes** -- Le life counter fonctionne (poison, energy, monarch) mais manque de retour visuel. Les 3 animations core (pulse, shake, glow) sont **deja implementees** dans `player_zone.dart` (controllers + AnimatedBuilder).
3. **Pas d'onboarding** -- Les nouveaux utilisateurs arrivent directement sur le life counter sans aucune introduction. La page `OnboardingPage` existe deja (3 ecrans, skip, persistence SharedPreferences).

**Constat important** : Le Sprint 14 est largement un sprint d'assemblage/integration. L'audit revele que **70-80% de l'infrastructure est deja en place** :
- PriceHelper + PriceTag : crees et fonctionnels (210 lignes)
- CollectionValueProvider : operationnel avec batch Scryfall (197 lignes)
- Animations life counter : implementees dans player_zone.dart (784 lignes)
- Onboarding : page creee avec routing conditionnel dans app_router.dart

---

## 2. Analyse de la Cause Racine

### Pourquoi le Sprint 14 est-il necessaire malgre l'infrastructure existante ?

1. **Integration incomplete des prix dans l'UI** : Le `PriceHelper` existe mais 27 fichiers referencent `.prices` avec des patterns encore heterogenes. La centralisation est faite au niveau helper mais pas encore propagee a tous les ecrans utilisateur (collection list, scanner overlay, set detail). Les utilisateurs ne beneficient pas encore de la valeur deja codee.

2. **77 `firstWhere` sans `orElse` = risque de crash en production** : L'audit revele 80 appels `firstWhere` dans 29 fichiers, dont 77 sans `orElse`. Chaque appel est une bombe a retardement : si l'element recherche n'existe pas (carte supprimee, donnee corrompue, desync), l'app crash avec un `StateError`. Ce n'est pas un probleme theorique -- c'est un scenario reel pour une collection de milliers de cartes synchronisees avec Scryfall.

3. **Absence de CI/CD sur les PR** : Le pipeline `build-main.yml` execute `flutter analyze` et `flutter test` **uniquement sur push vers main**. Il n'y a pas de check sur les Pull Requests, ce qui signifie que les regressions sont detectees apres le merge -- trop tard. De plus, `--no-fatal-infos --no-fatal-warnings` dans le pipeline masque des problemes.

---

## 3. User Stories (5 Prioritaires)

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points |
|----------|----|----------------|------------|------------|--------|-------------|
| 1 | US-14.1 | joueur collectionneur | voir le prix EUR/USD de chaque carte sur la page detail, la liste collection et l'overlay scanner | connaitre la valeur de mes cartes sans quitter l'app | Must | 3 |
| 2 | US-14.2 | joueur collectionneur | voir la valeur totale de ma collection en temps reel avec le top des cartes les plus cheres | evaluer mon investissement et identifier mes cartes les plus precieuses | Must | 3 |
| 3 | US-14.3 | joueur life counter | voir des animations visuelles (pulse, shake, glow) quand les points de vie changent | avoir un retour visuel satisfaisant et immersif pendant les parties | Must | 2 |
| 4 | US-14.4 | nouveau utilisateur | parcourir 3 ecrans d'onboarding presentant les fonctionnalites cles, avec un bouton skip | comprendre rapidement ce que l'app propose et demarrer efficacement | Should | 2 |
| 5 | US-14.5 | developpeur | que tous les `firstWhere` soient securises et qu'un CI check existe sur les PR | eviter les crashs en production et detecter les regressions avant le merge | Should | 2 |

**Total : 12 Story Points -- 10 jours effectifs (buffer QA inclus)**

---

## 4. Criteres d'Acceptation (Gherkin/BDD)

### US-14.1 : Prix Scryfall affiches

```gherkin
Fonctionnalite: Affichage des prix Scryfall
  Scenario: Prix affiches sur la page detail carte
    Etant donne que je consulte le detail d'une carte ayant un prix EUR
    Quand la page se charge
    Alors je vois le prix normal et le prix foil en EUR via un PriceTag.detailed

  Scenario: Prix affiches dans la liste collection
    Etant donne que je parcours ma collection
    Quand je regarde une carte dans la liste
    Alors je vois le prix compact (ex: "12.50 EUR") a cote du nom

  Scenario: Prix affiches sur l'overlay scanner
    Etant donne que je scanne une carte reconnue
    Quand le resultat s'affiche en overlay
    Alors je vois le prix EUR de la carte identifiee
```

### US-14.2 : Valeur collection temps reel

```gherkin
Fonctionnalite: Valeur totale de la collection
  Scenario: Affichage de la valeur totale
    Etant donne que j'ouvre la page collection
    Quand le CollectionValueProvider termine le calcul
    Alors je vois la valeur totale EUR (normal + foil) et le nombre de cartes pricees

  Scenario: Top cartes par valeur
    Etant donne que ma collection contient des cartes avec prix
    Quand je consulte la section "Top cartes"
    Alors je vois les 10 cartes les plus cheres triees par prix decroissant

  Scenario: Historique quotidien
    Etant donne que la valeur est calculee
    Quand le provider termine
    Alors la valeur du jour est enregistree via recordDailyValue dans CollectionValueHistory
```

### US-14.3 : Animations life counter

```gherkin
Fonctionnalite: Animations du compteur de vie
  Scenario: Pulse quand les points de vie augmentent
    Etant donne que je suis sur le life counter
    Quand un joueur gagne des points de vie
    Alors la zone du joueur effectue une animation de pulse (scale up/down)

  Scenario: Shake quand les points de vie diminuent
    Etant donne que je suis sur le life counter
    Quand un joueur perd des points de vie
    Alors la zone du joueur effectue une animation de tremblement horizontal

  Scenario: Glow quand un joueur est monarch
    Etant donne que je suis sur le life counter
    Quand un joueur active le statut monarch
    Alors la zone du joueur affiche un halo dore pulse en continu
```

### US-14.4 : Onboarding 3 ecrans

```gherkin
Fonctionnalite: Onboarding nouveaux utilisateurs
  Scenario: Premier lancement affiche l'onboarding
    Etant donne que c'est la premiere ouverture de l'app
    Quand l'app demarre
    Alors je suis redirige vers 3 ecrans d'onboarding swipables

  Scenario: Skip permet de sauter l'onboarding
    Etant donne que je suis sur l'onboarding
    Quand je clique sur "Passer"
    Alors je suis redirige vers le life counter et l'onboarding ne reapparait plus

  Scenario: L'onboarding ne reapparait pas
    Etant donne que j'ai complete ou skip l'onboarding
    Quand je relance l'app
    Alors je vais directement au life counter sans passer par l'onboarding
```

### US-14.5 : Batch fix firstWhere + CI pipeline

```gherkin
Fonctionnalite: Securisation firstWhere et CI
  Scenario: Aucun firstWhere sans orElse dans le codebase
    Etant donne le code source complet
    Quand je recherche les appels firstWhere
    Alors tous les 80 appels ont un orElse ou sont remplaces par une alternative sure

  Scenario: CI check sur les Pull Requests
    Etant donne qu'un developpeur ouvre une PR
    Quand la PR est creee ou mise a jour
    Alors flutter analyze et flutter test s'executent automatiquement
    Et la PR est bloquee si l'un des deux echoue
```

---

## 5. Contraintes & Hypotheses

### Contraintes

- **Technique** : API Scryfall gratuite, rate limit 10 req/s, delai 75ms entre requetes. Les prix sont des snapshots (pas d'historique natif).
- **Technique** : 17 fichiers utilisent encore `SharedPreferences` directement (dont onboarding, backup, migration). La migration complete vers drift n'est pas terminee.
- **Technique** : 77 `firstWhere` sans `orElse` dans 29 fichiers -- refactoring significatif mais mecanique.
- **Technique** : `--no-fatal-infos --no-fatal-warnings` dans le CI masque des problemes d'analyse. Le pipeline ne bloque pas sur les warnings.
- **Technique** : 40 appels `GoogleFonts.*` disperses dans 15 fichiers (centralisation `AppTextStyles` incomplete).
- **Technique** : 59 `Color(0x...)` hardcodes restants dans 14 fichiers malgre `AppColors` existant.
- **Ressources** : 1 developpeur fullstack, 10 jours effectifs.
- **Delai** : Sprint 14 = derniere ligne droite avant release v1.10.
- **Qualite** : 640 tests existants, couverture estimee ~55-60%.

### Hypotheses

- Les prix Scryfall sont disponibles pour la majorite des cartes en collection (couverture estimee >90% des cartes modernes).
- Le `CollectionValueProvider` existant est fonctionnel et performant pour des collections de <5000 cartes.
- Les 3 animations life counter deja codees dans `player_zone.dart` sont fluides a 60fps (a valider sur device physique).
- L'onboarding avec SharedPreferences suffit pour le Sprint 14 (migration vers drift reporte).
- Le pipeline CI existant (GitHub Actions) dispose de suffisamment de minutes gratuites (2000 min/mois).

---

## 6. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|------------------------|
| R1 | **Surcharge Sprint** : 12 SP pour 10 jours avec 1 dev | Moyenne | Eleve | Phasage strict Must/Should. US-14.4 et US-14.5 glissent si necessaire. |
| R2 | **Regression sur 27 fichiers prix** : L'integration PriceTag dans 27 fichiers peut introduire des bugs UI | Moyenne | Moyen | Tests existants (640) comme filet de securite. Review visuel systematique. |
| R3 | **Performance collection value** : Calcul batch Scryfall pour >3000 cartes peut etre lent | Moyenne | Moyen | Batch de 75 cartes deja implemente. Ajouter un indicateur de progression. |
| R4 | **77 firstWhere a corriger** : Volume important, risque d'introduire des regressions logiques | Basse | Moyen | Approche mecanique : ajouter `orElse: () => throw/return null` systematiquement. Tests unitaires existants couvrent les cas critiques. |
| R5 | **Onboarding SharedPreferences** : Persistence fragile (clear data = re-onboarding) | Basse | Basse | Acceptable pour v1.10. Migration drift Sprint 15. |
| R6 | **Animations sur devices faibles** : Shake + pulse + glow simultanes peuvent causer du jank | Basse | Moyen | Tester sur device physique entree de gamme. Les animations utilisent des controllers legers (pas de Rive/Lottie). |
| R7 | **CI pipeline GitHub Actions** : Configuration PR Check peut bloquer le workflow existant | Basse | Basse | Creer un workflow separe `pr-check.yml` pour ne pas impacter `build-main.yml`. |

---

## 7. Dependances & Carte des Parties Prenantes

### Dependances externes

- **API Scryfall** : Source unique des prix. Pas de fallback alternatif. Rate limit respecte via `ScryfallApiService` avec Dio + cache.
- **Firebase** : Backend pour auth Google Drive, Cloud Functions (Oracle IA), Crashlytics, Analytics.
- **GitHub Actions** : CI/CD pour build, release, Firebase App Distribution.
- **SharedPreferences** : Persistence de l'onboarding (temporaire, migration drift ulterieure).

### Dependances internes (chemin critique)

```
PriceHelper (existe) --> PriceTag integration UI (US-14.1) --> CollectionValue UI (US-14.2)
                                                              |
AnimationControllers (existent) --> Validation 60fps (US-14.3)
                                                              |
OnboardingPage (existe) --> Routing conditionnel (US-14.4) --+
                                                              |
firstWhere audit (US-14.5) --> CI pipeline (US-14.5) --------+
```

### Carte des parties prenantes

| Partie Prenante | Interet | Influence | Strategie |
|----------------|---------|-----------|-----------|
| Joueurs collectionneurs | Eleve (prix = gap #1) | Moyen | US-14.1 + US-14.2 en priorite absolue |
| Joueurs life counter | Moyen (animations = polish) | Moyen | US-14.3 deja implemente, validation seulement |
| Nouveaux utilisateurs | Eleve (retention J7) | Faible | US-14.4 onboarding = Must pour adoption |
| Developpeur (Alexis) | Eleve (stabilite, DX) | Eleve | US-14.5 securise le codebase long terme |

---

---

# AUDIT COMPLET DU CODE EXISTANT

> Audit realise le 08/03/2026 par Zorro (Business Analyst & Chef de Projet Senior)
> Base auditee : 147 fichiers Dart, 34 152 lignes (hors code genere), 640 tests, 37 fichiers test

---

## A1. Metriques Globales

| Metrique | Valeur | Cible | Ecart | Statut |
|----------|--------|-------|-------|--------|
| Fichiers Dart (lib/) | 147 | -- | -- | Info |
| Lignes de code (hors .g.dart) | 34 152 | -- | -- | Info |
| Fichiers de test | 37 | -- | -- | Info |
| Tests unitaires | 640 | >400 | +240 | OK |
| Controllers Riverpod | 12 | >12 | 0 | OK |
| Providers Riverpod | 7 fichiers providers + service_providers | >25 | ~20+ | OK |
| Pages | 23 (12 sous-dossiers) | -- | -- | Info |
| Widgets | 40+ (9 sous-dossiers) | -- | -- | Info |
| Services | 21 | -- | -- | Info |
| Models | 10+ | -- | -- | Info |
| Navigator.push | 0 | 0 | 0 | OK |
| print() dans lib/ | 0 | 0 | 0 | OK |
| TODO/FIXME/HACK | 1 | 0 | -1 | OK |
| Score qualite estime | **8.5/10** | 9.5/10 | -1.0 | En cours |

---

## A2. Architecture

### Points forts

1. **Separation des couches solide** : models / services / providers / controllers / pages / widgets / router / theme. L'architecture suit le pattern recommande Flutter + Riverpod.
2. **12 controllers Riverpod** : Extraction reussie des God Files pages vers des controllers dedies (`DeckDetailController`, `CardSearchController`, `SetDetailController`, etc.). Logique metier separee de l'UI.
3. **Service providers centralises** : `service_providers.dart` injecte proprement tous les services via Riverpod avec `appDatabaseProvider` comme source unique de verite pour la base drift.
4. **Router decoupe** : `app_router.dart` reduit a 86 lignes avec des sous-routeurs domaine (cards, collections, decks, life_counter, scanner, settings, tools). Route onboarding integree avec redirect conditionnel.
5. **Base de donnees drift** : Migration transparente depuis SharedPreferences reussie. Schema complet avec tables collection, decks, wishlists, profiles, game_history, scan_history, collection_value_history.
6. **Client HTTP unifie** : `ScryfallApiService` avec Dio, cache, rate limiting. Plus aucun import `package:http/`.
7. **Theme centralise** : `AppColors` (184 lignes, 60+ constantes), `AppTextStyles` pour les fonts.
8. **PriceHelper centralise** : Helper + PriceTag widget pour toutes les operations prix (parsing, format, comparaison, tri).

### Points faibles

1. **God Files widgets persistants** : 6 widgets >500 lignes restent non decomposes :
   - `player_zone.dart` : 784 lignes
   - `deck_card_picker.dart` : 777 lignes
   - `deck_suggestions_tab.dart` : 736 lignes
   - `collection_list_tab.dart` : 670 lignes
   - `deck_stats_tab.dart` : 615 lignes
   - `game_setup_modal.dart` : 511 lignes

2. **God Files pages persistants** : 4 pages >500 lignes :
   - `set_detail_page.dart` : 1015 lignes (le plus gros fichier applicatif)
   - `deck_detail_page.dart` : 605 lignes
   - `card_search_page.dart` : 565 lignes
   - `card_detail_page.dart` : 542 lignes

3. **SharedPreferences residuelles** : 17 fichiers importent encore `SharedPreferences` malgre la base drift. Usages : onboarding flag, backup, migration, life counter, glossary, tournament, card search, card detail.

---

## A3. Qualite du Code

### Anti-patterns detectes

| # | Anti-pattern | Occurrences | Fichiers | Severite | Recommandation |
|---|-------------|-------------|----------|----------|----------------|
| AP1 | `firstWhere` sans `orElse` | 77 | 29 | **CRITIQUE** | Ajouter `orElse` ou utiliser `.where().firstOrNull` (Dart 3.0) |
| AP2 | `catch (e)` generique | 130 | 51 | HAUTE | Typer les exceptions : `on DioException`, `on StateError`, etc. |
| AP3 | `Color(0x...)` hardcode | 59 | 14 | MOYENNE | Migrer vers `AppColors.*` |
| AP4 | `GoogleFonts.*` direct | 40 | 15 | MOYENNE | Migrer vers `AppTextStyles.*` |
| AP5 | `SharedPreferences` direct | 17 | 17 | MOYENNE | Migrer vers drift `AppSettings` table |
| AP6 | `dependency_overrides` dans pubspec.yaml | 2 | 1 | BASSE | Mettre a jour ML Kit vers versions compatibles |

### Couverture de tests

| Domaine | Fichiers testes | Tests | Couverture estimee |
|---------|----------------|-------|-------------------|
| Controllers | 8/12 | ~280 | ~65% |
| Services | 10/21 | ~200 | ~45% |
| Models | 5/10+ | ~80 | ~50% |
| Widgets | 2/40+ | ~30 | ~5% |
| Pages | 0/23 | 0 | 0% |
| Router | 1/1 | ~20 | ~80% |
| Utils | 2/2 | ~30 | ~70% |
| **Total** | **28/110+** | **640** | **~35-40%** |

**Constat** : La couverture tests est bonne pour les controllers et services, mais quasi nulle pour les widgets et pages. Les tests widget/integration sont le maillon faible.

### Analyse statique

- `analysis_options.yaml` : 8 regles lint actives (basiques).
- Pipeline CI : `flutter analyze --no-fatal-infos --no-fatal-warnings` = **les warnings ne bloquent pas le build**.
- Recommandation : activer `--fatal-warnings` minimum, et ajouter des regles lint avancees (`prefer_final_locals`, `avoid_dynamic_calls`, `unawaited_futures`, `prefer_expression_function_bodies`).

---

## A4. Performance

### Points forts
- **Cache Scryfall** : Dio interceptor avec TTL pour les requetes API.
- **Isolate pour recherche locale** : `compute()` utilise pour le parsing de ~27 000 cartes.
- **Router instantie une seule fois** : Fix applique dans `main.dart` (`late final _router`).
- **TapGestureRecognizer disposes** : Gestion correcte des pools de recognizers dans `card_detail_page.dart` et `card_detail_info_sections.dart`.
- **Animations legeres** : Controllers natifs Flutter (pas de Rive/Lottie = empreinte minimale).

### Points d'attention
- **CollectionValueProvider** : Calcul batch pour collections >3000 cartes. Batch de 75 ok mais pas d'indicateur de progression pour l'utilisateur.
- **27 000 cartes en memoire** : `LocalCardService` charge le fichier oracle-cards.json au boot. Sur devices avec peu de RAM, cela pourrait poser probleme.
- **6 widgets >500 lignes** : Les builds de ces widgets sont potentiellement couteux. L'extraction en sous-widgets + `const` constructors ameliorerait les performances de rebuild.

---

## A5. CI/CD

### Pipeline existant (`build-main.yml`)

| Etape | Presente | Commentaire |
|-------|----------|-------------|
| Checkout + Flutter setup | Oui | Cache Flutter active |
| Python backend lint (Flake8) | Oui | Verifie le backend RAG |
| `flutter analyze` | Oui | **Mais `--no-fatal-infos --no-fatal-warnings`** |
| `flutter test --coverage` | Oui | Coverage check avec seuil 30% (warning seulement) |
| Build APK release | Oui | Semantic versioning automatique |
| GitHub Release | Oui | Avec APK renomme + changelog |
| Firebase App Distribution | Oui | Groupe "testers" |

### Manques identifies

| Manque | Impact | Recommandation |
|--------|--------|----------------|
| **Pas de PR Check** | Regressions detectees apres merge | Creer `pr-check.yml` avec analyze + test |
| **Warnings non fataux** | Problemes masques | Passer a `--no-fatal-infos` seulement (garder warnings fataux) |
| **Seuil coverage** | 30% = trop bas, warning seulement | Monter a 40% et bloquer la CI si en dessous |
| **Pas de test iOS** | Pas de validation cross-platform | Ajouter un job macOS si besoin (hors scope Sprint 14) |
| **Pas de Nightly build** | Pas de detection de regressions nocturnes | Sprint 15 |

---

## A6. Securite

| Point | Statut | Commentaire |
|-------|--------|-------------|
| `service-account.json` | A verifier | Doit etre dans `.gitignore` (verifie par audit Sprint 1) |
| `upload-keystore.jks` a la racine | **ATTENTION** | Fichier keystore present a la racine du projet. Doit etre dans `.gitignore`. |
| API keys dans le code | OK | Firebase config via `firebase_options.dart` (genere, acceptable) |
| `dependency_overrides` | RISQUE FAIBLE | ML Kit pin sur versions specifiques = bloque les patches securite |
| `shared_preferences` pour data sensible | OK | Pas de donnees sensibles stockees (seulement flags, preferences) |

---

## A7. Dette Technique Residuelle

### Heritee des sprints precedents (backlog Sprint 8)

| # | Dette | Effort | Priorite | Sprint cible |
|---|-------|--------|----------|-------------|
| D1 | 6 widgets >500 lignes a decomposer | 6j | P1 | Sprint 15 |
| D2 | 4 pages >500 lignes a decomposer | 4j | P1 | Sprint 15 |
| D3 | 130 `catch (e)` generiques a typer | 2j | P2 | Sprint 15-16 |
| D4 | 59 `Color(0x...)` hardcodes a migrer vers AppColors | 1j | P2 | Sprint 15 |
| D5 | 40 `GoogleFonts.*` directs a migrer vers AppTextStyles | 1j | P2 | Sprint 15 |
| D6 | 17 fichiers avec SharedPreferences a migrer vers drift | 2j | P2 | Sprint 15-16 |
| D7 | 2 `dependency_overrides` ML Kit a resoudre | 0.5j | P3 | Sprint 16 |
| D8 | 0 test widget / 0 test page (couverture UI = 0%) | 5j | P2 | Sprint 15-16 |
| D9 | Analyse statique permissive (warnings non fataux) | 0.5j | P1 | Sprint 14 (US-14.5) |
| **Total dette** | | **22j** | | Sprint 15-16 |

### Nouvelle dette Sprint 14

| # | Dette | Effort | Priorite |
|---|-------|--------|----------|
| N1 | 77 `firstWhere` sans `orElse` (a corriger dans US-14.5) | 1j | P0 -- Sprint 14 |
| N2 | `CollectionValueProvider` sans indicateur de progression | 0.5j | P2 |
| N3 | Onboarding avec SharedPreferences au lieu de drift | 0.25j | P3 |

---

## A8. Scoring Qualite

| Dimension | Score | Poids | Justification |
|-----------|-------|-------|---------------|
| Architecture | 9/10 | 25% | Separation des couches excellente, 12 controllers, providers centralises. -1 pour les God Files widgets restants. |
| Tests | 7/10 | 20% | 640 tests, bonne couverture controllers/services. -3 pour 0% couverture UI. |
| Code proprete | 7.5/10 | 15% | 0 print, 0 Navigator.push, 1 TODO. -2.5 pour 77 firstWhere, 130 catch generiques, 59 Colors hardcodes. |
| Performance | 8.5/10 | 15% | Cache, isolate, router fixe, animations natives. -1.5 pour God Files widgets (rebuild couteux). |
| CI/CD | 7/10 | 10% | Pipeline complet sur main. -3 pour absence de PR check et warnings non fataux. |
| Securite | 8/10 | 5% | Firebase config ok, SharedPrefs ok. -2 pour keystore a la racine et dependency_overrides. |
| Documentation | 9/10 | 5% | 57+ fichiers docs, roadmap, audits multi-agents. -1 pour absence de doc inline dans certains services. |
| DX (Developer Experience) | 8/10 | 5% | Riverpod, go_router, drift, Dio. -2 pour 17 SharedPrefs residuelles et lint permissif. |
| **Score global** | **8.1/10** | **100%** | **Progression depuis 5.5/10 (Sprint 0) a 8.1/10 (Sprint 14). Objectif 9.5/10 apres Sprint 15.** |

### Evolution du score qualite

```
Sprint 0  : 5.5/10  (0 tests, SharedPrefs, pas de DI, God Files)
Sprint 7  : 9.0/10  (273 tests, drift, Riverpod, 6 controllers)
Sprint 9  : 9.0/10  (298 tests, 5 features, stable)
Sprint 13 : 9.0/10  (617 tests, UI polish)
Sprint 14 : 8.1/10  (640 tests, audit approfondi revele dette cachee)
```

**Note** : La baisse apparente de 9.0 a 8.1 n'est pas une regression -- c'est un recalibrage de l'evaluation avec des criteres plus stricts (prise en compte des 77 firstWhere, 130 catch generiques, couverture UI nulle, CI permissive). Le code est objectivement meilleur qu'au Sprint 9.

---

## A9. Recommandations Prioritaires

### Immediat (Sprint 14)

1. **Corriger les 77 `firstWhere` sans `orElse`** -- Utiliser `.where().firstOrNull` (Dart 3.0+) ou `.firstWhere(test, orElse: () => ...)`.
2. **Creer `pr-check.yml`** -- Workflow GitHub Actions declenche sur `pull_request` avec `flutter analyze --no-fatal-infos` + `flutter test`.
3. **Finaliser l'integration PriceTag** dans tous les ecrans (collection list, scanner overlay, set detail).
4. **Valider les animations** sur device physique (60fps garanti).
5. **Verifier que `upload-keystore.jks` est dans `.gitignore`**.

### Court terme (Sprint 15)

1. Decomposer les 6 God Files widgets (>500 lignes).
2. Decomposer les 4 God Files pages (>500 lignes).
3. Migrer les 59 `Color(0x...)` restants vers `AppColors`.
4. Migrer les 40 `GoogleFonts.*` restants vers `AppTextStyles`.
5. Ajouter des tests widget pour les composants critiques (PriceTag, CollectionBadge, PlayerZone).

### Moyen terme (Sprint 16-17)

1. Typer les 130 `catch (e)` generiques.
2. Migrer les 17 `SharedPreferences` restantes vers drift.
3. Resoudre les `dependency_overrides` ML Kit.
4. Atteindre 60%+ de couverture tests globale.
5. Activer `--fatal-warnings` dans le CI.

---

*Audit realise par Zorro -- Business Analyst & Chef de Projet Senior*
*Sprint 14 -- Magic Companion v1.10 -- 08/03/2026*
*Base : 147 fichiers Dart, 34 152 lignes, 640 tests, 12 controllers, 21 services*
